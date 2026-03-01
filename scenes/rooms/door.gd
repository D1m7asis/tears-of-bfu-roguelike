extends StaticBody2D

enum DoorMode { LOCKED_KEY, ROOM_EXIT }
@export var mode: DoorMode = DoorMode.ROOM_EXIT

@export var dir: int = 0 # 0 N, 1 E, 2 S, 3 W (совместим с RoomManager.Dir)

@export var required_item_id: String = "key"
@export var consume_item: bool = true

@export var closed_texture: Texture2D
@export var open_texture: Texture2D

@onready var blocker: CollisionShape2D = $DoorBlocker
@onready var trigger: Area2D = $Trigger
@onready var sprite: Sprite2D = $Sprite2D

var is_open: bool = false

func _ready():
	is_open = false
	blocker.disabled = false
	trigger.monitoring = true
	if closed_texture != null:
		sprite.texture = closed_texture

func _on_trigger_body_entered(body):
	if is_open:
		return
	if not body.is_in_group("player"):
		return

	if mode == DoorMode.LOCKED_KEY:
		_try_open_with_key(body)
	else:
		_try_room_transition()

func _try_open_with_key(body):
	if not body.has_method("has_item_id"):
		return
	if body.has_item_id(required_item_id, 1):
		if consume_item and body.has_method("remove_item_id"):
			body.remove_item_id(required_item_id, 1)
		open()

func _try_room_transition():
	var rm = get_tree().get_first_node_in_group("room_manager")
	if rm == null:
		return
	rm.try_move(dir)

func open():
	is_open = true
	blocker.set_deferred("disabled", true)
	if open_texture != null:
		sprite.texture = open_texture
	trigger.monitoring = false
