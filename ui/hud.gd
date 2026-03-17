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
@onready var item_card_lines: RichTextLabel = $ItemCard/CardMargin/CardRow/CardText/CardLines
@onready var pickup_hint_label: RichTextLabel = $PickupHint
@onready var cinematic_backdrop: ColorRect = $CinematicBackdrop
@onready var cinematic_banner: Label = $CinematicBanner
@onready var collected_items_container: GridContainer = $VBoxContainer/CollectedItems
@onready var run_meta_label: Label = $TopRight/RunMetaLabel
@onready var inventory_overlay: ColorRect = $InventoryOverlay
@onready var inventory_active_icon: TextureRect = $InventoryOverlay/InventoryPanel/InventoryMargin/InventoryContent/InventoryActiveRow/InventoryActiveIcon
@onready var inventory_active_name: Label = $InventoryOverlay/InventoryPanel/InventoryMargin/InventoryContent/InventoryActiveRow/InventoryActiveText/InventoryActiveName
@onready var inventory_active_state: Label = $InventoryOverlay/InventoryPanel/InventoryMargin/InventoryContent/InventoryActiveRow/InventoryActiveText/InventoryActiveState
@onready var inventory_stackables_label: Label = $InventoryOverlay/InventoryPanel/InventoryMargin/InventoryContent/InventoryColumns/InventoryStackables
@onready var inventory_stats_left_label: Label = $InventoryOverlay/InventoryPanel/InventoryMargin/InventoryContent/InventoryColumns/InventoryStatsColumns/InventoryStatsLeft
@onready var inventory_stats_right_label: Label = $InventoryOverlay/InventoryPanel/InventoryMargin/InventoryContent/InventoryColumns/InventoryStatsColumns/InventoryStatsRight
@onready var inventory_passives_grid: GridContainer = $InventoryOverlay/InventoryPanel/InventoryMargin/InventoryContent/InventoryPassivesScroll/InventoryPassives

var _background_music = null
var _pause_open: bool = false
var _bullet_time_tween: Tween = null
var _bullet_time_material: ShaderMaterial = null
var _bullet_time_overlay_tween: Tween = null
var _bullet_time_visual_strength: float = 0.0
var _bullet_time_overlay_active: bool = false
var _item_card_tween: Tween = null
var _banner_tween: Tween = null
var _inventory_open: bool = false

const POSITIVE_STAT_COLOR := "#7CFF8D"
const NEGATIVE_STAT_COLOR := "#FF6B6B"
const NEUTRAL_STAT_COLOR := "#D8E2F4"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_bullet_time_shader()
	update_health(0, 0)
	update_keys(0)
	update_active_item(null, 0.0)
	update_bullet_time(0.0, 5.0, false)
	update_player_stats({})
	update_run_meta(0.0, 0, 1)
	set_hint("WASD - движение, стрелки - стрельба, Shift - фокус, E - активный предмет, Q - инвентарь, удерживай R - рестарт, Esc - пауза")
	_resolve_background_music()
	_sync_music_slider()
	_sync_sfx_slider()
	_set_pause_open(false)
	set_inventory_open(false)

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
	key_label.text = "Ключи: " + str(value)

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
		active_item_name.text = item.get_localized_name()
	var rarity_color: Color = item.get_rarity_color() if item != null else Color.WHITE
	active_item_panel.modulate = rarity_color
	if active_item_icon != null:
		active_item_icon.modulate = rarity_color
	if active_item_name != null:
		active_item_name.modulate = rarity_color
	if active_item_state != null:
		active_item_state.text = "Готово [E]" if cooldown_remaining <= 0.0 else "Перезарядка %.1f с" % [cooldown_remaining]
		active_item_state.modulate = rarity_color.lightened(0.12)

func update_player_stats(stats: Dictionary) -> void:
	if stats_label == null:
		return
	var damage := int(stats.get("damage", 1))
	var ats := float(stats.get("attack_speed", 0.0))
	var max_hp := int(stats.get("max_health", 0))
	var move_speed := int(round(float(stats.get("move_speed", 0.0))))
	stats_label.text = "УРОН %d   СКОР. АТКИ %.1f   МАКС. HP %d   СКОРОСТЬ %d" % [damage, ats, max_hp, move_speed]


func update_run_meta(elapsed_seconds: float, score: int, basement: int) -> void:
	if run_meta_label == null:
		return
	var total_seconds: int = int(maxf(0.0, elapsed_seconds))
	var minutes: int = int(total_seconds / 60)
	var seconds: int = total_seconds % 60
	run_meta_label.text = "ПОДВАЛ %d\nВРЕМЯ %02d:%02d\nСЧЁТ %d" % [basement, minutes, seconds, score]

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
		var tooltip_lines := item.build_stat_lines()
		icon.tooltip_text = item.get_localized_name() + ("\n" + "\n".join(tooltip_lines) if not tooltip_lines.is_empty() else "")
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
		item_card_icon.modulate = item.get_rarity_color() if item.pickup_kind == "active_item" else Color.WHITE
	if item_card_title != null:
		item_card_title.text = item.get_localized_name()
		item_card_title.modulate = item.get_rarity_color() if item.pickup_kind == "active_item" else Color(1, 0.95, 0.86, 1)
	if item_card_lines != null:
		item_card_lines.clear()
		item_card_lines.bbcode_enabled = true
		item_card_lines.fit_content = true
		item_card_lines.scroll_active = false
		item_card_lines.text = _build_item_display_bbcode(item)
	if item_card != null:
		item_card.modulate = item.get_rarity_color().lightened(0.05) if item.pickup_kind == "active_item" else Color.WHITE

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
	if item == null:
		return PackedStringArray()
	return item.build_stat_lines()


func _build_item_display_bbcode(item: ItemData) -> String:
	if item == null:
		return ""
	return _entries_to_bbcode(item.build_stat_entries())

func update_bullet_time(current: float, max_value: float, active: bool) -> void:
	if bullet_time_bar != null:
		bullet_time_bar.max_value = max_value
		bullet_time_bar.value = current
		bullet_time_bar.modulate = Color(0.6, 0.82, 1.0, 1.0) if active else Color(1, 1, 1, 1)
	if bullet_time_label != null:
		var seconds_text := str(snappedf(current, 0.1))
		if active:
			bullet_time_label.text = "Фокус: " + seconds_text + " с"
			bullet_time_label.modulate = Color(0.8, 0.95, 1.0, 1.0)
		else:
			bullet_time_label.text = "Заряд фокуса: " + seconds_text + " с"
			bullet_time_label.modulate = Color(0.839216, 0.886275, 0.980392, 1)

	_update_bullet_time_overlay(current, max_value, active)

func set_hint(text: String) -> void:
	hint_label.text = text

func set_pickup_hint(text: String, world_position: Vector2 = Vector2.ZERO) -> void:
	if pickup_hint_label == null:
		return
	pickup_hint_label.bbcode_enabled = true
	pickup_hint_label.fit_content = true
	pickup_hint_label.scroll_active = false
	pickup_hint_label.text = text
	pickup_hint_label.visible = text != ""
	if text == "":
		return

	var max_hint_width := 420.0
	pickup_hint_label.size = Vector2(max_hint_width, 0.0)
	var measured_size := pickup_hint_label.get_minimum_size()
	var hint_size := Vector2(max_hint_width, maxf(58.0, measured_size.y + 10.0))
	pickup_hint_label.size = hint_size

	var canvas_transform := get_viewport().get_canvas_transform()
	var screen_position: Vector2 = canvas_transform * world_position
	var target_position := screen_position + Vector2(-hint_size.x * 0.5, -hint_size.y - 16.0)
	var viewport_rect := get_viewport().get_visible_rect()
	target_position.x = clampf(target_position.x, 8.0, viewport_rect.size.x - hint_size.x - 8.0)
	target_position.y = clampf(target_position.y, 8.0, viewport_rect.size.y - hint_size.y - 8.0)
	pickup_hint_label.position = target_position

func clear_hint() -> void:
	hint_label.text = ""


func set_inventory_open(open: bool) -> void:
	_inventory_open = open
	if inventory_overlay != null:
		inventory_overlay.visible = open


func is_inventory_open() -> bool:
	return _inventory_open


func update_inventory_view(active_item: ItemData, inventory: Array, passive_items: Array, stats: Dictionary) -> void:
	if inventory_active_icon != null:
		inventory_active_icon.texture = null if active_item == null else active_item.icon
		inventory_active_icon.modulate = Color.WHITE if active_item == null else active_item.get_rarity_color()
	if inventory_active_name != null:
		inventory_active_name.text = "Нет активного предмета" if active_item == null else active_item.get_localized_name()
		inventory_active_name.modulate = Color(0.95, 0.92, 0.84, 1.0) if active_item == null else active_item.get_rarity_color()
	if inventory_active_state != null:
		if active_item == null:
			inventory_active_state.text = "Слот пуст"
		else:
			var active_lines: PackedStringArray = _build_item_display_lines(active_item)
			inventory_active_state.text = "Нажми E для активации" if active_lines.is_empty() else "Нажми E для активации\n" + "\n".join(active_lines)

	if inventory_stackables_label != null:
		var stack_lines: PackedStringArray = PackedStringArray()
		for slot_variant in inventory:
			var slot: Dictionary = slot_variant
			var item: ItemData = slot.get("data", null)
			if item == null:
				continue
			var count: int = int(slot.get("count", 0))
			stack_lines.append("%s x%d" % [item.get_localized_name(), count])
		inventory_stackables_label.text = "РАСХОДНИКИ\nПока пусто" if stack_lines.is_empty() else "РАСХОДНИКИ\n" + "\n".join(stack_lines)

	if inventory_stats_left_label != null:
		var left_lines: PackedStringArray = PackedStringArray([
			"АТАКА",
			"Урон за выстрел: %d" % [int(stats.get("damage", 1))],
			"Скорость атаки: %.2f" % [float(stats.get("attack_speed", 0.0))],
			"Доп. снаряды: %d" % [int(stats.get("extra_shots", 0))],
			"Скорость пули: %d" % [int(round(float(stats.get("projectile_speed", 0.0))))],
			"Перезар. активки: x%.2f" % [float(stats.get("active_cooldown_multiplier", 1.0))],
		])
		inventory_stats_left_label.text = "\n".join(left_lines)

	if inventory_stats_right_label != null:
		var right_lines: PackedStringArray = PackedStringArray([
			"ЖИВУЧЕСТЬ",
			"Максимум HP: %d" % [int(stats.get("max_health", 0))],
			"Скорость: %d" % [int(round(float(stats.get("move_speed", 0.0))))],
			"Броня: %d" % [int(stats.get("armor", 0))],
			"Лечение за килл: %d" % [int(stats.get("heal_on_kill", 0))],
			"Ёмкость фокуса: %.1f" % [float(stats.get("focus_max", 0.0))],
			"Фокус за килл: %.1f" % [float(stats.get("focus_kill_gain", 0.0))],
		])
		inventory_stats_right_label.text = "\n".join(right_lines)

	if inventory_passives_grid != null:
		for child in inventory_passives_grid.get_children():
			child.queue_free()
		var passive_counts: Dictionary = {}
		var passive_items_by_path: Dictionary = {}
		for item_variant in passive_items:
			var passive_item := item_variant as ItemData
			if passive_item == null:
				continue
			var path: String = passive_item.resource_path
			if path == "":
				path = passive_item.get_localized_name()
			passive_counts[path] = int(passive_counts.get(path, 0)) + 1
			passive_items_by_path[path] = passive_item
		for path in passive_counts.keys():
			var passive_item: ItemData = passive_items_by_path[path]
			if passive_item == null:
				continue
			var slot_root := PanelContainer.new()
			slot_root.custom_minimum_size = Vector2(0, 72)
			slot_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			slot_root.add_child(row)
			var icon := TextureRect.new()
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(38, 38)
			icon.texture = passive_item.icon
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(icon)
			var text_box := VBoxContainer.new()
			text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(text_box)
			var title := Label.new()
			title.text = passive_item.get_localized_name() + (" x%d" % [int(passive_counts[path])] if int(passive_counts[path]) > 1 else "")
			title.add_theme_font_size_override("font_size", 14)
			title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.84, 1.0))
			text_box.add_child(title)
			var detail := RichTextLabel.new()
			detail.bbcode_enabled = true
			detail.fit_content = true
			detail.scroll_active = false
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			detail.custom_minimum_size = Vector2(0, 0)
			detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			detail.add_theme_font_size_override("normal_font_size", 12)
			var passive_entries: Array[Dictionary] = passive_item.build_stat_entries()
			var count: int = int(passive_counts[path])
			var scaled_entries: Array[Dictionary] = []
			for entry_variant in passive_entries:
				var entry: Dictionary = entry_variant.duplicate(true)
				if count > 1:
					entry["text"] = "%s  (x%d)" % [str(entry.get("text", "")), count]
				scaled_entries.append(entry)
			if scaled_entries.is_empty():
				detail.text = "[color=%s]Нет числовых бонусов[/color]" % NEUTRAL_STAT_COLOR
			else:
				detail.text = _entries_to_bbcode(scaled_entries)
			icon.tooltip_text = passive_item.get_localized_name() + ("\n" + "\n".join(_entry_texts(scaled_entries)) if not scaled_entries.is_empty() else "")
			text_box.add_child(detail)
			inventory_passives_grid.add_child(slot_root)

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
		music_value_label.text = "Музыка: " + str(int(round(percent))) + "%"

func _sync_sfx_slider() -> void:
	if sfx_slider == null:
		return

	var percent := SfxLib.get_sfx_volume_percent()
	sfx_slider.value = percent
	_update_sfx_value_label(percent)

func _update_sfx_value_label(percent: float) -> void:
	if sfx_value_label != null:
		sfx_value_label.text = "Звуки: " + str(int(round(percent))) + "%"

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


func _entries_to_bbcode(entries: Array[Dictionary]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		var text := str(entry.get("text", ""))
		if text == "":
			continue
		lines.append("[color=%s]%s[/color]" % [_tone_color_hex(str(entry.get("tone", "neutral"))), text])
	return "\n".join(lines)


func _entry_texts(entries: Array[Dictionary]) -> PackedStringArray:
	var lines := PackedStringArray()
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		var text := str(entry.get("text", ""))
		if text != "":
			lines.append(text)
	return lines


func _tone_color_hex(tone: String) -> String:
	match tone:
		"positive":
			return POSITIVE_STAT_COLOR
		"negative":
			return NEGATIVE_STAT_COLOR
		_:
			return NEUTRAL_STAT_COLOR

func _update_bullet_time_overlay(current: float, max_value: float, active: bool) -> void:
	var percent := 0.0
	if max_value > 0.0:
		percent = current / max_value

	if bullet_time_meter != null:
		bullet_time_meter.max_value = max_value
		bullet_time_meter.value = current

	if bullet_time_seconds != null:
		bullet_time_seconds.text = str(snappedf(current, 0.1)) + " с"

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
