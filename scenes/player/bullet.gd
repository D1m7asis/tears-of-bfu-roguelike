extends Area2D

@export var speed: float = 600.0
@export var damage: int = 1
var direction: Vector2 = Vector2.ZERO
var _player = null

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	var time_scale := 1.0
	if _player != null and _player.has_method("get_bullet_time_world_scale"):
		time_scale = _player.get_bullet_time_world_scale()
	position += direction * speed * delta * time_scale


func _on_body_entered(_body) -> void:
	queue_free()

func _on_area_entered(_area) -> void:
	queue_free()
