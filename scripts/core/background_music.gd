extends AudioStreamPlayer

@export var music_folder: String = "res://assets/audio/music"
@export var music_volume_db: float = -18.0

const SUPPORTED_EXTENSIONS := ["mp3", "ogg", "wav"]
const MIN_VOLUME_DB: float = -40.0
const MAX_VOLUME_DB: float = 0.0
const NORMAL_PITCH_SCALE: float = 1.0
const BULLET_TIME_PITCH_SCALE: float = 0.88
const BULLET_TIME_TRANSITION_DURATION: float = 0.28

var _generator_playback: AudioStreamGeneratorPlayback = null
var _tracks: Array[String] = []
var _current_track_path: String = ""
var _rng := RandomNumberGenerator.new()
var _pitch_tween: Tween = null

func _ready() -> void:
	add_to_group("background_music")
	set_music_volume_db(music_volume_db)
	pitch_scale = NORMAL_PITCH_SCALE
	finished.connect(_on_track_finished)
	_rng.randomize()
	_reload_tracks()

	if _tracks.is_empty():
		_setup_silent_fallback()
	else:
		_play_random_track()

func _process(_delta: float) -> void:
	if _generator_playback == null:
		return

	var frames_available := _generator_playback.get_frames_available()
	for _i in range(frames_available):
		_generator_playback.push_frame(Vector2.ZERO)

func _reload_tracks() -> void:
	_tracks.clear()

	var dir := DirAccess.open(music_folder)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if file_name.ends_with(".import"):
			continue

		var extension := file_name.get_extension().to_lower()
		if extension in SUPPORTED_EXTENSIONS:
			_tracks.append(music_folder.path_join(file_name))
	dir.list_dir_end()

func _play_random_track() -> void:
	if _tracks.is_empty():
		_setup_silent_fallback()
		return

	var candidates := _tracks.duplicate()
	if candidates.size() > 1 and _current_track_path != "":
		candidates.erase(_current_track_path)

	var next_track_path: String = candidates[_rng.randi_range(0, candidates.size() - 1)]
	var next_stream := load(next_track_path) as AudioStream
	if next_stream == null:
		_tracks.erase(next_track_path)
		_play_random_track()
		return

	_current_track_path = next_track_path
	_generator_playback = null
	stream = next_stream
	play()

func _setup_silent_fallback() -> void:
	_current_track_path = ""
	var silent_stream := AudioStreamGenerator.new()
	silent_stream.mix_rate = 44100.0
	silent_stream.buffer_length = 0.5
	stream = silent_stream
	play()
	_generator_playback = get_stream_playback() as AudioStreamGeneratorPlayback

func _on_track_finished() -> void:
	_play_random_track()

func set_music_volume_db(value: float) -> void:
	music_volume_db = clampf(value, MIN_VOLUME_DB, MAX_VOLUME_DB)
	volume_db = music_volume_db

func get_music_volume_db() -> float:
	return music_volume_db

func set_music_volume_percent(percent: float) -> void:
	var normalized := clampf(percent, 0.0, 100.0) / 100.0
	set_music_volume_db(lerpf(MIN_VOLUME_DB, MAX_VOLUME_DB, normalized))

func get_music_volume_percent() -> float:
	return inverse_lerp(MIN_VOLUME_DB, MAX_VOLUME_DB, music_volume_db) * 100.0

func set_bullet_time_audio(active: bool) -> void:
	var target_pitch := NORMAL_PITCH_SCALE
	if active:
		target_pitch = BULLET_TIME_PITCH_SCALE

	if _pitch_tween != null:
		_pitch_tween.kill()

	_pitch_tween = create_tween()
	_pitch_tween.set_trans(Tween.TRANS_SINE)
	_pitch_tween.set_ease(Tween.EASE_IN_OUT)
	_pitch_tween.tween_property(self, "pitch_scale", target_pitch, BULLET_TIME_TRANSITION_DURATION)
