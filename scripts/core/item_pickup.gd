extends Area2D

@export var item_data: ItemData
@export var amount: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if item_data != null and sprite != null and item_data.icon != null:
		sprite.texture = item_data.icon
	_apply_visual_profile()


func _on_body_entered(body: Node) -> void:
	if body.has_method("add_item"):
		var ok: bool = body.add_item(item_data, amount)
		if ok:
			queue_free()


func _apply_visual_profile() -> void:
	if item_data == null or sprite == null:
		return

	z_index = 20
	if item_data.pickup_kind == "heal":
		sprite.scale = Vector2(0.2, 0.2)
		if collision_shape != null:
			collision_shape.scale = Vector2(1.8, 1.8)
		return

	sprite.scale = Vector2(0.04038163, 0.040381636)
	if collision_shape != null:
		collision_shape.scale = Vector2.ONE
