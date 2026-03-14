extends StaticBody2D

enum DoorMode { LOCKED_KEY, ROOM_EXIT }
@export var mode: DoorMode = DoorMode.ROOM_EXIT

# 0 N, 1 E, 2 S, 3 W (RoomManager.Dir)
@export var dir: int = 0

# for locked door
@export var required_item_id: String = "key"
@export var consume_item: bool = true

# for room exit door
@export var starts_open: bool = true

@export var closed_texture: Texture2D
@export var open_texture: Texture2D

@onready var blocker: CollisionShape2D = $DoorBlocker
@onready var sprite: Sprite2D = $Sprite2D
@onready var trigger: Area2D = $Trigger
@onready var trigger_shape: CollisionShape2D = $Trigger/TriggerShape

var is_open: bool = false
var exists_in_room: bool = true
var is_combat_locked: bool = false
var special_style: String = "normal"

func _ready() -> void:
	is_open = starts_open
	_apply_visual_and_collision()

func set_exists(exists: bool) -> void:
	exists_in_room = exists
	visible = exists
	_apply_visual_and_collision()

func set_open(opened: bool) -> void:
	is_open = opened
	_apply_visual_and_collision()

func set_combat_locked(locked: bool) -> void:
	is_combat_locked = locked
	_apply_visual_and_collision()

func set_special_style(style: String) -> void:
	special_style = style
	_apply_visual_and_collision()

func _apply_visual_and_collision() -> void:
	var blocker_disabled := (not exists_in_room) or (is_open and not is_combat_locked)
	blocker.set_deferred("disabled", blocker_disabled)
	trigger_shape.set_deferred("disabled", (not exists_in_room) or is_combat_locked)
	trigger.set_deferred("monitoring", exists_in_room and not is_combat_locked)
	trigger.set_deferred("monitorable", exists_in_room and not is_combat_locked)

	if not exists_in_room:
		return

	if is_open and not is_combat_locked:
		if open_texture != null:
			sprite.texture = open_texture
	else:
		if closed_texture != null:
			sprite.texture = closed_texture

	var tint := Color(1, 1, 1, 1)
	if special_style == "boss":
		tint = Color(1.0, 0.42, 0.42, 1.0)
	if is_combat_locked:
		tint = tint.darkened(0.35)
	sprite.modulate = tint

func _on_trigger_body_entered(body: Node) -> void:
	if not exists_in_room or is_combat_locked:
		return
	if not body.is_in_group("player"):
		return

	if body.has_method("can_use_doors") and not body.can_use_doors():
		return

	if is_open:
		_try_room_transition(body)

func _try_room_transition(_body: Node) -> void:
	var rm = get_tree().get_first_node_in_group("room_manager")
	if rm == null:
		return
	if rm.has_method("request_move"):
		rm.request_move(dir)
	else:
		rm.try_move(dir)
