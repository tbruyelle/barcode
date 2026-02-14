extends OmniLight3D

@export var base_energy: float = 2.0
@export var flicker_chance: float = 0.005  # Probabilité de scintillement par frame
@export var buzz_chance: float = 0.003  # Probabilité de grésillement par frame

var buzz_sound: AudioStreamPlayer3D
var buzz_stream: AudioStreamWAV
var is_flickering: bool = false
var flicker_timer: float = 0.0
var flicker_duration: float = 0.0

func _ready() -> void:
	base_energy = light_energy
	_setup_buzz_sound()

func _setup_buzz_sound() -> void:
	buzz_sound = AudioStreamPlayer3D.new()
	buzz_sound.unit_size = 5.0
	buzz_sound.max_distance = 15.0
	buzz_sound.volume_db = -26.0
	add_child(buzz_sound)
	buzz_stream = _generate_buzz()
	buzz_sound.stream = buzz_stream

func _generate_buzz() -> AudioStreamWAV:
	var sample_rate := 44100.0
	var duration := 0.3
	var samples := int(sample_rate * duration)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = int(sample_rate)
	audio.stereo = false
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / sample_rate
		# Enveloppe : montée rapide, plateau, descente
		var envelope := 1.0
		if t < 0.02:
			envelope = t / 0.02
		elif t > 0.25:
			envelope = (duration - t) / 0.05
		# Bourdonnement 50Hz (fréquence secteur) + harmoniques
		var value := sin(TAU * 50.0 * t) * 0.3
		value += sin(TAU * 100.0 * t) * 0.25
		value += sin(TAU * 150.0 * t) * 0.15
		value += sin(TAU * 200.0 * t) * 0.1
		# Bruit haute fréquence pour le grésillement
		value += (randf() * 2.0 - 1.0) * 0.2
		value *= envelope
		var sample_val := int(clampf(value, -1.0, 1.0) * 32767)
		data[i * 2] = sample_val & 0xFF
		data[i * 2 + 1] = (sample_val >> 8) & 0xFF
	audio.data = data
	return audio

func _process(delta: float) -> void:
	if is_flickering:
		flicker_timer -= delta
		if flicker_timer <= 0.0:
			is_flickering = false
			light_energy = base_energy
		else:
			# Scintillement rapide et irrégulier
			light_energy = base_energy * randf_range(0.3, 1.1)
		return

	# Déclencher un scintillement aléatoire
	if randf() < flicker_chance:
		is_flickering = true
		flicker_duration = randf_range(0.05, 0.25)
		flicker_timer = flicker_duration
		# Jouer le grésillement
		buzz_sound.pitch_scale = randf_range(0.9, 1.2)
		buzz_sound.play()
	# Grésillement léger sans scintillement
	elif randf() < buzz_chance:
		buzz_sound.volume_db = randf_range(-30.0, -24.0)
		buzz_sound.pitch_scale = randf_range(0.8, 1.1)
		buzz_sound.play()
		# Micro-variation de lumière
		light_energy = base_energy * randf_range(0.92, 1.0)
	else:
		# Retour progressif à la normale
		light_energy = lerpf(light_energy, base_energy, delta * 10.0)
