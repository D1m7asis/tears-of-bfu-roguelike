extends Area2D

@export var speed: float = 600.0
var direction: Vector2 = Vector2.ZERO
var _player = null

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player != null and _player.has_method("is_time_stopped") and _player.is_time_stopped():
		return
	position += direction * speed * delta


func _on_body_entered(_body) -> void:
	queue_free()

func _on_area_entered(_area) -> void:
	queue_free()
