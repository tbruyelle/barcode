extends RigidBody3D

@export var item_name: String = "Article"
@export var price: float = 1.0
@export var barcode_threshold: float = 0.3

@onready var barcode_position: Node3D = $BarcodePosition
@onready var mesh: MeshInstance3D = $Mesh

# Limites du tapis roulant
const CONVEYOR_X_MIN: float = -2.25
const CONVEYOR_X_MAX: float = -0.75
const CONVEYOR_Z_MIN: float = -1.05
const CONVEYOR_Z_MAX: float = -0.55
const CONVEYOR_Y_MIN: float = 0.8  # Hauteur minimum (sur le tapis, pas au sol)

func _ready() -> void:
	add_to_group("grabbable")
	set_meta("item_name", item_name)
	set_meta("price", price)
	set_meta("scanned", false)

func check_barcode_facing(scanner_position: Vector3) -> bool:
	# Direction du code-barre (face locale Z+)
	var barcode_forward = barcode_position.global_transform.basis.z.normalized()

	# Direction vers le scanner
	var to_scanner = (scanner_position - barcode_position.global_position).normalized()

	# Le code-barre doit faire face au scanner
	var dot = barcode_forward.dot(to_scanner)

	return dot > barcode_threshold

func _is_on_conveyor() -> bool:
	var pos = global_position
	return pos.x >= CONVEYOR_X_MIN and pos.x <= CONVEYOR_X_MAX \
		and pos.z >= CONVEYOR_Z_MIN and pos.z <= CONVEYOR_Z_MAX \
		and pos.y >= CONVEYOR_Y_MIN

func _physics_process(_delta: float) -> void:
	# Mouvement sur le tapis roulant uniquement si l'objet est dessus
	if _is_on_conveyor() and not freeze:
		linear_velocity.x = get_parent().conveyor_speed

var halo: MeshInstance3D = null
var halo_material: StandardMaterial3D = null

func mark_as_scanned() -> void:
	# Créer un halo fin autour de l'objet
	halo = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.14, 0.19, 0.07)  # Juste un peu plus grand
	halo.mesh = box

	halo_material = StandardMaterial3D.new()
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.albedo_color = Color(0.3, 1.0, 0.4, 0.15)
	halo_material.emission_enabled = true
	halo_material.emission = Color(0.2, 0.8, 0.3)
	halo_material.emission_energy_multiplier = 0.2
	halo.set_surface_override_material(0, halo_material)

	add_child(halo)

	# Lancer l'animation de pulsation
	_animate_halo()

func _animate_halo() -> void:
	if not halo:
		return
	var tween = create_tween()
	tween.set_loops()
	tween.tween_method(_set_halo_alpha, 0.1, 0.25, 0.8)
	tween.tween_method(_set_halo_alpha, 0.25, 0.1, 0.8)

func _set_halo_alpha(alpha: float) -> void:
	if halo_material:
		halo_material.albedo_color.a = alpha
