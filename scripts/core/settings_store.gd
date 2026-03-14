extends RefCounted
class_name SettingsStore

const SETTINGS_PATH := "user://settings.cfg"
const SECTION_AUDIO := "audio"
const KEY_MUSIC_VOLUME := "music_volume_percent"
const KEY_SFX_VOLUME := "sfx_volume_percent"

static var _loaded: bool = false
static var _music_volume_percent: float = 55.0
static var _sfx_volume_percent: float = 75.0


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


static func _save() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION_AUDIO, KEY_MUSIC_VOLUME, _music_volume_percent)
	config.set_value(SECTION_AUDIO, KEY_SFX_VOLUME, _sfx_volume_percent)
	config.save(SETTINGS_PATH)
