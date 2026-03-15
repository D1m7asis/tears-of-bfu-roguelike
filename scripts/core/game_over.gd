extends Control

const RunState = preload("res://scripts/core/run_state.gd")

@export var restart_scene_path: String = "res://scenes/Game.tscn"

@onready var prompt: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Prompt
@onready var summary: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Summary

func _ready() -> void:
	var death_summary: Dictionary = RunState.consume_death_summary()
	if summary != null:
		var kills: int = int(death_summary.get("kills", 0))
		var score: int = int(death_summary.get("score", 0))
		var time_seconds: int = int(death_summary.get("time_seconds", 0.0))
		var basement: int = int(death_summary.get("basement", 1))
		var minutes: int = int(time_seconds / 60)
		var seconds: int = time_seconds % 60
		summary.text = "Kills: %d\nScore: %d\nTime: %02d:%02d\nReached Basement: %d" % [kills, score, minutes, seconds, basement]
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(prompt, "modulate:a", 0.35, 0.8)
	tween.tween_property(prompt, "modulate:a", 1.0, 0.8)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_hold") or event.is_action_pressed("ui_accept"):
		RunState.reset_run()
		get_tree().change_scene_to_file(restart_scene_path)
