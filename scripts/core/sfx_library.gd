extends RefCounted
class_name SfxLibrary

const SHOOT_PATHS := [
	"res://assets/audio/sfx/shoot.wav",
	"res://assets/audio/sfx/shoot.ogg",
	"res://assets/audio/sfx/shoot.mp3",
]

const ENEMY_DEATH_PATHS := [
	"res://assets/audio/sfx/enemy_die.wav",
	"res://assets/audio/sfx/enemy_die.ogg",
	"res://assets/audio/sfx/enemy_die.mp3",
]

static var _stream_cache: Dictionary = {}
static var _sfx_volume_percent: float = 75.0

static func play_shoot(source: Node, volume_db: float = -4.5) -> void:
	_play(source, "shoot", volume_db)

static func play_enemy_death(source: Node, volume_db: float = -3.5) -> void:
	_play(source, "enemy_death", volume_db)

static func _play(source: Node, kind: String, volume_db: float) -> void:
	if source == null or source.get_tree() == null:
		return

	var player := AudioStreamPlayer2D.new()
	player.volume_db = _resolve_output_volume_db(volume_db)
	player.max_distance = 1600.0
	player.attenuation = 1.2
	player.stream = _get_stream(kind)

	if source is Node2D:
		player.global_position = (source as Node2D).global_position

	source.get_tree().current_scene.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

static func set_sfx_volume_percent(percent: float) -> void:
	_sfx_volume_percent = clampf(percent, 0.0, 100.0)

static func get_sfx_volume_percent() -> float:
	return _sfx_volume_percent

static func _get_stream(kind: String) -> AudioStream:
	if _stream_cache.has(kind):
		return _stream_cache[kind]

	var stream := _load_custom_stream(kind)
	if stream == null:
		stream = _build_fallback_stream(kind)

	_stream_cache[kind] = stream
	return stream

static func _load_custom_stream(kind: String) -> AudioStream:
	var candidates := SHOOT_PATHS
	if kind == "enemy_death":
		candidates = ENEMY_DEATH_PATHS

	for path in candidates:
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				return stream

	return null

static func _build_fallback_stream(kind: String) -> AudioStreamWAV:
	if kind == "enemy_death":
		return _generate_tone_stream(580.0, 0.16, 0.30, 0.65, 120.0)
	return _generate_tone_stream(880.0, 0.07, 0.20, 0.0, 0.0)

static func _generate_tone_stream(start_freq: float, duration: float, amplitude: float, end_freq: float, noise_mix: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	var phase := 0.0
	for i in range(sample_count):
		var t := float(i) / float(sample_count)
		var env := 1.0 - t
		env *= env

		var freq := start_freq
		if end_freq > 0.0:
			freq = lerpf(start_freq, end_freq, t)

		phase += TAU * freq / sample_rate
		var sample := sin(phase) * amplitude * env

		if noise_mix > 0.0:
			var noise := randf_range(-1.0, 1.0) * noise_mix * env * 0.25
			sample += noise

		var pcm_value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		data[i * 2] = pcm_value & 0xFF
		data[i * 2 + 1] = (pcm_value >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream

static func _resolve_output_volume_db(base_volume_db: float) -> float:
	if _sfx_volume_percent <= 0.0:
		return -80.0
	return base_volume_db + linear_to_db(_sfx_volume_percent / 100.0)
