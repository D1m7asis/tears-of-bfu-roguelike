extends Area2D

const SfxLib = preload("res://scripts/core/sfx_library.gd")
const POSITIVE_STAT_COLOR := "#7CFF8D"
const NEGATIVE_STAT_COLOR := "#FF6B6B"
const NEUTRAL_STAT_COLOR := "#D8E2F4"

@export var item_data: ItemData
@export var amount: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var pedestal: Sprite2D = get_node_or_null("Pedestal")
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
var _pickup_enabled: bool = true
var _can_collect: bool = true
var _spawn_protection_time: float = 0.0
var _require_exit_before_collect: bool = false


func _ready() -> void:
	add_to_group("floor_pickup")
	if item_data != null and sprite != null and item_data.icon != null:
		sprite.texture = item_data.icon
	_apply_visual_profile()
	_notify_room_pickup_changed()


func _process(delta: float) -> void:
	if _spawn_protection_time > 0.0:
		_spawn_protection_time = maxf(0.0, _spawn_protection_time - delta)
		return
	if not _require_exit_before_collect:
		return
	if _is_player_overlapping():
		return
	_require_exit_before_collect = false
	_can_collect = true


func _on_body_entered(body: Node) -> void:
	if not _pickup_enabled or not _can_collect:
		return
	if body.has_method("add_item"):
		var ok: bool = body.add_item(item_data, amount)
		if ok:
			SfxLib.play_item_pickup(self, item_data)
			var room_owner := _find_room_owner()
			if room_owner != null and room_owner.has_method("on_floor_pickup_collected"):
				room_owner.on_floor_pickup_collected(self)
			_notify_room_pickup_changed()
			queue_free()


func _apply_visual_profile() -> void:
	if item_data == null or sprite == null:
		return

	z_index = 20
	if pedestal != null:
		pedestal.visible = false
		pedestal.modulate = Color(1, 1, 1, 1)
	if item_data.pickup_kind == "heal":
		sprite.scale = Vector2(0.28, 0.28)
		sprite.position = Vector2(0, -6)
		if collision_shape != null:
			collision_shape.scale = Vector2(1.8, 1.8)
		return
	if item_data.pickup_kind == "passive_item":
		sprite.scale = Vector2(0.28, 0.28)
		sprite.position = Vector2(0, -10)
		if pedestal != null:
			pedestal.visible = true
			pedestal.scale = Vector2(0.34, 0.34)
			pedestal.modulate = Color(1.0, 0.96, 0.88, 1.0)
		if collision_shape != null:
			collision_shape.scale = Vector2(1.8, 1.8)
		return
	if item_data.pickup_kind == "active_item":
		sprite.scale = Vector2(0.2, 0.2)
		sprite.position = Vector2(0, -12)
		var rarity_color: Color = item_data.get_rarity_color()
		sprite.modulate = rarity_color
		if pedestal != null:
			pedestal.visible = true
			pedestal.scale = Vector2(0.4, 0.4)
			pedestal.modulate = rarity_color.lightened(0.08)
		if collision_shape != null:
			collision_shape.scale = Vector2(2.1, 2.1)
		return
	if item_data.id == "key":
		sprite.scale = Vector2(0.04038163, 0.040381636)
		sprite.position = Vector2(0, -4)
		if collision_shape != null:
			collision_shape.scale = Vector2.ONE
		return

	sprite.scale = Vector2(0.065, 0.065)
	sprite.position = Vector2(0, -6)
	if collision_shape != null:
		collision_shape.scale = Vector2(1.3, 1.3)


func set_pickup_enabled(enabled: bool) -> void:
	_pickup_enabled = enabled
	visible = enabled
	set_deferred("monitoring", enabled)
	set_deferred("monitorable", enabled)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not enabled)
	_notify_room_pickup_changed()


func is_pickup_enabled() -> bool:
	return _pickup_enabled


func prepare_spawn_protection(delay: float = 0.12, require_exit_before_collect: bool = true) -> void:
	_can_collect = false
	_spawn_protection_time = maxf(delay, 0.0)
	_require_exit_before_collect = require_exit_before_collect


func get_minimap_icon_id() -> String:
	if not _pickup_enabled or item_data == null:
		return ""
	if item_data.id == "key":
		return "key"
	if item_data.id == "heart":
		return "heart"
	if item_data.pickup_kind == "active_item":
		return "active_item"
	if item_data.pickup_kind == "passive_item":
		return "passive_item"
	return ""


func get_interaction_hint() -> String:
	if not _pickup_enabled or item_data == null:
		return ""

	if item_data.pickup_kind == "heal":
		return "%s\nЛечение +%d HP" % [item_data.get_localized_name(), item_data.heal_amount]
	if item_data.pickup_kind == "active_item":
		var details := _format_hint_lines(item_data.get_localized_display_lines())
		var replace_hint := ""
		var player := get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("get_active_item_name"):
			var current_active_name := str(player.call("get_active_item_name"))
			if current_active_name != "":
				replace_hint = "\nЗаменит: %s" % current_active_name
		return item_data.get_localized_name() + replace_hint if details == "" else "%s\n%s%s" % [item_data.get_localized_name(), details, replace_hint]
	if item_data.pickup_kind == "passive_item":
		var details := _format_hint_entries(item_data.build_stat_entries())
		return item_data.get_localized_name() if details == "" else "%s\n%s" % [item_data.get_localized_name(), details]
	if item_data.id == "key":
		return "Ключ\nОткрывает сундуки"
	return item_data.get_localized_name()


func get_hint_anchor_world_position() -> Vector2:
	if sprite != null and sprite.texture != null:
		var texture_size := sprite.texture.get_size()
		if texture_size.x > 0 and texture_size.y > 0:
			var top_offset := sprite.position.y - texture_size.y * sprite.scale.y * 0.5
			return global_position + Vector2(0.0, top_offset)
	return global_position + Vector2(0.0, -18.0)


func export_floor_state() -> Dictionary:
	return {
		"item_path": "" if item_data == null else item_data.resource_path,
		"amount": amount,
		"global_position": global_position,
		"pickup_enabled": _pickup_enabled,
	}


func apply_floor_state(state: Dictionary) -> void:
	var item_path := str(state.get("item_path", ""))
	if item_path != "":
		item_data = load(item_path) as ItemData
	amount = int(state.get("amount", amount))
	global_position = state.get("global_position", global_position)
	if item_data != null and sprite != null and item_data.icon != null:
		sprite.texture = item_data.icon
	_apply_visual_profile()
	set_pickup_enabled(bool(state.get("pickup_enabled", true)))


func _notify_room_pickup_changed() -> void:
	var room_owner := _find_room_owner()
	if room_owner != null and room_owner.has_method("on_room_pickup_changed"):
		room_owner.on_room_pickup_changed()


func _find_room_owner() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("on_room_pickup_changed"):
			return node
		node = node.get_parent()
	return null


func _is_player_overlapping() -> bool:
	for body in get_overlapping_bodies():
		if body != null and body.is_in_group("player"):
			return true
	return false


func _build_passive_lines() -> PackedStringArray:
	if item_data == null:
		return PackedStringArray()
	return item_data.build_stat_lines()


func _format_hint_lines(lines: PackedStringArray) -> String:
	if lines.is_empty():
		return ""
	return "\n".join(lines)


func _format_hint_entries(entries: Array[Dictionary]) -> String:
	var lines := PackedStringArray()
	for entry_variant in entries:
		var entry: Dictionary = entry_variant
		var text := str(entry.get("text", ""))
		if text == "":
			continue
		lines.append("[color=%s]%s[/color]" % [_tone_color_hex(str(entry.get("tone", "neutral"))), text])
	return "\n".join(lines)


func _tone_color_hex(tone: String) -> String:
	match tone:
		"positive":
			return POSITIVE_STAT_COLOR
		"negative":
			return NEGATIVE_STAT_COLOR
		_:
			return NEUTRAL_STAT_COLOR
