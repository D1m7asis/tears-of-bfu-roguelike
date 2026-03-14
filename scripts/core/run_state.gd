extends RefCounted
class_name RunState

static var floor_index: int = 1
static var continue_run: bool = false
static var player_state: Dictionary = {}


static func reset_run() -> void:
	floor_index = 1
	continue_run = false
	player_state = {}


static func advance_to_next_floor(state: Dictionary) -> void:
	floor_index += 1
	continue_run = true
	player_state = state.duplicate(true)


static func consume_player_state() -> Dictionary:
	continue_run = false
	return player_state.duplicate(true)
