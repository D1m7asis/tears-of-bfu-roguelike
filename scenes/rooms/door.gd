extends StaticBody2D

@export var required_item_id: String = "key"
@export var consume_item: bool = true

@onready var blocker: CollisionShape2D = $DoorBlocker
@onready var trigger: Area2D = $Trigger
@onready var sprite: Sprite2D = $Sprite2D

var is_open: bool = false

func _ready():
	# на старте дверь закрыта
	blocker.disabled = false

func _on_trigger_body_entered(body):
	if is_open:
		return
	if not body.has_method("has_item_id"):
		return

	if body.has_item_id(required_item_id, 1):
		if consume_item and body.has_method("remove_item_id"):
			body.remove_item_id(required_item_id, 1)
		open()

func open():
	is_open = true
	blocker.set_deferred("disabled", true)
	sprite.visible = false
	trigger.monitoring = false
	print("Door opened, blocker disabled:", blocker.disabled)
