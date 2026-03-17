extends Control

const RunState = preload("res://scripts/core/run_state.gd")
const SettingsStoreLib = preload("res://scripts/core/settings_store.gd")
const LeaderboardClientLib = preload("res://scripts/core/leaderboard_client.gd")

@export var restart_scene_path: String = "res://scenes/Game.tscn"
@export var menu_scene_path: String = "res://scenes/MainMenu.tscn"

@onready var prompt: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Prompt
@onready var summary: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Summary
@onready var submit_status: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/SubmitStatus

func _ready() -> void:
	var death_summary: Dictionary = RunState.consume_death_summary()
	SettingsStoreLib.record_completed_run(death_summary)
	if summary != null:
		var kills: int = int(death_summary.get("kills", 0))
		var score: int = int(death_summary.get("score", 0))
		var time_seconds: int = int(death_summary.get("time_seconds", 0.0))
		var basement: int = int(death_summary.get("basement", 1))
		var minutes: int = int(time_seconds / 60)
		var seconds: int = time_seconds % 60
		summary.text = "Убийства: %d\nСчёт: %d\nВремя: %02d:%02d\nДостигнут подвал: %d" % [kills, score, minutes, seconds, basement]
	if submit_status != null:
		submit_status.text = "Отправляю результат..."
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(prompt, "modulate:a", 0.35, 0.8)
	tween.tween_property(prompt, "modulate:a", 1.0, 0.8)
	if not death_summary.is_empty():
		call_deferred("_submit_run", death_summary)
	else:
		submit_status.text = "Нет данных забега для отправки."


func _submit_run(death_summary: Dictionary) -> void:
	var response := await LeaderboardClientLib.submit_run(self, death_summary, RunState.current_mode)
	if submit_status == null:
		return
	if bool(response.get("ok", false)):
		submit_status.text = "Результат отправлен в рейтинг."
	else:
		submit_status.text = "Не удалось синхронизировать рейтинг: %s" % [str(response.get("error", "неизвестная ошибка"))]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_hold") or event.is_action_pressed("ui_accept"):
		RunState.start_new_run("endless")
		get_tree().change_scene_to_file(restart_scene_path)
	elif event.is_action_pressed("pause_game"):
		RunState.reset_run()
		get_tree().change_scene_to_file(menu_scene_path)
