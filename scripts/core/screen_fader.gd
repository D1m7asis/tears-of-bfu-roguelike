extends CanvasLayer

@export var default_fade_duration: float = 0.45

@onready var overlay: ColorRect = $ColorRect

var _tween: Tween = null
var _glow_tween: Tween = null

func _ready() -> void:
	add_to_group("screen_fader")
	if not _ensure_overlay():
		return
	overlay.visible = false
	overlay.color.a = 0.0

func set_black_instant(alpha: float = 1.0) -> void:
	if not _ensure_overlay():
		return
	overlay.visible = true
	overlay.color.a = clamp(alpha, 0.0, 1.0)

func fade_to_black(duration: float = default_fade_duration) -> void:
	if not _ensure_overlay():
		return
	_start_fade(1.0, duration)
	if _tween != null:
		await _tween.finished

func fade_from_black(duration: float = default_fade_duration) -> void:
	if not _ensure_overlay():
		return
	overlay.visible = true
	_start_fade(0.0, duration)
	if _tween != null:
		await _tween.finished
	if is_instance_valid(overlay):
		overlay.visible = false

func play_arrival_glow(duration: float = 0.22, glow_color: Color = Color(0, 0, 0, 0.18)) -> void:
	if not _ensure_overlay():
		return
	if _glow_tween != null:
		_glow_tween.kill()

	overlay.visible = true
	overlay.color = glow_color
	_glow_tween = create_tween()
	_glow_tween.set_trans(Tween.TRANS_SINE)
	_glow_tween.set_ease(Tween.EASE_OUT)
	_glow_tween.tween_property(overlay, "color:a", 0.0, max(duration, 0.01))
	await _glow_tween.finished
	if is_instance_valid(overlay) and overlay.color.a <= 0.001:
		overlay.visible = false

func _start_fade(target_alpha: float, duration: float) -> void:
	if not _ensure_overlay():
		return
	if _tween != null:
		_tween.kill()

	overlay.visible = true
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(overlay, "color:a", clamp(target_alpha, 0.0, 1.0), max(duration, 0.01))

func _ensure_overlay() -> bool:
	if overlay == null:
		overlay = get_node_or_null("ColorRect")
	return overlay != null
