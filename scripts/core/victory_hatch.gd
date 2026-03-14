extends Area2D

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null and room_manager.has_method("start_next_floor_transition"):
		room_manager.start_next_floor_transition()
	if body.has_method("win_at_hatch"):
		body.call_deferred("win_at_hatch", global_position)
	elif body.has_method("win"):
		body.call_deferred("win")
