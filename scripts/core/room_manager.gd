extends Node
class_name RoomManager

const RunStateLib = preload("res://scripts/core/run_state.gd")

signal map_generated(map_data: Dictionary)
signal room_loaded(pos: Vector2i)
signal connection_unlocked(from_pos: Vector2i, dir: int)
signal room_state_changed(pos: Vector2i)
signal floor_transition_started(next_floor: int)

enum Dir { N, E, S, W }

const DIR_VECTORS := {
	Dir.N: Vector2i(0, -1),
	Dir.E: Vector2i(1, 0),
	Dir.S: Vector2i(0, 1),
	Dir.W: Vector2i(-1, 0),
}

const OPPOSITE := {
	Dir.N: Dir.S,
	Dir.E: Dir.W,
	Dir.S: Dir.N,
	Dir.W: Dir.E,
}

const ENTRY_OFFSETS := {
	Dir.N: Vector2(0, 56),
	Dir.E: Vector2(-56, 0),
	Dir.S: Vector2(0, -56),
	Dir.W: Vector2(56, 0),
}

@export var room_templates: Array[PackedScene] = []
@export var start_room_template: PackedScene
@export var boss_room_template: PackedScene
@export var room_count: int = 12
@export var branch_chance: float = 0.25
@export var extra_connection_chance: float = 0.22
@export var room_transition_fade_duration: float = 0.2
@export var enemy_activation_delay: float = 0.25
@export var key_reward_chance: float = 0.15

@onready var room_root: Node2D = get_parent().get_node("RoomRoot")
@onready var player: CharacterBody2D = get_parent().get_node("Player")
@onready var screen_fader = get_parent().get_node_or_null("ScreenFader")

var map: Dictionary = {}
var current_pos: Vector2i = Vector2i.ZERO
var current_room_instance: Node = null
var is_room_transitioning: bool = false
var _generation_rng := RandomNumberGenerator.new()
var _reward_rng := RandomNumberGenerator.new()
var _cleared_normal_room_count: int = 0
var _planned_chest_slots: Array[int] = []
var _force_center_spawn_once: bool = false


func _ready() -> void:
	add_to_group("room_manager")
	_generation_rng.randomize()
	_reward_rng.randomize()
	room_count += max(0, RunStateLib.floor_index - 1)
	if RunStateLib.floor_index > 1 and screen_fader != null and screen_fader.has_method("set_black_instant"):
		screen_fader.set_black_instant(1.0)
	generate_map()
	_assign_boss_room()
	emit_signal("map_generated", map)
	_force_center_spawn_once = true
	load_room(Vector2i.ZERO, Dir.S)
	call_deferred("_activate_current_room_enemies_after_delay")
	call_deferred("_announce_floor_if_needed")


func generate_map() -> void:
	map.clear()
	_create_room(Vector2i.ZERO)

	var pos: Vector2i = Vector2i.ZERO
	var created: int = 1

	while created < room_count:
		var dir: int = _generation_rng.randi_range(0, 3)
		var next_pos: Vector2i = pos + DIR_VECTORS[dir]

		if not map.has(next_pos):
			_create_room(next_pos)
			_link_rooms(pos, next_pos, dir)
			created += 1
			pos = next_pos
		else:
			pos = next_pos

		if _generation_rng.randf() < branch_chance and created < room_count:
			var branch_dir: int = _generation_rng.randi_range(0, 3)
			var branch_pos: Vector2i = pos + DIR_VECTORS[branch_dir]
			if not map.has(branch_pos):
				_create_room(branch_pos)
				_link_rooms(pos, branch_pos, branch_dir)
				created += 1

	_add_extra_connections()


func _create_room(pos: Vector2i) -> void:
	var room_template: PackedScene = null
	if pos == Vector2i.ZERO and start_room_template != null:
		room_template = start_room_template
	elif room_templates.size() > 0:
		room_template = room_templates[_generation_rng.randi_range(0, room_templates.size() - 1)]

	map[pos] = {
		"pos": pos,
		"doors_exist": {Dir.N: false, Dir.E: false, Dir.S: false, Dir.W: false},
		"doors_open": {Dir.N: false, Dir.E: false, Dir.S: false, Dir.W: false},
		"template": room_template,
		"instance": null,
		"visited": false,
		"cleared": pos == Vector2i.ZERO,
		"room_kind": "start" if pos == Vector2i.ZERO else "normal",
		"boss_door_dirs": {},
		"boss_intro_seen": false,
		"reward_type": "none",
		"reward_claimed": pos == Vector2i.ZERO,
		"reward_item_path": "",
		"reward_pickup_present": false,
	}


func _link_rooms(a: Vector2i, b: Vector2i, dir_from_a_to_b: int) -> void:
	map[a]["doors_exist"][dir_from_a_to_b] = true
	map[b]["doors_exist"][OPPOSITE[dir_from_a_to_b]] = true
	map[a]["doors_open"][dir_from_a_to_b] = true
	map[b]["doors_open"][OPPOSITE[dir_from_a_to_b]] = true

func _add_extra_connections() -> void:
	for pos_variant in map.keys():
		var pos: Vector2i = pos_variant as Vector2i
		for dir in DIR_VECTORS.keys():
			var neighbor_pos: Vector2i = pos + DIR_VECTORS[dir]
			if not map.has(neighbor_pos):
				continue
			if bool(map[pos]["doors_exist"].get(dir, false)):
				continue
			if _generation_rng.randf() > extra_connection_chance:
				continue
			_link_rooms(pos, neighbor_pos, dir)


func load_room(pos: Vector2i, entered_from: int) -> void:
	if not map.has(pos):
		return

	var previous_pos: Vector2i = current_pos
	var previous_room_instance: Node = current_room_instance
	var room_data: Dictionary = map[pos]
	current_pos = pos
	room_data["visited"] = true
	map[pos] = room_data
	emit_signal("room_loaded", pos)

	if previous_room_instance != null:
		if previous_room_instance.has_method("on_room_unloaded"):
			previous_room_instance.on_room_unloaded()
		if previous_room_instance.get_parent() == room_root:
			room_root.remove_child(previous_room_instance)
		if previous_pos != pos:
			if map.has(previous_pos):
				map[previous_pos]["instance"] = null
			previous_room_instance.queue_free()
	current_room_instance = null

	var room_instance: Node = room_data.get("instance", null)
	if room_instance == null:
		var room_template: PackedScene = room_data["template"]
		if room_template == null:
			push_error("Room template is null. Assign room_templates.")
			return

		room_instance = room_template.instantiate()
		room_data["instance"] = room_instance
		map[pos] = room_data
		if room_instance.has_signal("room_cleared"):
			var on_room_cleared := Callable(self, "_on_room_cleared")
			if not room_instance.is_connected("room_cleared", on_room_cleared):
				room_instance.connect("room_cleared", on_room_cleared)

	current_room_instance = room_instance
	if current_room_instance.get_parent() != room_root:
		if current_room_instance.get_parent() != null:
			current_room_instance.get_parent().remove_child(current_room_instance)
		room_root.add_child(current_room_instance)

	if current_room_instance.has_method("apply_room_data"):
		current_room_instance.apply_room_data(map[pos])

	_spawn_player_at_entry(entered_from)


func try_move(dir: int) -> void:
	if is_room_transitioning or not map.has(current_pos):
		return
	if map[current_pos]["doors_exist"][dir] != true:
		return
	if map[current_pos]["doors_open"][dir] != true:
		return

	var next_pos: Vector2i = current_pos + DIR_VECTORS[dir]
	if not map.has(next_pos):
		return

	_start_room_transition(next_pos, OPPOSITE[dir], dir)


func request_move(dir: int) -> void:
	try_move(dir)


func unlock_connection(dir: int) -> void:
	var a: Vector2i = current_pos
	var b: Vector2i = current_pos + DIR_VECTORS[dir]
	if not map.has(b) or map[a]["doors_exist"][dir] != true:
		return

	map[a]["doors_open"][dir] = true
	map[b]["doors_open"][OPPOSITE[dir]] = true
	if current_room_instance != null and current_room_instance.has_method("apply_room_data"):
		current_room_instance.apply_room_data(map[a])
	emit_signal("connection_unlocked", current_pos, dir)


func mark_room_reward_claimed(pos: Vector2i) -> void:
	if not map.has(pos):
		return
	map[pos]["reward_claimed"] = true
	map[pos]["reward_pickup_present"] = false
	notify_room_state_changed(pos)


func set_room_reward_item(pos: Vector2i, item_path: String) -> void:
	if not map.has(pos):
		return
	if str(map[pos].get("reward_item_path", "")) == item_path and bool(map[pos].get("reward_pickup_present", false)) == (item_path != ""):
		return
	map[pos]["reward_item_path"] = item_path
	map[pos]["reward_pickup_present"] = item_path != ""
	notify_room_state_changed(pos)


func set_room_reward_pickup_present(pos: Vector2i, present: bool) -> void:
	if not map.has(pos):
		return
	if bool(map[pos].get("reward_pickup_present", false)) == present:
		return
	map[pos]["reward_pickup_present"] = present
	notify_room_state_changed(pos)


func _spawn_player_at_entry(entered_from: int) -> void:
	if _force_center_spawn_once:
		_force_center_spawn_once = false
		var center_marker := _find_center_spawn_marker()
		if center_marker != null:
			player.global_position = center_marker.global_position
			if player.has_method("lock_doors"):
				player.lock_doors()
			return

	var marker := _find_entry_spawn_marker(entered_from)
	if marker != null and marker is Node2D:
		var spawn_pos := (marker as Node2D).global_position
		spawn_pos += ENTRY_OFFSETS.get(entered_from, Vector2.ZERO)
		player.global_position = spawn_pos
	else:
		var fallback_marker := _find_center_spawn_marker()
		if fallback_marker != null:
			player.global_position = fallback_marker.global_position
		elif current_room_instance is Node2D:
			player.global_position = (current_room_instance as Node2D).global_position

	if player.has_method("lock_doors"):
		player.lock_doors()

func _find_entry_spawn_marker(entered_from: int) -> Node2D:
	if current_room_instance == null:
		return null
	var marker_name := ""
	match entered_from:
		Dir.N:
			marker_name = "Spawn_N"
		Dir.E:
			marker_name = "Spawn_E"
		Dir.S:
			marker_name = "Spawn_S"
		Dir.W:
			marker_name = "Spawn_W"
		_:
			marker_name = ""
	if marker_name == "":
		return null
	for marker_path in [marker_name, "Spawns/" + marker_name]:
		var marker := current_room_instance.get_node_or_null(marker_path)
		if marker != null and marker is Node2D:
			return marker as Node2D
	return null

func _find_center_spawn_marker() -> Node2D:
	if current_room_instance == null:
		return null
	var marker_paths := [^"CenterSpawn", ^"Spawns/CenterSpawn", ^"KeySpawn", ^"BossSpawn", ^"HatchSpawn"]
	for marker_path in marker_paths:
		var marker := current_room_instance.get_node_or_null(marker_path)
		if marker != null and marker is Node2D:
			return marker as Node2D
	if current_room_instance is Node2D:
		return current_room_instance as Node2D
	return null


func _start_room_transition(next_pos: Vector2i, entered_from: int, exit_dir: int) -> void:
	if is_room_transitioning:
		return
	is_room_transitioning = true
	call_deferred("_finish_room_transition", next_pos, entered_from, exit_dir)


func _finish_room_transition(next_pos: Vector2i, entered_from: int, exit_dir: int) -> void:
	if player != null and player.has_method("begin_room_transition"):
		player.begin_room_transition(exit_dir)

	if screen_fader != null and screen_fader.has_method("fade_to_black"):
		await screen_fader.fade_to_black(room_transition_fade_duration)

	_clear_active_bullets()
	load_room(next_pos, entered_from)

	if screen_fader != null and screen_fader.has_method("fade_from_black"):
		await screen_fader.fade_from_black(room_transition_fade_duration)
	if screen_fader != null and screen_fader.has_method("play_arrival_glow"):
		screen_fader.play_arrival_glow()
	if player != null and player.has_method("play_room_arrival_effect"):
		await player.play_room_arrival_effect(entered_from)
	if str(map[next_pos].get("room_kind", "normal")) == "boss":
		await _play_boss_room_intro_if_needed(next_pos)

	if player != null and player.has_method("end_room_transition"):
		player.end_room_transition()

	await _activate_current_room_enemies_after_delay()
	is_room_transitioning = false


func start_next_floor_transition() -> void:
	emit_signal("floor_transition_started", RunStateLib.floor_index)


func _play_boss_room_intro_if_needed(pos: Vector2i) -> void:
	if not map.has(pos):
		return
	if current_pos != pos:
		return
	if bool(map[pos].get("boss_intro_seen", false)):
		return
	map[pos]["boss_intro_seen"] = true
	if player != null and player.has_method("play_boss_room_intro"):
		await player.play_boss_room_intro()


func _announce_floor_if_needed() -> void:
	if RunStateLib.floor_index <= 1:
		return
	emit_signal("floor_transition_started", RunStateLib.floor_index)
	if player != null and player.has_method("play_floor_spawn_intro"):
		await player.play_floor_spawn_intro(RunStateLib.floor_index)


func _activate_current_room_enemies() -> void:
	if current_room_instance == null:
		return
	if current_room_instance.has_method("start_encounter"):
		current_room_instance.start_encounter()
	elif current_room_instance.has_method("set_enemies_active"):
		current_room_instance.set_enemies_active(true)


func _activate_current_room_enemies_after_delay() -> void:
	if enemy_activation_delay > 0.0:
		await get_tree().create_timer(enemy_activation_delay).timeout
	while player != null and player.has_method("can_use_doors") and not player.can_use_doors():
		await get_tree().create_timer(0.05).timeout
	_activate_current_room_enemies()


func _clear_active_bullets() -> void:
	for bullet in get_tree().get_nodes_in_group("bullet"):
		if bullet != null:
			bullet.queue_free()


func _assign_boss_room() -> void:
	if boss_room_template == null:
		return

	var farthest_pos := _find_farthest_room_from_start()
	if farthest_pos == Vector2i.ZERO or not map.has(farthest_pos):
		return

	map[farthest_pos]["template"] = boss_room_template
	map[farthest_pos]["room_kind"] = "boss"
	map[farthest_pos]["reward_type"] = "none"
	map[farthest_pos]["reward_item_path"] = ""
	map[farthest_pos]["reward_pickup_present"] = false

	for dir in DIR_VECTORS.keys():
		if map[farthest_pos]["doors_exist"][dir] != true:
			continue
		var neighbor_pos: Vector2i = farthest_pos + DIR_VECTORS[dir]
		if not map.has(neighbor_pos):
			continue
		map[farthest_pos]["doors_open"][dir] = true
		map[neighbor_pos]["doors_open"][OPPOSITE[dir]] = true
		map[farthest_pos]["boss_door_dirs"][dir] = true
		map[neighbor_pos]["boss_door_dirs"][OPPOSITE[dir]] = true
		break


func _find_farthest_room_from_start() -> Vector2i:
	var distances: Dictionary = {Vector2i.ZERO: 0}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var farthest_pos: Vector2i = Vector2i.ZERO
	var farthest_distance: int = 0

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var distance: int = distances[pos]

		if distance > farthest_distance:
			farthest_distance = distance
			farthest_pos = pos

		for dir in DIR_VECTORS.keys():
			if map[pos]["doors_exist"][dir] != true:
				continue

			var next_pos: Vector2i = pos + DIR_VECTORS[dir]
			if not map.has(next_pos) or distances.has(next_pos):
				continue

			distances[next_pos] = distance + 1
			queue.append(next_pos)

	return farthest_pos


func _on_room_cleared(pos: Vector2i) -> void:
	if not map.has(pos):
		return

	map[pos]["cleared"] = true
	_assign_room_reward(pos)
	if current_pos == pos and current_room_instance != null and current_room_instance.has_method("apply_room_data"):
		current_room_instance.apply_room_data(map[pos])
	notify_room_state_changed(pos)


func _assign_room_reward(pos: Vector2i) -> void:
	var room_kind := str(map[pos].get("room_kind", "normal"))
	if room_kind == "boss":
		map[pos]["reward_type"] = "active_item"
		map[pos]["reward_claimed"] = false
		map[pos]["reward_pickup_present"] = false
		return
	if room_kind != "normal":
		map[pos]["reward_type"] = "none"
		map[pos]["reward_claimed"] = true
		return

	if str(map[pos].get("reward_type", "none")) != "none" or bool(map[pos].get("reward_claimed", false)):
		return

	_cleared_normal_room_count += 1
	var batch_index := ((_cleared_normal_room_count - 1) % 10) + 1
	if batch_index == 1 or _planned_chest_slots.is_empty():
		_roll_chest_batch()

	if _planned_chest_slots.has(batch_index):
		map[pos]["reward_type"] = "chest"
		map[pos]["reward_claimed"] = false
		return

	if _reward_rng.randf() <= key_reward_chance:
		map[pos]["reward_type"] = "key"
		map[pos]["reward_claimed"] = false
		return

	map[pos]["reward_type"] = "none"
	map[pos]["reward_claimed"] = true


func _roll_chest_batch() -> void:
	_planned_chest_slots.clear()
	var chest_count := _reward_rng.randi_range(1, 2)
	while _planned_chest_slots.size() < chest_count:
		var slot := _reward_rng.randi_range(1, 10)
		if not _planned_chest_slots.has(slot):
			_planned_chest_slots.append(slot)


func notify_room_state_changed(pos: Vector2i) -> void:
	emit_signal("room_state_changed", pos)
