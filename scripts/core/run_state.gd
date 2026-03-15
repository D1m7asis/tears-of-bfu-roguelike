extends RefCounted
class_name RunState

static var floor_index: int = 1
static var continue_run: bool = false
static var player_state: Dictionary = {}
static var death_summary: Dictionary = {}
static var floor_reached_max: int = 1


static func reset_run() -> void:
	floor_index = 1
	floor_reached_max = 1
	continue_run = false
	player_state = {}
	death_summary = {}


static func advance_to_next_floor(state: Dictionary) -> void:
	floor_index += 1
	floor_reached_max = max(floor_reached_max, floor_index)
	continue_run = true
	player_state = state.duplicate(true)


static func consume_player_state() -> Dictionary:
	continue_run = false
	return player_state.duplicate(true)


static func store_death_summary(summary: Dictionary) -> void:
	death_summary = summary.duplicate(true)


static func consume_death_summary() -> Dictionary:
	return death_summary.duplicate(true)
