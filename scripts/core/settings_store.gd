extends RefCounted
class_name SettingsStore

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LEADERBOARD_API_PATH := "api/leaderboard.php"
const SECTION_AUDIO := "audio"
const SECTION_PROFILE := "profile"
const SECTION_STATS := "stats"
const KEY_MUSIC_VOLUME := "music_volume_percent"
const KEY_SFX_VOLUME := "sfx_volume_percent"
const KEY_PLAYER_NAME := "player_name"
const KEY_LEADERBOARD_API_URL := "leaderboard_api_url"
const KEY_TOTAL_RUNS := "total_runs"
const KEY_TOTAL_KILLS := "total_kills"
const KEY_TOTAL_SCORE := "total_score"
const KEY_TOTAL_TIME_SECONDS := "total_time_seconds"
const KEY_BEST_SCORE := "best_score"
const KEY_BEST_BASEMENT := "best_basement"
const KEY_LAST_SCORE := "last_score"
const KEY_LAST_BASEMENT := "last_basement"

static var _loaded: bool = false
static var _music_volume_percent: float = 55.0
static var _sfx_volume_percent: float = 75.0
static var _player_name: String = "Игрок BFU"
static var _leaderboard_api_url: String = DEFAULT_LEADERBOARD_API_PATH
static var _total_runs: int = 0
static var _total_kills: int = 0
static var _total_score: int = 0
static var _total_time_seconds: int = 0
static var _best_score: int = 0
static var _best_basement: int = 1
static var _last_score: int = 0
static var _last_basement: int = 1


static func get_music_volume_percent() -> float:
	_ensure_loaded()
	return _music_volume_percent


static func set_music_volume_percent(percent: float) -> void:
	_ensure_loaded()
	_music_volume_percent = clampf(percent, 0.0, 100.0)
	_save()


static func get_sfx_volume_percent() -> float:
	_ensure_loaded()
	return _sfx_volume_percent


static func get_player_name() -> String:
	_ensure_loaded()
	return _player_name


static func set_player_name(value: String) -> void:
	_ensure_loaded()
	_player_name = _sanitize_player_name(value)
	_save()


static func get_leaderboard_api_url() -> String:
	_ensure_loaded()
	return _resolve_leaderboard_api_url(_leaderboard_api_url)


static func set_leaderboard_api_url(value: String) -> void:
	_ensure_loaded()
	_leaderboard_api_url = _sanitize_leaderboard_api_url(value)
	_save()


static func record_completed_run(summary: Dictionary) -> void:
	_ensure_loaded()
	if summary.is_empty():
		return

	var kills: int = max(0, int(summary.get("kills", 0)))
	var score: int = max(0, int(summary.get("score", 0)))
	var time_seconds: int = max(0, int(summary.get("time_seconds", 0)))
	var basement: int = max(1, int(summary.get("basement", 1)))

	_total_runs += 1
	_total_kills += kills
	_total_score += score
	_total_time_seconds += time_seconds
	_best_score = max(_best_score, score)
	_best_basement = max(_best_basement, basement)
	_last_score = score
	_last_basement = basement
	_save()


static func get_profile_stats() -> Dictionary:
	_ensure_loaded()
	return {
		"total_runs": _total_runs,
		"total_kills": _total_kills,
		"total_score": _total_score,
		"total_time_seconds": _total_time_seconds,
		"best_score": _best_score,
		"best_basement": _best_basement,
		"last_score": _last_score,
		"last_basement": _last_basement,
	}


static func set_sfx_volume_percent(percent: float) -> void:
	_ensure_loaded()
	_sfx_volume_percent = clampf(percent, 0.0, 100.0)
	_save()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true

	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return

	_music_volume_percent = float(config.get_value(SECTION_AUDIO, KEY_MUSIC_VOLUME, _music_volume_percent))
	_sfx_volume_percent = float(config.get_value(SECTION_AUDIO, KEY_SFX_VOLUME, _sfx_volume_percent))
	_player_name = _sanitize_player_name(str(config.get_value(SECTION_PROFILE, KEY_PLAYER_NAME, _player_name)))
	_leaderboard_api_url = _sanitize_leaderboard_api_url(str(config.get_value(SECTION_PROFILE, KEY_LEADERBOARD_API_URL, _leaderboard_api_url)))
	_total_runs = max(0, int(config.get_value(SECTION_STATS, KEY_TOTAL_RUNS, _total_runs)))
	_total_kills = max(0, int(config.get_value(SECTION_STATS, KEY_TOTAL_KILLS, _total_kills)))
	_total_score = max(0, int(config.get_value(SECTION_STATS, KEY_TOTAL_SCORE, _total_score)))
	_total_time_seconds = max(0, int(config.get_value(SECTION_STATS, KEY_TOTAL_TIME_SECONDS, _total_time_seconds)))
	_best_score = max(0, int(config.get_value(SECTION_STATS, KEY_BEST_SCORE, _best_score)))
	_best_basement = max(1, int(config.get_value(SECTION_STATS, KEY_BEST_BASEMENT, _best_basement)))
	_last_score = max(0, int(config.get_value(SECTION_STATS, KEY_LAST_SCORE, _last_score)))
	_last_basement = max(1, int(config.get_value(SECTION_STATS, KEY_LAST_BASEMENT, _last_basement)))


static func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_AUDIO, KEY_MUSIC_VOLUME, _music_volume_percent)
	config.set_value(SECTION_AUDIO, KEY_SFX_VOLUME, _sfx_volume_percent)
	config.set_value(SECTION_PROFILE, KEY_PLAYER_NAME, _player_name)
	config.set_value(SECTION_PROFILE, KEY_LEADERBOARD_API_URL, _sanitize_leaderboard_api_url(_leaderboard_api_url))
	config.set_value(SECTION_STATS, KEY_TOTAL_RUNS, _total_runs)
	config.set_value(SECTION_STATS, KEY_TOTAL_KILLS, _total_kills)
	config.set_value(SECTION_STATS, KEY_TOTAL_SCORE, _total_score)
	config.set_value(SECTION_STATS, KEY_TOTAL_TIME_SECONDS, _total_time_seconds)
	config.set_value(SECTION_STATS, KEY_BEST_SCORE, _best_score)
	config.set_value(SECTION_STATS, KEY_BEST_BASEMENT, _best_basement)
	config.set_value(SECTION_STATS, KEY_LAST_SCORE, _last_score)
	config.set_value(SECTION_STATS, KEY_LAST_BASEMENT, _last_basement)
	config.save(SETTINGS_PATH)


static func _sanitize_player_name(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed == "":
		return "Игрок BFU"
	if trimmed.length() > 24:
		return trimmed.substr(0, 24)
	return trimmed


static func _sanitize_leaderboard_api_url(value: String) -> String:
	var trimmed := value.strip_edges()
	if trimmed == "":
		return DEFAULT_LEADERBOARD_API_PATH if OS.has_feature("web") else ""
	return trimmed


static func _resolve_leaderboard_api_url(value: String) -> String:
	var normalized := _sanitize_leaderboard_api_url(value)
	if normalized == "":
		return ""
	if normalized.begins_with("http://") or normalized.begins_with("https://"):
		return normalized
	if not OS.has_feature("web"):
		return normalized
	if not Engine.has_singleton("JavaScriptBridge"):
		return normalized
	var escaped_path := normalized.replace("\\", "\\\\").replace("'", "\\'")
	var script := "new URL('%s', window.location.href).href" % escaped_path
	var resolved: Variant = JavaScriptBridge.eval(script)
	if resolved == null:
		return normalized
	var resolved_text := str(resolved).strip_edges()
	return resolved_text if resolved_text != "" else normalized
