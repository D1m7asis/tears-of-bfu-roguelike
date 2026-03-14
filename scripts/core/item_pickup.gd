extends Area2D

const SfxLib = preload("res://scripts/core/sfx_library.gd")

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
		pedestal.visible = true
	if item_data.pickup_kind == "heal":
		sprite.scale = Vector2(0.28, 0.28)
		sprite.position = Vector2(0, -6)
		if pedestal != null:
			pedestal.scale = Vector2(0.22, 0.22)
		if collision_shape != null:
			collision_shape.scale = Vector2(1.8, 1.8)
		return
	if item_data.pickup_kind == "passive_item":
		sprite.scale = Vector2(0.28, 0.28)
		sprite.position = Vector2(0, -10)
		if pedestal != null:
			pedestal.scale = Vector2(0.28, 0.28)
		if collision_shape != null:
			collision_shape.scale = Vector2(1.8, 1.8)
		return
	if item_data.pickup_kind == "active_item":
		sprite.scale = Vector2(0.2, 0.2)
		sprite.position = Vector2(0, -12)
		if pedestal != null:
			pedestal.scale = Vector2(0.34, 0.34)
		if collision_shape != null:
			collision_shape.scale = Vector2(2.1, 2.1)
		return
	if item_data.id == "key":
		sprite.scale = Vector2(0.04038163, 0.040381636)
		sprite.position = Vector2(0, -4)
		if pedestal != null:
			pedestal.scale = Vector2(0.18, 0.18)
		if collision_shape != null:
			collision_shape.scale = Vector2.ONE
		return

	sprite.scale = Vector2(0.065, 0.065)
	sprite.position = Vector2(0, -6)
	if pedestal != null:
		pedestal.scale = Vector2(0.22, 0.22)
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
		return "%s\nHeal +%d HP" % [item_data.display_name, item_data.heal_amount]
	if item_data.pickup_kind == "active_item":
		var details := "\n".join(item_data.display_lines)
		var replace_hint := ""
		var player := get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("get_active_item_name"):
			var current_active_name := str(player.call("get_active_item_name"))
			if current_active_name != "":
				replace_hint = "\nReplaces %s" % current_active_name
		return item_data.display_name + replace_hint if details == "" else "%s\n%s%s" % [item_data.display_name, details, replace_hint]
	if item_data.pickup_kind == "passive_item":
		var details := "\n".join(_build_passive_lines())
		return item_data.display_name if details == "" else "%s\n%s" % [item_data.display_name, details]
	if item_data.id == "key":
		return "Key\nOpens treasure chests"
	return item_data.display_name


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
	var lines := PackedStringArray()
	if item_data == null:
		return lines
	if item_data.damage_delta != 0:
		lines.append("DMG %s%d" % ["+" if item_data.damage_delta > 0 else "", item_data.damage_delta])
	if item_data.attack_speed_delta != 0.0:
		lines.append("ATS %s%.1f" % ["+" if item_data.attack_speed_delta > 0.0 else "", item_data.attack_speed_delta])
	if item_data.max_health_delta != 0:
		lines.append("MAX HP %s%d" % ["+" if item_data.max_health_delta > 0 else "", item_data.max_health_delta])
	if lines.is_empty():
		return item_data.display_lines
	return lines
