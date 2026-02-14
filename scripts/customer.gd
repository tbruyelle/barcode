extends Node3D

signal customer_left

enum State { DEPOSITING, WALKING_TO_BASKET, COLLECTING, LEAVING }

## Vitesse de déplacement du client (en mètres par seconde)
@export var move_speed: float = 0.2

## Paramètres du balancier de marche
@export var bob_frequency: float = 0.8
@export var bob_amplitude: float = 0.01
@export var sway_frequency: float = 0.6
@export var sway_amplitude: float = 0.02

const DEPOSIT_POS: Vector3 = Vector3(-2.1, 0, 0.2)
const BASKET_POS: Vector3 = Vector3(1.5, 0, 0.2)
const DOOR_POS: Vector3 = Vector3(5.0, 0, 0.2)
const DEPOSIT_INTERVAL: float = 2.0
const COLLECT_INTERVAL: float = 0.5
const ORBIT_RADIUS: float = 0.4
const ORBIT_SPEED: float = 1.5

@onready var sprite: Sprite3D = $Sprite3D

var state: State = State.DEPOSITING
var walk_time: float = 0.0
var base_sprite_y: float = 0.0

var game_manager: Node3D = null
var items_data: Array = []
var deposit_timer: float = 0.0
var deposit_index: int = 0
var collect_timer: float = 0.0

# Visual floaters orbiting the customer
var orbit_visuals: Array[MeshInstance3D] = []
# References to physical items deposited on conveyor
var deposited_items: Array[RigidBody3D] = []

var move_target: Vector3 = Vector3.ZERO

func setup(p_items_data: Array, p_game_manager: Node3D) -> void:
	items_data = p_items_data
	game_manager = p_game_manager

func _ready() -> void:
	position = DEPOSIT_POS
	base_sprite_y = sprite.position.y
	_create_orbit_visuals()
	state = State.DEPOSITING
	deposit_timer = 0.0
	deposit_index = 0

func _create_orbit_visuals() -> void:
	for i in range(items_data.size()):
		var data: Dictionary = items_data[i]
		var visual = _make_visual(data)
		add_child(visual)
		orbit_visuals.append(visual)

func _make_visual(data: Dictionary) -> MeshInstance3D:
	var visual = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = data.size
	visual.mesh = box
	var mat = StandardMaterial3D.new()
	mat.albedo_color = data.color
	visual.set_surface_override_material(0, mat)
	# Add barcode stripe
	var barcode = MeshInstance3D.new()
	var barcode_box = BoxMesh.new()
	barcode_box.size = Vector3(data.size.x * 0.5, data.size.y * 0.3, 0.002)
	barcode.mesh = barcode_box
	var barcode_mat = StandardMaterial3D.new()
	barcode_mat.albedo_color = Color.WHITE
	barcode.set_surface_override_material(0, barcode_mat)
	barcode.position.z = data.size.z * 0.4 + 0.002
	visual.add_child(barcode)
	return visual

func _process(delta: float) -> void:
	_update_orbit(delta)
	match state:
		State.DEPOSITING:
			_process_depositing(delta)
		State.WALKING_TO_BASKET:
			_process_walking(delta, BASKET_POS)
		State.COLLECTING:
			_process_collecting(delta)
		State.LEAVING:
			_process_walking(delta, DOOR_POS)

func _update_orbit(delta: float) -> void:
	walk_time += delta
	var count = orbit_visuals.size()
	for i in range(count):
		var visual = orbit_visuals[i]
		if not is_instance_valid(visual):
			continue
		var angle = walk_time * ORBIT_SPEED + (TAU / max(count, 1)) * i
		var height = 0.6 + 0.3 * sin(walk_time * 0.8 + i * 0.7)
		visual.position = Vector3(cos(angle) * ORBIT_RADIUS, height, sin(angle) * ORBIT_RADIUS)
		visual.rotation.y = walk_time * 0.5

func _process_depositing(delta: float) -> void:
	deposit_timer += delta
	if deposit_timer >= DEPOSIT_INTERVAL and deposit_index < items_data.size():
		deposit_timer = 0.0
		_deposit_next_item()
	if deposit_index >= items_data.size():
		state = State.WALKING_TO_BASKET

func _deposit_next_item() -> void:
	if deposit_index >= orbit_visuals.size():
		return
	var visual = orbit_visuals[deposit_index]
	var data = items_data[deposit_index]
	deposit_index += 1
	if not is_instance_valid(visual):
		# Visual gone, still spawn the physical item
		_spawn_physical_item(data)
		return
	# Reparent visual to scene root (keep global position)
	var global_pos = visual.global_position
	var global_rot = visual.global_rotation
	visual.get_parent().remove_child(visual)
	game_manager.add_child(visual)
	visual.global_position = global_pos
	visual.global_rotation = global_rot
	# Tween to conveyor drop position
	var drop_pos = Vector3(-2.1, 1.3, -0.8)
	var tween = game_manager.create_tween()
	tween.tween_property(visual, "global_position", drop_pos, 0.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_callback(_on_deposit_tween_done.bind(visual, data))

func _on_deposit_tween_done(visual: MeshInstance3D, data: Dictionary) -> void:
	if is_instance_valid(visual):
		visual.queue_free()
	_spawn_physical_item(data)

func _spawn_physical_item(data: Dictionary) -> void:
	var item = game_manager.instantiate_item(data)
	deposited_items.append(item)

func _process_walking(delta: float, target: Vector3) -> void:
	# Walking animation
	var bob_offset = abs(sin(walk_time * bob_frequency * TAU)) * bob_amplitude
	sprite.position.y = base_sprite_y + bob_offset
	sprite.rotation.z = sin(walk_time * sway_frequency * TAU) * sway_amplitude

	var direction = (target - position).normalized()
	position += direction * move_speed * delta

	if position.distance_to(target) < 0.1:
		sprite.position.y = base_sprite_y
		sprite.rotation.z = 0.0
		if state == State.WALKING_TO_BASKET:
			state = State.COLLECTING
			collect_timer = 0.0
		elif state == State.LEAVING:
			customer_left.emit()

func _process_collecting(delta: float) -> void:
	collect_timer += delta
	if collect_timer >= COLLECT_INTERVAL:
		collect_timer = 0.0
		if not _collect_one_item():
			# No more scanned items to collect, leave
			state = State.LEAVING

func _collect_one_item() -> bool:
	# Clean up invalid refs and find next scanned item
	var i = 0
	while i < deposited_items.size():
		var item = deposited_items[i]
		if not is_instance_valid(item):
			deposited_items.remove_at(i)
			continue
		if item.get_meta("scanned"):
			var data = {
				"size": item.item_size,
				"color": item.mesh.get_surface_override_material(0).albedo_color if item.mesh.get_surface_override_material(0) else Color.WHITE,
				"name": item.item_name,
				"price": item.price
			}
			deposited_items.remove_at(i)
			# Freeze physics and fly towards customer
			item.freeze = true
			item.collision_layer = 0
			var target = global_position + Vector3(0, 0.8, 0)
			var tween = game_manager.create_tween()
			tween.tween_property(item, "global_position", target, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
			tween.tween_callback(_on_collect_tween_done.bind(item, data))
			return true
		i += 1
	return false

func _on_collect_tween_done(item: RigidBody3D, data: Dictionary) -> void:
	if is_instance_valid(item):
		item.queue_free()
	var visual = _make_visual(data)
	add_child(visual)
	orbit_visuals.append(visual)
