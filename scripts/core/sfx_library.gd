extends RefCounted
class_name SfxLibrary

const SettingsStoreLib = preload("res://scripts/core/settings_store.gd")

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

const KEY_PICKUP_PATHS := [
	"res://assets/audio/sfx/key_pickup.wav",
	"res://assets/audio/sfx/key_pickup.ogg",
	"res://assets/audio/sfx/key_pickup.mp3",
]

const HEART_PICKUP_PATHS := [
	"res://assets/audio/sfx/heart_pickup.wav",
	"res://assets/audio/sfx/heart_pickup.ogg",
	"res://assets/audio/sfx/heart_pickup.mp3",
]

const PASSIVE_PICKUP_PATHS := [
	"res://assets/audio/sfx/passive_pickup.wav",
	"res://assets/audio/sfx/passive_pickup.ogg",
	"res://assets/audio/sfx/passive_pickup.mp3",
]

const PLAYER_HURT_PATHS := [
	"res://assets/audio/sfx/player_hurt.wav",
	"res://assets/audio/sfx/player_hurt.ogg",
	"res://assets/audio/sfx/player_hurt.mp3",
]

static var _stream_cache: Dictionary = {}
static var _sfx_volume_percent: float = SettingsStoreLib.get_sfx_volume_percent()

static func play_shoot(source: Node, volume_db: float = -4.5) -> void:
	_play(source, "shoot", volume_db)

static func play_enemy_death(source: Node, volume_db: float = -3.5) -> void:
	_play(source, "enemy_death", volume_db)

static func play_item_pickup(source: Node, item_data: ItemData, volume_db: float = -5.5) -> void:
	if item_data == null:
		_play(source, "passive_pickup", volume_db)
		return
	if item_data.id == "key":
		_play(source, "key_pickup", volume_db)
		return
	if item_data.id == "heart" or item_data.pickup_kind == "heal":
		_play(source, "heart_pickup", volume_db)
		return
	_play(source, "passive_pickup", volume_db)

static func play_player_hurt(source: Node, volume_db: float = -4.0) -> void:
	_play(source, "player_hurt", volume_db)

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
	SettingsStoreLib.set_sfx_volume_percent(_sfx_volume_percent)

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
	elif kind == "key_pickup":
		candidates = KEY_PICKUP_PATHS
	elif kind == "heart_pickup":
		candidates = HEART_PICKUP_PATHS
	elif kind == "passive_pickup":
		candidates = PASSIVE_PICKUP_PATHS
	elif kind == "player_hurt":
		candidates = PLAYER_HURT_PATHS

	for path in candidates:
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				return stream

	return null

static func _build_fallback_stream(kind: String) -> AudioStreamWAV:
	if kind == "enemy_death":
		return _generate_tone_stream(580.0, 0.16, 0.30, 0.65, 120.0)
	if kind == "key_pickup":
		return _generate_tone_stream(1320.0, 0.08, 0.22, 1680.0, 0.0)
	if kind == "heart_pickup":
		return _generate_tone_stream(720.0, 0.12, 0.24, 980.0, 0.0)
	if kind == "passive_pickup":
		return _generate_tone_stream(520.0, 0.22, 0.26, 1040.0, 0.0)
	if kind == "player_hurt":
		return _generate_tone_stream(240.0, 0.18, 0.28, 120.0, 0.14)
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
