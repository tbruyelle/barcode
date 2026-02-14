extends MeshInstance3D

var time: float = 0.0
var material: StandardMaterial3D

func _ready() -> void:
	material = get_surface_override_material(0)

func _process(delta: float) -> void:
	time += delta
	# Plusieurs ondes superposées pour un effet scintillant
	var shimmer := sin(time * 6.0) * 0.3
	shimmer += sin(time * 14.0) * 0.2
	shimmer += sin(time * 23.0) * 0.15
	var alpha := 0.06 + (shimmer + 0.65) * 0.08
	material.albedo_color.a = clampf(alpha, 0.02, 0.15)
	material.emission_energy_multiplier = 0.15 + (shimmer + 0.65) * 0.4
