extends Area2D

@export var item_data: ItemData
@export var amount: int = 1

func _ready():
	# опционально: автоматически показывать иконку предмета
	if item_data != null and $Sprite2D != null and item_data.icon != null:
		$Sprite2D.texture = item_data.icon

func _on_body_entered(body):
	if body.has_method("add_item"):
		var ok: bool = body.add_item(item_data, amount)
		if ok:
			queue_free()
