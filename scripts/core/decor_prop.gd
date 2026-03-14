extends StaticBody2D

@export var blocks_movement: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not blocks_movement)
