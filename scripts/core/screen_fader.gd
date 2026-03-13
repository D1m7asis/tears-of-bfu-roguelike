extends CanvasLayer

@export var default_fade_duration: float = 0.45

@onready var overlay: ColorRect = $ColorRect

var _tween: Tween = null

func _ready() -> void:
	add_to_group("screen_fader")
	overlay.visible = false
	overlay.color.a = 0.0

func fade_to_black(duration: float = default_fade_duration) -> void:
	_start_fade(1.0, duration)
	if _tween != null:
		await _tween.finished

func fade_from_black(duration: float = default_fade_duration) -> void:
	overlay.visible = true
	_start_fade(0.0, duration)
	if _tween != null:
		await _tween.finished
	if is_instance_valid(overlay):
		overlay.visible = false

func _start_fade(target_alpha: float, duration: float) -> void:
	if _tween != null:
		_tween.kill()

	overlay.visible = true
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(overlay, "color:a", clamp(target_alpha, 0.0, 1.0), max(duration, 0.01))
