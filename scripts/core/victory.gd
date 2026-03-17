extends Control

const RunState = preload("res://scripts/core/run_state.gd")

@export var restart_scene_path: String = "res://scenes/Game.tscn"
@export var menu_scene_path: String = "res://scenes/MainMenu.tscn"

@onready var prompt: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Prompt

func _ready() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(prompt, "modulate:a", 0.45, 0.8)
	tween.tween_property(prompt, "modulate:a", 1.0, 0.8)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_hold") or event.is_action_pressed("ui_accept"):
		RunState.start_new_run("endless")
		get_tree().change_scene_to_file(restart_scene_path)
	elif event.is_action_pressed("pause_game"):
		RunState.reset_run()
		get_tree().change_scene_to_file(menu_scene_path)
