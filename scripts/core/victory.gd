extends Control

@export var restart_scene_path: String = "res://scenes/Game.tscn"

@onready var prompt: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/Prompt

func _ready() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(prompt, "modulate:a", 0.45, 0.8)
	tween.tween_property(prompt, "modulate:a", 1.0, 0.8)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart_hold") or event.is_action_pressed("ui_accept"):
		get_tree().change_scene_to_file(restart_scene_path)
