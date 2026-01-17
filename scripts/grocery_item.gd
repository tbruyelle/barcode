extends RigidBody3D

@export var item_name: String = "Article"
@export var price: float = 1.0
@export var barcode_threshold: float = 0.7

@onready var barcode_position: Node3D = $BarcodePosition

var is_on_conveyor: bool = true

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

func _physics_process(_delta: float) -> void:
	# Mouvement sur le tapis roulant
	if is_on_conveyor and not freeze:
		var conveyor_direction = Vector3(1, 0, 0)
		linear_velocity = conveyor_direction * 0.3
