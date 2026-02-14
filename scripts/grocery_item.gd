extends RigidBody3D

@export var item_name: String = "Article"
@export var price: float = 1.0
@export var barcode_threshold: float = 0.3

@onready var barcode_position: Node3D = $BarcodePosition
@onready var mesh: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var barcode_mesh: MeshInstance3D = $BarcodePosition/BarcodeMesh
@onready var collision_sound: AudioStreamPlayer3D = $CollisionSound

var item_size: Vector3 = Vector3(0.13, 0.18, 0.06)
var collision_cooldown: float = 0.0
const COLLISION_COOLDOWN_TIME: float = 0.1

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
	body_entered.connect(_on_body_entered)
	_generate_collision_sound()

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

func _physics_process(delta: float) -> void:
	if collision_cooldown > 0.0:
		collision_cooldown -= delta
	# Mouvement sur le tapis roulant uniquement si l'objet est dessus
	if _is_on_conveyor() and not freeze:
		linear_velocity.x = get_parent().conveyor_speed

var halo: MeshInstance3D = null
var halo_material: StandardMaterial3D = null

func mark_as_scanned() -> void:
	# Créer un halo fin autour de l'objet
	halo = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = item_size + Vector3(0.01, 0.01, 0.01)  # Juste un peu plus grand
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

func set_appearance(size: Vector3, color: Color, product_name: String, product_price: float) -> void:
	item_size = size
	item_name = product_name
	price = product_price
	set_meta("item_name", item_name)
	set_meta("price", price)

	# Mettre à jour le mesh
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh

	# Mettre à jour le matériau
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.set_surface_override_material(0, mat)

	# Mettre à jour la collision shape
	var shape = BoxShape3D.new()
	shape.size = size + Vector3(0.02, 0.02, 0.02)
	collision_shape.shape = shape

	# Repositionner le code-barre sur la face avant
	barcode_position.position = Vector3(0, 0, size.z / 2.0 + 0.001)

	# Mettre à jour la taille du halo si scanné
	if halo:
		var halo_box = halo.mesh as BoxMesh
		halo_box.size = size + Vector3(0.01, 0.01, 0.01)

func _generate_collision_sound() -> void:
	var sample_rate := 44100.0
	var duration := 0.08
	var samples := int(sample_rate * duration)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = int(sample_rate)
	audio.stereo = false

	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in range(samples):
		var t := float(i) / sample_rate
		# Enveloppe à décroissance rapide
		var envelope := exp(-t * 45.0)
		# Son sourd : basses fréquences + harmoniques
		var value := sin(TAU * 120.0 * t) * 0.5
		value += sin(TAU * 240.0 * t) * 0.2
		value += sin(TAU * 80.0 * t) * 0.3
		value *= envelope
		var sample_val := int(clampf(value, -1.0, 1.0) * 32767)
		data[i * 2] = sample_val & 0xFF
		data[i * 2 + 1] = (sample_val >> 8) & 0xFF

	audio.data = data
	collision_sound.stream = audio

func _on_body_entered(_body: Node) -> void:
	var speed := linear_velocity.length()
	if speed < 0.3:
		return
	# Volume selon la vitesse d'impact
	collision_sound.volume_db = lerpf(-18.0, 0.0, clampf(speed / 4.0, 0.0, 1.0))
	# Variation de pitch pour varier les sons
	collision_sound.pitch_scale = randf_range(0.8, 1.3)
	collision_sound.play()
