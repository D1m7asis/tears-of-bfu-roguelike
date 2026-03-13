extends CanvasLayer

const BULLET_TIME_SHADER = preload("res://assets/shaders/bullet_time_overlay.gdshader")
const SfxLib = preload("res://scripts/core/sfx_library.gd")

@onready var heart_bar: Control = $VBoxContainer/HeartBar
@onready var key_label: Label = $VBoxContainer/KeyLabel
@onready var hint_label: Label = $VBoxContainer/HintLabel
@onready var bullet_time_bar: ProgressBar = $VBoxContainer/BulletTimeBar
@onready var bullet_time_label: Label = $VBoxContainer/BulletTimeLabel
@onready var minimap: Control = $Minimap
@onready var bullet_time_overlay: ColorRect = $BulletTimeOverlay
@onready var bullet_time_frame: Panel = $BulletTimeOverlay/BulletTimeFrame
@onready var bullet_time_banner: Label = $BulletTimeOverlay/TopCenter/BulletTimeStack/BulletTimeBanner
@onready var bullet_time_seconds: Label = $BulletTimeOverlay/TopCenter/BulletTimeStack/BulletTimeSeconds
@onready var bullet_time_meter: ProgressBar = $BulletTimeOverlay/BottomCenter/BulletTimeMeter
@onready var pause_overlay: ColorRect = $PauseOverlay
@onready var pause_panel: Panel = $PauseOverlay/PausePanel
@onready var music_slider: HSlider = $PauseOverlay/PausePanel/PauseContent/MusicSlider
@onready var music_value_label: Label = $PauseOverlay/PausePanel/PauseContent/MusicValueLabel
@onready var sfx_slider: HSlider = $PauseOverlay/PausePanel/PauseContent/SfxSlider
@onready var sfx_value_label: Label = $PauseOverlay/PausePanel/PauseContent/SfxValueLabel

var _background_music = null
var _pause_open: bool = false
var _bullet_time_tween: Tween = null
var _bullet_time_material: ShaderMaterial = null
var _bullet_time_overlay_tween: Tween = null
var _bullet_time_visual_strength: float = 0.0
var _bullet_time_overlay_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bullet_time_shader()
	update_health(0, 0)
	update_keys(0)
	update_bullet_time(0.0, 5.0, false)
	set_hint("WASD move, Arrows shoot, Space bullet time, Hold R restart, Esc pause")
	_resolve_background_music()
	_sync_music_slider()
	_sync_sfx_slider()
	_set_pause_open(false)

	var rm := get_tree().get_first_node_in_group("room_manager")
	if rm != null and minimap != null and minimap.has_method("bind_room_manager"):
		minimap.bind_room_manager(rm)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and not event.is_echo():
		_toggle_pause()
		get_viewport().set_input_as_handled()

func update_health(current: int, max_value: int = -1) -> void:
	if heart_bar == null or not heart_bar.has_method("set_health"):
		return
	if max_value < 0:
		max_value = current
	heart_bar.set_health(current, max_value)

func update_keys(value: int) -> void:
	key_label.text = "Keys: " + str(value)

func update_bullet_time(current: float, max_value: float, active: bool) -> void:
	if bullet_time_bar != null:
		bullet_time_bar.max_value = max_value
		bullet_time_bar.value = current
		bullet_time_bar.modulate = Color(0.6, 0.82, 1.0, 1.0) if active else Color(1, 1, 1, 1)
	if bullet_time_label != null:
		var seconds_text := str(snappedf(current, 0.1))
		if active:
			bullet_time_label.text = "Bullet Time: " + seconds_text + "s"
			bullet_time_label.modulate = Color(0.8, 0.95, 1.0, 1.0)
		else:
			bullet_time_label.text = "Focus: " + seconds_text + "s"
			bullet_time_label.modulate = Color(0.839216, 0.886275, 0.980392, 1)

	_update_bullet_time_overlay(current, max_value, active)

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
		_sync_sfx_slider()
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

func _sync_sfx_slider() -> void:
	if sfx_slider == null:
		return

	var percent := SfxLib.get_sfx_volume_percent()
	sfx_slider.value = percent
	_update_sfx_value_label(percent)

func _update_sfx_value_label(percent: float) -> void:
	if sfx_value_label != null:
		sfx_value_label.text = "SFX: " + str(int(round(percent))) + "%"

func _on_music_slider_value_changed(value: float) -> void:
	_update_music_value_label(value)
	if _background_music == null:
		_resolve_background_music()
	if _background_music != null and _background_music.has_method("set_music_volume_percent"):
		_background_music.set_music_volume_percent(value)

func _on_sfx_slider_value_changed(value: float) -> void:
	_update_sfx_value_label(value)
	SfxLib.set_sfx_volume_percent(value)

func _on_resume_button_pressed() -> void:
	_set_pause_open(false)

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _update_bullet_time_overlay(current: float, max_value: float, active: bool) -> void:
	var percent := 0.0
	if max_value > 0.0:
		percent = current / max_value

	if bullet_time_meter != null:
		bullet_time_meter.max_value = max_value
		bullet_time_meter.value = current

	if bullet_time_seconds != null:
		bullet_time_seconds.text = str(snappedf(current, 0.1)) + "s"

	_set_bullet_time_charge_ratio(percent)
	_animate_bullet_time_overlay(active)

func _start_bullet_time_tween() -> void:
	if bullet_time_banner == null:
		return
	if _bullet_time_tween != null:
		return

	_bullet_time_tween = create_tween()
	_bullet_time_tween.set_loops()
	_bullet_time_tween.set_trans(Tween.TRANS_SINE)
	_bullet_time_tween.set_ease(Tween.EASE_IN_OUT)
	_bullet_time_tween.tween_property(bullet_time_banner, "scale", Vector2(1.03, 1.03), 0.35)
	_bullet_time_tween.parallel().tween_property(bullet_time_banner, "modulate:a", 0.82, 0.35)
	_bullet_time_tween.tween_property(bullet_time_banner, "scale", Vector2.ONE, 0.35)
	_bullet_time_tween.parallel().tween_property(bullet_time_banner, "modulate:a", 1.0, 0.35)

func _stop_bullet_time_tween() -> void:
	if _bullet_time_tween != null:
		_bullet_time_tween.kill()
		_bullet_time_tween = null
	if bullet_time_banner != null:
		bullet_time_banner.scale = Vector2.ONE
		bullet_time_banner.modulate.a = 1.0

func _setup_bullet_time_shader() -> void:
	if bullet_time_overlay == null:
		return

	_bullet_time_material = ShaderMaterial.new()
	_bullet_time_material.shader = BULLET_TIME_SHADER
	bullet_time_overlay.material = _bullet_time_material
	_set_bullet_time_shader_params(0.0, 1.0)

func _set_bullet_time_shader_params(strength: float, charge_ratio: float) -> void:
	if _bullet_time_material == null:
		return

	_bullet_time_material.set_shader_parameter("active_strength", strength)
	_bullet_time_material.set_shader_parameter("charge_ratio", clampf(charge_ratio, 0.0, 1.0))

func _set_bullet_time_charge_ratio(charge_ratio: float) -> void:
	_set_bullet_time_shader_params(_bullet_time_visual_strength, charge_ratio)
	if bullet_time_overlay != null:
		bullet_time_overlay.modulate = Color(1, 1, 1, (0.68 + (1.0 - charge_ratio) * 0.16) * _bullet_time_visual_strength)
	if bullet_time_frame != null:
		bullet_time_frame.modulate = Color(0.62, 0.86, 1.0, (0.18 + (1.0 - charge_ratio) * 0.24) * _bullet_time_visual_strength)
	if bullet_time_banner != null:
		bullet_time_banner.modulate = Color(0.78 + (1.0 - charge_ratio) * 0.12, 0.94, 1.0, 0.65 + _bullet_time_visual_strength * 0.35)
	if bullet_time_meter != null:
		bullet_time_meter.modulate = Color(0.58, 0.88, 1.0, 0.72 + _bullet_time_visual_strength * 0.28)

func _animate_bullet_time_overlay(active: bool) -> void:
	if bullet_time_overlay == null:
		return
	if _bullet_time_overlay_active == active:
		return
	_bullet_time_overlay_active = active

	if _bullet_time_overlay_tween != null:
		_bullet_time_overlay_tween.kill()
		_bullet_time_overlay_tween = null

	bullet_time_overlay.visible = true

	var target_strength := 0.0
	var duration := 0.12
	if active:
		target_strength = 1.0
		duration = 0.2
		_start_bullet_time_tween()
	else:
		_stop_bullet_time_tween()

	_bullet_time_overlay_tween = create_tween()
	_bullet_time_overlay_tween.set_trans(Tween.TRANS_SINE)
	_bullet_time_overlay_tween.set_ease(Tween.EASE_IN_OUT)
	_bullet_time_overlay_tween.tween_method(_set_bullet_time_visual_strength, _bullet_time_visual_strength, target_strength, duration)

	if not active:
		_bullet_time_overlay_tween.finished.connect(_on_bullet_time_overlay_hidden)

func _set_bullet_time_visual_strength(value: float) -> void:
	_bullet_time_visual_strength = clampf(value, 0.0, 1.0)
	var charge_ratio := 1.0
	if bullet_time_meter != null and bullet_time_meter.max_value > 0.0:
		charge_ratio = bullet_time_meter.value / bullet_time_meter.max_value
	_set_bullet_time_charge_ratio(charge_ratio)

func _on_bullet_time_overlay_hidden() -> void:
	if _bullet_time_visual_strength <= 0.001 and bullet_time_overlay != null:
		bullet_time_overlay.visible = false
