extends RigidBody3D

@export var item_name: String = "Article"
@export var price: float = 1.0
@export var barcode_threshold: float = 0.3

@onready var barcode_position: Node3D = $BarcodePosition

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
		linear_velocity.x = 0.3
