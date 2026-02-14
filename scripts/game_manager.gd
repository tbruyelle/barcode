extends Node3D

signal item_scanned(item_name: String, price: float)

const CONVEYOR_SPEED: float = 0.6

# Définition des produits variés (basés sur les étagères)
const PRODUCT_COLORS: Array = [
	Color(0.9, 0.2, 0.15, 1),   # Rouge
	Color(0.95, 0.85, 0.2, 1),  # Jaune
	Color(0.2, 0.7, 0.3, 1),    # Vert
	Color(0.2, 0.5, 0.9, 1),    # Bleu
	Color(0.95, 0.5, 0.1, 1),   # Orange
	Color(0.6, 0.3, 0.7, 1),    # Violet
	Color(0.95, 0.5, 0.7, 1),   # Rose
	Color(0.5, 0.35, 0.2, 1),   # Marron
]

const PRODUCT_NAMES: Array = [
	"Sauce tomate",
	"Moutarde",
	"Cornichons",
	"Confiture",
	"Jus d'orange",
	"Confiture de mûres",
	"Bonbons",
	"Chocolat",
]

# Tailles min/max pour générer des produits variés (70% des produits étagères)
const SIZE_MIN: Vector3 = Vector3(0.07, 0.084, 0.056)
const SIZE_MAX: Vector3 = Vector3(0.154, 0.21, 0.112)

@onready var camera: Camera3D = $Player/Camera3D
@onready var held_item_position: Node3D = $Player/Camera3D/HeldItem
@onready var scanner_area: Area3D = $Checkout/Scanner/ScannerArea
@onready var scan_sound: AudioStreamPlayer = $ScanSound
@onready var scan_item_list: VBoxContainer = $UI/ScanHUD/MarginContainer/VBoxContainer/ScrollContainer/ItemList
@onready var total_label: Label = $UI/ScanHUD/MarginContainer/VBoxContainer/TotalLabel

var held_item: RigidBody3D = null
var total_price: float = 0.0
var score: int = 0
var items_scanned: int = 0

var item_scene: PackedScene
var customer_scene: PackedScene
var current_customer: Node3D = null

func _ready() -> void:
	item_scene = preload("res://scenes/items/grocery_item.tscn")
	customer_scene = preload("res://scenes/customer.tscn")
	scanner_area.body_entered.connect(_on_scanner_body_entered)
	spawn_next_customer()

func _physics_process(_delta: float) -> void:
	if held_item:
		# Déplacer l'objet via vélocité (la physique gère les collisions)
		var target_pos = held_item_position.global_position
		held_item.linear_velocity = (target_pos - held_item.global_position) * 15.0

		# Rotation manuelle via angular_velocity
		if Input.is_action_pressed("rotate_item_x"):
			held_item.angular_velocity.x = 2.0
		if Input.is_action_pressed("rotate_item_y"):
			held_item.angular_velocity.y = 2.0
		if Input.is_action_pressed("rotate_item_z"):
			held_item.angular_velocity.z = 2.0

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
				held_item.angular_velocity.x += 3.0
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				held_item.angular_velocity.x -= 3.0

func try_grab_item() -> void:
	var space_state = get_world_3d().direct_space_state
	var from = camera.global_position
	var to = from + -camera.global_transform.basis.z * 3.0

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true

	var result = space_state.intersect_ray(query)
	if result:
		var collider = result.collider
		# Vérifier si c'est le bouton du tiroir-caisse
		if collider.is_in_group("drawer_button"):
			$Checkout/CashRegister.toggle_drawer()
			return
		# Sinon, essayer de prendre un objet
		if collider is RigidBody3D and collider.is_in_group("grabbable"):
			held_item = collider
			held_item.gravity_scale = 0.0
			held_item.angular_damp = 3.0
			held_item.collision_layer = 2  # Invisible au raycast (layer 1) mais collisions actives

const THROW_FORCE: float = 3.0

func release_item() -> void:
	if held_item:
		held_item.gravity_scale = 1.0
		held_item.angular_damp = 0.0
		held_item.collision_layer = 1
		# Projeter l'objet dans la direction de la caméra
		var throw_direction = -camera.global_transform.basis.z
		held_item.linear_velocity = throw_direction * THROW_FORCE
		held_item = null

func generate_item_data() -> Dictionary:
	var color_index = randi() % PRODUCT_COLORS.size()
	var color = PRODUCT_COLORS[color_index]
	var product_name = PRODUCT_NAMES[color_index]
	var size = Vector3(
		randf_range(SIZE_MIN.x, SIZE_MAX.x),
		randf_range(SIZE_MIN.y, SIZE_MAX.y),
		randf_range(SIZE_MIN.z, SIZE_MAX.z)
	)
	var volume = size.x * size.y * size.z
	var price = snappedf(1.0 + volume * 100.0, 0.1)
	return {
		"color": color,
		"name": product_name,
		"size": size,
		"price": price
	}

func instantiate_item(data: Dictionary) -> RigidBody3D:
	var item = item_scene.instantiate()
	item.position = Vector3(-2.1, 1.3, -0.8)
	item.rotation = Vector3(
		randf_range(0, TAU),
		randf_range(0, TAU),
		randf_range(0, TAU)
	)
	add_child(item)
	item.set_appearance(data.size, data.color, data.name, data.price)
	return item

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

	# Mettre à jour le HUD
	total_price += price
	var item_label = Label.new()
	item_label.text = "%s  —  %.2f €" % [item_name, price]
	item_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	var mono_font = SystemFont.new()
	mono_font.font_names = PackedStringArray(["Courier New", "Liberation Mono", "DejaVu Sans Mono", "monospace"])
	item_label.add_theme_font_override("font", mono_font)
	item_label.add_theme_font_size_override("font_size", 17)
	scan_item_list.add_child(item_label)
	total_label.text = "Total: %.2f €" % total_price
	# Auto-scroll vers le dernier article
	scan_item_list.get_parent().call_deferred("ensure_control_visible", item_label)

	scan_sound.play()

func spawn_next_customer() -> void:
	_reset_hud()
	var item_count = randi_range(1, 20)
	var items_data: Array = []
	for i in range(item_count):
		items_data.append(generate_item_data())
	current_customer = customer_scene.instantiate()
	current_customer.setup(items_data, self)
	add_child(current_customer)
	current_customer.customer_left.connect(_on_customer_left)

func _on_customer_left() -> void:
	if current_customer:
		current_customer.queue_free()
		current_customer = null
	get_tree().create_timer(2.0).timeout.connect(spawn_next_customer)

func _reset_hud() -> void:
	total_price = 0.0
	items_scanned = 0
	total_label.text = "Total: 0.00 €"
	for child in scan_item_list.get_children():
		child.queue_free()
