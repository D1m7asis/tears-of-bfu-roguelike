extends Control

const HEART_TEXTURE = preload("res://assets/sprites/items/heart.svg")

const FULL_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const EMPTY_COLOR := Color(0.28, 0.22, 0.24, 0.95)

@export var heart_size: Vector2 = Vector2(24, 24)
@export var heart_gap: float = 6.0

var _current_health: int = 0
var _max_health: int = 0


func set_health(current_health: int, max_health: int) -> void:
	_current_health = max(0, current_health)
	_max_health = max(0, max_health)
	_update_minimum_size()
	queue_redraw()


func _draw() -> void:
	var heart_count := int(ceil(float(_max_health) / 2.0))
	if heart_count <= 0 or HEART_TEXTURE == null:
		return

	var texture_size := HEART_TEXTURE.get_size()
	if texture_size.x <= 0 or texture_size.y <= 0:
		return

	for heart_index in range(heart_count):
		var heart_rect := Rect2(Vector2(heart_index * (heart_size.x + heart_gap), 0.0), heart_size)
		var fill_units := clampi(_current_health - heart_index * 2, 0, 2)
		_draw_heart(heart_rect, texture_size, fill_units)


func _draw_heart(draw_rect: Rect2, texture_size: Vector2, fill_units: int) -> void:
	draw_texture_rect(HEART_TEXTURE, draw_rect, false, EMPTY_COLOR)

	if fill_units <= 0:
		return

	if fill_units >= 2:
		draw_texture_rect(HEART_TEXTURE, draw_rect, false, FULL_COLOR)
		return

	var left_half_rect := Rect2(draw_rect.position, Vector2(draw_rect.size.x * 0.5, draw_rect.size.y))
	var left_half_region := Rect2(Vector2.ZERO, Vector2(texture_size.x * 0.5, texture_size.y))
	draw_texture_rect_region(HEART_TEXTURE, left_half_rect, left_half_region, FULL_COLOR, false)


func _update_minimum_size() -> void:
	var heart_count := int(ceil(float(_max_health) / 2.0))
	if heart_count <= 0:
		custom_minimum_size = Vector2.ZERO
		return

	custom_minimum_size = Vector2(
		heart_count * heart_size.x + max(heart_count - 1, 0) * heart_gap,
		heart_size.y
	)
