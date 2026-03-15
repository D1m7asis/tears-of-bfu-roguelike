extends Area2D

var _can_activate: bool = false
var _spawn_protection_time: float = 0.18
var _require_exit_before_activate: bool = true


func _ready() -> void:
	_can_activate = false
	set_process(true)


func _process(delta: float) -> void:
	if _spawn_protection_time > 0.0:
		_spawn_protection_time = maxf(0.0, _spawn_protection_time - delta)
		return
	if not _require_exit_before_activate:
		_can_activate = true
		return
	if _is_player_overlapping():
		return
	_require_exit_before_activate = false
	_can_activate = true


func _on_body_entered(body: Node) -> void:
	if not _can_activate:
		return
	if not body.is_in_group("player"):
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null and room_manager.has_method("start_next_floor_transition"):
		room_manager.start_next_floor_transition()
	if body.has_method("win_at_hatch"):
		body.call_deferred("win_at_hatch", global_position)
	elif body.has_method("win"):
		body.call_deferred("win")


func _is_player_overlapping() -> bool:
	for body in get_overlapping_bodies():
		if body != null and body.is_in_group("player"):
			return true
	return false
