extends Node3D

signal item_scanned(item_name: String, price: float)

@export var spawn_interval: float = 3.0
@export var conveyor_speed: float = 0.6

const CONVEYOR_SPEED_MIN: float = 0.3
const CONVEYOR_SPEED_MAX: float = 2.0
const CONVEYOR_SPEED_CHANGE: float = 0.2

@onready var camera: Camera3D = $Player/Camera3D
@onready var held_item_position: Node3D = $Player/Camera3D/HeldItem
@onready var scanner_area: Area3D = $Checkout/Scanner/ScannerArea
@onready var scan_sound: AudioStreamPlayer = $ScanSound

var held_item: RigidBody3D = null
var score: int = 0
var items_scanned: int = 0
var spawn_timer: float = 0.0

var item_scene: PackedScene

func _ready() -> void:
	item_scene = preload("res://scenes/items/grocery_item.tscn")
	scanner_area.body_entered.connect(_on_scanner_body_entered)
	spawn_item()

func _process(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		spawn_item()

func _physics_process(delta: float) -> void:
	if held_item:
		# Déplacer l'objet tenu vers la position devant la caméra
		var target_pos = held_item_position.global_position
		held_item.global_position = held_item.global_position.lerp(target_pos, 15.0 * delta)

		# Rotation de l'objet avec la molette ou les touches
		if Input.is_action_pressed("rotate_item_x"):
			held_item.rotate_x(delta * 2.0)
		if Input.is_action_pressed("rotate_item_y"):
			held_item.rotate_y(delta * 2.0)
		if Input.is_action_pressed("rotate_item_z"):
			held_item.rotate_z(delta * 2.0)

		# Vérifier si l'objet est dans la zone du scanner
		check_scanning(held_item)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("grab"):
		if held_item:
			release_item()
		else:
			try_grab_item()

	# Rotation avec la molette de la souris
	if held_item:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				held_item.rotate_x(0.2)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				held_item.rotate_x(-0.2)

func try_grab_item() -> void:
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + -camera.global_transform.basis.z * 3.0

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		# Vérifier si c'est un bouton de vitesse
		if collider.is_in_group("speed_button"):
			press_speed_button(collider)
			return
		# Sinon, essayer de prendre un objet
		if collider is RigidBody3D and collider.is_in_group("grabbable"):
			held_item = collider
			held_item.freeze = true
			held_item.collision_layer = 0

func press_speed_button(button: Node) -> void:
	if button.has_meta("speed_change"):
		var change = button.get_meta("speed_change")
		conveyor_speed = clamp(conveyor_speed + CONVEYOR_SPEED_CHANGE * change, CONVEYOR_SPEED_MIN, CONVEYOR_SPEED_MAX)
		print("Vitesse du tapis: %.1f" % conveyor_speed)

const THROW_FORCE: float = 3.0

func release_item() -> void:
	if held_item:
		held_item.freeze = false
		held_item.collision_layer = 1
		# Projeter l'objet dans la direction de la caméra
		var throw_direction = -camera.global_transform.basis.z
		held_item.linear_velocity = throw_direction * THROW_FORCE
		held_item = null

func spawn_item() -> void:
	if item_scene:
		var item = item_scene.instantiate()
		item.position = Vector3(-2.1, 1.3, -0.8)  # Au-dessus du tapis roulant
		# Rotation aléatoire initiale
		item.rotation = Vector3(
			randf_range(0, TAU),
			randf_range(0, TAU),
			randf_range(0, TAU)
		)
		add_child(item)

func check_scanning(item: Node3D) -> void:
	if not item.has_method("check_barcode_facing"):
		return

	# Vérifier la distance au scanner
	var distance = item.global_position.distance_to(scanner_area.global_position)
	if distance > 0.25:
		return

	# Vérifier si le code-barre fait face au scanner
	if item.check_barcode_facing(scanner_area.global_position):
		scan_item(item)

func _on_scanner_body_entered(body: Node3D) -> void:
	if body.is_in_group("grabbable") and body.has_method("check_barcode_facing"):
		if body.check_barcode_facing(scanner_area.global_position):
			scan_item(body)

func scan_item(item: Node3D) -> void:
	if item.has_meta("scanned") and item.get_meta("scanned"):
		return

	item.set_meta("scanned", true)

	# Effet visuel sur l'article scanné
	if item.has_method("mark_as_scanned"):
		item.mark_as_scanned()

	var item_name = item.get_meta("item_name") if item.has_meta("item_name") else "Article"
	var price = item.get_meta("price") if item.has_meta("price") else 1.0

	score += int(price * 100)
	items_scanned += 1

	emit_signal("item_scanned", item_name, price)
	print("Article scanné: %s - %.2f€" % [item_name, price])

	scan_sound.play()
