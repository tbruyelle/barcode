extends MeshInstance3D

@export var glow_speed: float = 0.15

var glow: MeshInstance3D
var glow_material: StandardMaterial3D
var glow_pos: float = 0.1
var direction: float = -1.0
const BEAM_HALF: float = 0.1

func _ready() -> void:
	glow = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.004
	sphere.height = 0.008
	glow.mesh = sphere

	glow_material = StandardMaterial3D.new()
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.albedo_color = Color(1, 0.3, 0, 0.9)
	glow_material.emission_enabled = true
	glow_material.emission = Color(1, 0, 0)
	glow_material.emission_energy_multiplier = 2.5
	glow.set_surface_override_material(0, glow_material)

	add_child(glow)

func _process(delta: float) -> void:
	glow_pos += direction * glow_speed * delta
	if glow_pos <= -BEAM_HALF:
		glow_pos = -BEAM_HALF
		direction = 1.0
	elif glow_pos >= BEAM_HALF:
		glow_pos = BEAM_HALF
		direction = -1.0
	glow.position.x = glow_pos
	# Plus lumineux au centre, plus faible aux extrémités
	var t: float = 1.0 - abs(glow_pos) / BEAM_HALF
	glow_material.albedo_color.a = t * 0.9
	glow_material.emission_energy_multiplier = t * 3.0
