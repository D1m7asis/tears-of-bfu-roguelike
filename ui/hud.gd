extends CanvasLayer

@onready var health_label: Label = $VBoxContainer/HealthLabel
@onready var key_label: Label = $VBoxContainer/KeyLabel
@onready var hint_label: Label = $VBoxContainer/HintLabel
@onready var minimap: Control = $Minimap
@onready var pause_overlay: ColorRect = $PauseOverlay
@onready var pause_panel: Panel = $PauseOverlay/PausePanel
@onready var music_slider: HSlider = $PauseOverlay/PausePanel/PauseContent/MusicSlider
@onready var music_value_label: Label = $PauseOverlay/PausePanel/PauseContent/MusicValueLabel

var _background_music = null
var _pause_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	update_health(0)
	update_keys(0)
	set_hint("WASD move, Arrows shoot, Hold R restart, Esc pause")
	_resolve_background_music()
	_sync_music_slider()
	_set_pause_open(false)

	var rm := get_tree().get_first_node_in_group("room_manager")
	if rm != null and minimap != null and minimap.has_method("bind_room_manager"):
		minimap.bind_room_manager(rm)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and not event.is_echo():
		_toggle_pause()
		get_viewport().set_input_as_handled()

func update_health(value: int) -> void:
	health_label.text = "HP: " + str(value)

func update_keys(value: int) -> void:
	key_label.text = "Keys: " + str(value)

func set_hint(text: String) -> void:
	hint_label.text = text

func clear_hint() -> void:
	hint_label.text = ""

func _toggle_pause() -> void:
	_set_pause_open(not _pause_open)

func _set_pause_open(open: bool) -> void:
	_pause_open = open
	if pause_overlay != null:
		pause_overlay.visible = open
	if pause_panel != null:
		pause_panel.visible = open
	if open:
		_sync_music_slider()
	get_tree().paused = open

func _resolve_background_music() -> void:
	_background_music = get_tree().get_first_node_in_group("background_music")

func _sync_music_slider() -> void:
	if music_slider == null:
		return
	if _background_music == null:
		_resolve_background_music()

	var percent := 50.0
	if _background_music != null and _background_music.has_method("get_music_volume_percent"):
		percent = _background_music.get_music_volume_percent()

	music_slider.value = percent
	_update_music_value_label(percent)

func _update_music_value_label(percent: float) -> void:
	if music_value_label != null:
		music_value_label.text = "Music: " + str(int(round(percent))) + "%"

func _on_music_slider_value_changed(value: float) -> void:
	_update_music_value_label(value)
	if _background_music == null:
		_resolve_background_music()
	if _background_music != null and _background_music.has_method("set_music_volume_percent"):
		_background_music.set_music_volume_percent(value)

func _on_resume_button_pressed() -> void:
	_set_pause_open(false)

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
