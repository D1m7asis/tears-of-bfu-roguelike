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

func _apply_visual_and_collision() -> void:
	var blocker_disabled := (not exists_in_room) or is_open
	blocker.set_deferred("disabled", blocker_disabled)
	trigger_shape.set_deferred("disabled", not exists_in_room)
	trigger.set_deferred("monitoring", exists_in_room)
	trigger.set_deferred("monitorable", exists_in_room)

	if not exists_in_room:
		return

	if is_open:
		if open_texture != null:
			sprite.texture = open_texture
	else:
		if closed_texture != null:
			sprite.texture = closed_texture

func _on_trigger_body_entered(body: Node) -> void:
	if not exists_in_room:
		return
	if not body.is_in_group("player"):
		return

	if body.has_method("can_use_doors") and not body.can_use_doors():
		return

	if not is_open:
		_try_open_with_key(body)
		return

	_try_room_transition(body)

func _try_open_with_key(body: Node) -> void:
	print("tried opening")
	if is_open:
		return
	if not body.has_method("has_item_id"):
		return

	if body.has_item_id(required_item_id, 1):
		if consume_item and body.has_method("remove_item_id"):
			body.remove_item_id(required_item_id, 1)

		set_open(true)

		var rm = get_tree().get_first_node_in_group("room_manager")
		if rm != null and rm.has_method("unlock_connection"):
			rm.unlock_connection(dir)
		if rm != null and rm.has_method("request_move"):
			rm.request_move(dir)

func _try_room_transition(_body: Node) -> void:
	var rm = get_tree().get_first_node_in_group("room_manager")
	if rm == null:
		return
	if rm.has_method("request_move"):
		rm.request_move(dir)
	else:
		rm.try_move(dir)
