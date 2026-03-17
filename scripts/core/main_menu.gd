extends Control

const RunState = preload("res://scripts/core/run_state.gd")
const SettingsStoreLib = preload("res://scripts/core/settings_store.gd")
const LeaderboardClientLib = preload("res://scripts/core/leaderboard_client.gd")

@export var game_scene_path: String = "res://scenes/Game.tscn"

@onready var tabs: TabContainer = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs
@onready var nickname_input: LineEdit = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Profile/NicknameInput
@onready var music_slider: HSlider = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Settings/MusicSlider
@onready var music_value_label: Label = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Settings/MusicValue
@onready var sfx_slider: HSlider = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Settings/SfxSlider
@onready var sfx_value_label: Label = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Settings/SfxValue
@onready var campaign_button: Button = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Play/CampaignButton
@onready var endless_button: Button = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Play/StartEndlessButton
@onready var profile_stats_label: Label = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Profile/ProfileStatsText
@onready var leaderboard_list: ItemList = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Leaderboard/LeaderboardList
@onready var leaderboard_status: Label = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Leaderboard/LeaderboardStatus
@onready var title_label: Label = $RootMargin/Scroll/Center/Shell/HeroCard/HeroMargin/HeroStack/Title
@onready var accent_label: Label = $RootMargin/Scroll/Center/Shell/HeroCard/HeroMargin/HeroStack/AccentLine
@onready var play_summary_label: Label = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Play/PlaySummary
@onready var profile_hint_label: Label = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Profile/ProfileHint
@onready var settings_hint_label: Label = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Settings/SettingsHint
@onready var leaderboard_hint_label: Label = $RootMargin/Scroll/Center/Shell/TabsCard/TabsMargin/Tabs/Leaderboard/LeaderboardHint

var _background_music = null


func _ready() -> void:
	_resolve_background_music()
	_load_saved_values()
	_refresh_profile_stats()
	campaign_button.disabled = true
	call_deferred("_refresh_leaderboard")


func _load_saved_values() -> void:
	nickname_input.text = SettingsStoreLib.get_player_name()

	var music_percent := SettingsStoreLib.get_music_volume_percent()
	var sfx_percent := SettingsStoreLib.get_sfx_volume_percent()
	music_slider.value = music_percent
	sfx_slider.value = sfx_percent
	_update_music_value(music_percent)
	_update_sfx_value(sfx_percent)
	_apply_music_volume(music_percent)
	_refresh_static_labels()


func _refresh_profile_stats() -> void:
	var stats := SettingsStoreLib.get_profile_stats()
	var total_time_seconds: int = int(stats.get("total_time_seconds", 0))
	var minutes: int = int(total_time_seconds / 60)
	var seconds: int = total_time_seconds % 60
	profile_stats_label.text = "Профиль игрока\n\nЗабегов: %d\nВсего убийств: %d\nОбщий счёт: %d\nЛучший счёт: %d\nЛучший подвал: %d\nВремя в игре: %02d:%02d\nПоследний счёт: %d" % [
		int(stats.get("total_runs", 0)),
		int(stats.get("total_kills", 0)),
		int(stats.get("total_score", 0)),
		int(stats.get("best_score", 0)),
		int(stats.get("best_basement", 1)),
		minutes,
		seconds,
		int(stats.get("last_score", 0)),
	]


func _save_profile_inputs() -> void:
	SettingsStoreLib.set_player_name(nickname_input.text)
	nickname_input.text = SettingsStoreLib.get_player_name()
	_refresh_static_labels()


func _refresh_static_labels() -> void:
	var player_name := SettingsStoreLib.get_player_name()
	if tabs != null:
		tabs.set_tab_title(0, "Игра")
		tabs.set_tab_title(1, "Профиль")
		tabs.set_tab_title(2, "Настройки")
		tabs.set_tab_title(3, "Рейтинг")
	if title_label != null:
		title_label.text = "Tears of BFU"
	if accent_label != null:
		accent_label.text = "%s спускается в подвал." % [player_name]
	if play_summary_label != null:
		play_summary_label.text = "Текущий режим: Бесконечный\nПрофиль: %s\nСинхронизация рейтинга выполняется автоматически." % [player_name]
	if profile_hint_label != null:
		profile_hint_label.text = "Этот ник используется для локальной статистики и отправки результатов в рейтинг."
	if settings_hint_label != null:
		settings_hint_label.text = "Настройки звука сохраняются сразу и применяются при следующем запуске."
	if leaderboard_hint_label != null:
		leaderboard_hint_label.text = "На сайте рейтинг синхронизируется онлайн. На компьютере автоматически используется локальная таблица."
	if endless_button != null:
		endless_button.text = "Начать бесконечный режим"
	if campaign_button != null:
		campaign_button.text = "Кампания (скоро)"
	if nickname_input != null:
		nickname_input.placeholder_text = "Введи ник"


func _refresh_leaderboard() -> void:
	_save_profile_inputs()
	leaderboard_status.text = "Загружаю рейтинг..."
	leaderboard_list.clear()

	var response := await LeaderboardClientLib.fetch_leaderboard(self, 20)
	if not bool(response.get("ok", false)):
		leaderboard_status.text = "Рейтинг недоступен: %s" % [str(response.get("error", "неизвестная ошибка"))]
		return

	var entries: Array = response.get("entries", [])
	if entries.is_empty():
		var empty_source := "локальном" if str(response.get("source", "")) == "local" else "глобальном"
		leaderboard_status.text = "В %s рейтинге пока нет результатов." % [empty_source]
		return

	leaderboard_status.text = "Локальный рейтинг" if str(response.get("source", "")) == "local" else "Глобальный рейтинг"
	var rank: int = 1
	for entry_variant in entries:
		var entry: Dictionary = entry_variant as Dictionary
		var player_name := str(entry.get("player_name", "Неизвестно"))
		var score := int(entry.get("score", 0))
		var kills := int(entry.get("kills", 0))
		var basement := int(entry.get("basement", 1))
		leaderboard_list.add_item("%02d. %s | Счёт %d | П%d | У%d" % [rank, player_name, score, basement, kills])
		rank += 1


func _start_endless_run() -> void:
	_save_profile_inputs()
	RunState.start_new_run("endless")
	get_tree().change_scene_to_file(game_scene_path)


func _resolve_background_music() -> void:
	_background_music = get_tree().get_first_node_in_group("background_music")


func _apply_music_volume(value: float) -> void:
	if _background_music == null:
		_resolve_background_music()
	if _background_music != null and _background_music.has_method("set_music_volume_percent"):
		_background_music.set_music_volume_percent(value)


func _update_music_value(value: float) -> void:
	music_value_label.text = "Музыка: %d%%" % [int(round(value))]


func _update_sfx_value(value: float) -> void:
	sfx_value_label.text = "Звуки: %d%%" % [int(round(value))]


func _on_start_endless_button_pressed() -> void:
	_start_endless_run()


func _on_refresh_leaderboard_button_pressed() -> void:
	_refresh_leaderboard()


func _on_music_slider_value_changed(value: float) -> void:
	SettingsStoreLib.set_music_volume_percent(value)
	_update_music_value(value)
	_apply_music_volume(value)


func _on_sfx_slider_value_changed(value: float) -> void:
	SettingsStoreLib.set_sfx_volume_percent(value)
	_update_sfx_value(value)


func _on_nickname_input_text_submitted(_new_text: String) -> void:
	_save_profile_inputs()
	_refresh_profile_stats()


func _on_nickname_input_focus_exited() -> void:
	_save_profile_inputs()
