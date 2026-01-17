extends AudioStreamPlayer

var sample_rate: float = 44100.0
var frequency: float = 1000.0
var duration: float = 0.15

func _ready() -> void:
	_generate_beep()

func _generate_beep() -> void:
	var samples = int(sample_rate * duration)
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = int(sample_rate)
	audio.stereo = false

	var data = PackedByteArray()
	data.resize(samples * 2)  # 16 bits = 2 bytes per sample

	for i in range(samples):
		var t = float(i) / sample_rate
		var value = sin(TAU * frequency * t)
		# Envelope pour éviter les clics
		var envelope = 1.0
		var fade_samples = int(sample_rate * 0.01)
		if i < fade_samples:
			envelope = float(i) / fade_samples
		elif i > samples - fade_samples:
			envelope = float(samples - i) / fade_samples
		value *= envelope

		var sample = int(value * 32767)
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF

	audio.data = data
	stream = audio

func beep() -> void:
	play()
