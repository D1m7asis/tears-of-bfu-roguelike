extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	position += direction * speed * delta


@export var speed: float = 600.0
var direction: Vector2 = Vector2.ZERO


func _on_body_entered(body):
	queue_free()

func _on_area_entered(area):
	queue_free()
