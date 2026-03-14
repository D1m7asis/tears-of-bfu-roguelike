extends Node2D

@export var bar_size: Vector2 = Vector2(42, 6)
@export var y_offset: float = -78.0
@export var visible_duration: float = 2.0
@export var fade_duration: float = 0.22

var _current_health: int = 0
var _max_health: int = 1
var _visible_timer: float = 0.0
var _alpha: float = 0.0


func _ready() -> void:
	top_level = false
	visible = false


func _process(delta: float) -> void:
	position = Vector2(0.0, y_offset)

	if _visible_timer > 0.0:
		_visible_timer = maxf(0.0, _visible_timer - delta)
		_alpha = move_toward(_alpha, 1.0, delta / 0.08)
	else:
		_alpha = move_toward(_alpha, 0.0, delta / maxf(fade_duration, 0.01))

	visible = _alpha > 0.01
	if visible:
		queue_redraw()


func show_health(current_health: int, max_health: int) -> void:
	_current_health = max(0, current_health)
	_max_health = max(1, max_health)
	_visible_timer = visible_duration
	visible = true
	queue_redraw()


func hide_immediately() -> void:
	_visible_timer = 0.0
	_alpha = 0.0
	visible = false


func _draw() -> void:
	var bar_rect := Rect2(Vector2(-bar_size.x * 0.5, 0.0), bar_size)
	var fill_ratio := clampf(float(_current_health) / float(_max_health), 0.0, 1.0)

	draw_rect(bar_rect.grow(1.0), Color(0.03, 0.03, 0.04, 0.9 * _alpha), true)
	draw_rect(bar_rect, Color(0.16, 0.08, 0.08, 0.92 * _alpha), true)

	if fill_ratio > 0.0:
		var fill_rect := Rect2(bar_rect.position, Vector2(bar_rect.size.x * fill_ratio, bar_rect.size.y))
		draw_rect(fill_rect, Color(0.9, 0.22, 0.24, 0.98 * _alpha), true)
		draw_rect(Rect2(fill_rect.position, Vector2(fill_rect.size.x, fill_rect.size.y * 0.45)), Color(1.0, 0.56, 0.58, 0.88 * _alpha), true)
