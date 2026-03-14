extends CanvasLayer

const BULLET_TIME_SHADER = preload("res://assets/shaders/bullet_time_overlay.gdshader")
const SfxLib = preload("res://scripts/core/sfx_library.gd")

@onready var heart_bar: Control = $VBoxContainer/HeartBar
@onready var key_label: Label = $VBoxContainer/KeyLabel
@onready var hint_label: Label = $VBoxContainer/HintLabel
@onready var active_item_panel: Panel = $VBoxContainer/ActiveItemPanel
@onready var active_item_icon: TextureRect = $VBoxContainer/ActiveItemPanel/ActiveItemRow/ActiveItemIcon
@onready var active_item_name: Label = $VBoxContainer/ActiveItemPanel/ActiveItemRow/ActiveItemText/ActiveItemName
@onready var active_item_state: Label = $VBoxContainer/ActiveItemPanel/ActiveItemRow/ActiveItemText/ActiveItemState
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
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var item_card: Panel = $ItemCard
@onready var item_card_icon: TextureRect = $ItemCard/CardMargin/CardRow/CardIcon
@onready var item_card_title: Label = $ItemCard/CardMargin/CardRow/CardText/CardTitle
@onready var item_card_lines: Label = $ItemCard/CardMargin/CardRow/CardText/CardLines
@onready var pickup_hint_label: Label = $PickupHint
@onready var cinematic_backdrop: ColorRect = $CinematicBackdrop
@onready var cinematic_banner: Label = $CinematicBanner
@onready var collected_items_container: GridContainer = $VBoxContainer/CollectedItems

var _background_music = null
var _pause_open: bool = false
var _bullet_time_tween: Tween = null
var _bullet_time_material: ShaderMaterial = null
var _bullet_time_overlay_tween: Tween = null
var _bullet_time_visual_strength: float = 0.0
var _bullet_time_overlay_active: bool = false
var _item_card_tween: Tween = null
var _banner_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bullet_time_shader()
	update_health(0, 0)
	update_keys(0)
	update_active_item(null, 0.0)
	update_bullet_time(0.0, 5.0, false)
	update_player_stats({})
	set_hint("WASD move, Arrows shoot, Shift bullet time, Space active item, Hold R restart, Esc pause")
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

func update_active_item(item: ItemData, cooldown_remaining: float) -> void:
	if active_item_panel == null:
		return
	if item == null:
		active_item_panel.visible = false
		return
	active_item_panel.visible = true
	if active_item_icon != null:
		active_item_icon.texture = item.icon
	if active_item_name != null:
		active_item_name.text = item.display_name
	if active_item_state != null:
		active_item_state.text = "Ready [Space]" if cooldown_remaining <= 0.0 else "Cooldown %.1fs" % [cooldown_remaining]

func update_player_stats(stats: Dictionary) -> void:
	if stats_label == null:
		return
	var damage := int(stats.get("damage", 1))
	var ats := float(stats.get("attack_speed", 0.0))
	var max_hp := int(stats.get("max_health", 0))
	stats_label.text = "DMG %d   ATS %.1f   MAX HP %d" % [damage, ats, max_hp]

func update_collected_items(items: Array) -> void:
	if collected_items_container == null:
		return
	for child in collected_items_container.get_children():
		child.queue_free()
	for item_variant in items:
		var item := item_variant as ItemData
		if item == null or item.icon == null:
			continue
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(22, 22)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = item.icon
		var tooltip_lines := PackedStringArray()
		if item.damage_delta != 0:
			tooltip_lines.append("DMG %s%d" % ["+" if item.damage_delta > 0 else "", item.damage_delta])
		if item.attack_speed_delta != 0.0:
			tooltip_lines.append("ATS %s%.1f" % ["+" if item.attack_speed_delta > 0.0 else "", item.attack_speed_delta])
		if item.max_health_delta != 0:
			tooltip_lines.append("MAX HP %s%d" % ["+" if item.max_health_delta > 0 else "", item.max_health_delta])
		icon.tooltip_text = item.display_name + ("\n" + "\n".join(tooltip_lines) if not tooltip_lines.is_empty() else "")
		collected_items_container.add_child(icon)

func show_passive_item_card(item: ItemData) -> void:
	if item_card == null or item == null:
		return

	if _item_card_tween != null:
		_item_card_tween.kill()
		_item_card_tween = null

	item_card.visible = true
	item_card.modulate.a = 0.0
	item_card.scale = Vector2(0.95, 0.95)

	if item_card_icon != null:
		item_card_icon.texture = item.icon
	if item_card_title != null:
		item_card_title.text = item.display_name
	if item_card_lines != null:
		item_card_lines.text = "\n".join(_build_item_display_lines(item))

	_item_card_tween = create_tween()
	_item_card_tween.set_trans(Tween.TRANS_SINE)
	_item_card_tween.set_ease(Tween.EASE_OUT)
	_item_card_tween.parallel().tween_property(item_card, "modulate:a", 1.0, 0.16)
	_item_card_tween.parallel().tween_property(item_card, "scale", Vector2.ONE, 0.16)
	_item_card_tween.tween_interval(1.9)
	_item_card_tween.set_ease(Tween.EASE_IN)
	_item_card_tween.parallel().tween_property(item_card, "modulate:a", 0.0, 0.18)
	_item_card_tween.parallel().tween_property(item_card, "scale", Vector2(0.98, 0.98), 0.18)
	_item_card_tween.finished.connect(func() -> void:
		if item_card != null:
			item_card.visible = false
	)

func _build_item_display_lines(item: ItemData) -> PackedStringArray:
	var lines := PackedStringArray()
	if item == null:
		return lines
	if item.pickup_kind == "active_item" and not item.display_lines.is_empty():
		return item.display_lines
	if item.damage_delta != 0:
		lines.append("DMG %s%d" % ["+" if item.damage_delta > 0 else "", item.damage_delta])
	if item.attack_speed_delta != 0.0:
		lines.append("ATS %s%.1f" % ["+" if item.attack_speed_delta > 0.0 else "", item.attack_speed_delta])
	if item.max_health_delta != 0:
		lines.append("MAX HP %s%d" % ["+" if item.max_health_delta > 0 else "", item.max_health_delta])
	if lines.is_empty():
		return item.display_lines
	return lines

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

func set_pickup_hint(text: String) -> void:
	if pickup_hint_label == null:
		return
	pickup_hint_label.visible = text != ""
	pickup_hint_label.text = text

func clear_hint() -> void:
	hint_label.text = ""

func play_cinematic_banner(text: String, duration: float = 1.8) -> void:
	if cinematic_banner == null:
		return
	if _banner_tween != null:
		_banner_tween.kill()
	_banner_tween = create_tween()
	if cinematic_backdrop != null:
		cinematic_backdrop.visible = true
		cinematic_backdrop.modulate.a = 0.0
	cinematic_banner.visible = true
	cinematic_banner.text = text
	cinematic_banner.modulate.a = 0.0
	cinematic_banner.scale = Vector2(0.88, 0.88)
	_banner_tween.set_trans(Tween.TRANS_SINE)
	_banner_tween.set_ease(Tween.EASE_OUT)
	if cinematic_backdrop != null:
		_banner_tween.parallel().tween_property(cinematic_backdrop, "modulate:a", 1.0, 0.22)
	_banner_tween.parallel().tween_property(cinematic_banner, "modulate:a", 1.0, 0.18)
	_banner_tween.parallel().tween_property(cinematic_banner, "scale", Vector2.ONE, 0.18)
	_banner_tween.tween_interval(duration)
	_banner_tween.set_ease(Tween.EASE_IN)
	if cinematic_backdrop != null:
		_banner_tween.parallel().tween_property(cinematic_backdrop, "modulate:a", 0.0, 0.28)
	_banner_tween.parallel().tween_property(cinematic_banner, "modulate:a", 0.0, 0.22)
	_banner_tween.parallel().tween_property(cinematic_banner, "scale", Vector2(1.04, 1.04), 0.22)
	await _banner_tween.finished
	if cinematic_banner != null:
		cinematic_banner.visible = false
	if cinematic_backdrop != null:
		cinematic_backdrop.visible = false

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
