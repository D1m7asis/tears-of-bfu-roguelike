extends Node
class_name RoomManager

signal map_generated(map_data: Dictionary)
signal room_loaded(pos: Vector2i)
signal connection_unlocked(from_pos: Vector2i, dir: int)

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
@export var room_transition_fade_duration: float = 0.2
@export var enemy_activation_delay: float = 0.25

@onready var room_root: Node2D = get_parent().get_node("RoomRoot")
@onready var player: CharacterBody2D = get_parent().get_node("Player")
@onready var screen_fader = get_parent().get_node_or_null("ScreenFader")

var map: Dictionary = {} # Vector2i -> Dictionary
var current_pos: Vector2i = Vector2i.ZERO
var current_room_instance: Node = null
var is_room_transitioning: bool = false

func _ready() -> void:
	add_to_group("room_manager")
	generate_map()
	_assign_boss_room()
	emit_signal("map_generated", map)
	print("rooms generated:", map.size())
	load_room(Vector2i.ZERO, Dir.S)
	call_deferred("_activate_current_room_enemies_after_delay")

func generate_map() -> void:
	map.clear()
	_create_room(Vector2i.ZERO)

	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var pos: Vector2i = Vector2i.ZERO
	var created: int = 1

	while created < room_count:
		var dir: int = rng.randi_range(0, 3)
		var next_pos: Vector2i = pos + DIR_VECTORS[dir]

		if not map.has(next_pos):
			_create_room(next_pos)
			_link_rooms(pos, next_pos, dir)
			created += 1
			pos = next_pos
		else:
			pos = next_pos

		if rng.randf() < branch_chance and created < room_count:
			var bdir: int = rng.randi_range(0, 3)
			var bpos: Vector2i = pos + DIR_VECTORS[bdir]
			if not map.has(bpos):
				_create_room(bpos)
				_link_rooms(pos, bpos, bdir)
				created += 1

func _create_room(pos: Vector2i) -> void:
	var tpl: PackedScene = null
	if pos == Vector2i.ZERO and start_room_template != null:
		tpl = start_room_template
	elif room_templates.size() > 0:
		tpl = room_templates.pick_random()

	map[pos] = {
		"pos": pos,

		# проход существует?
		"doors_exist": { Dir.N: false, Dir.E: false, Dir.S: false, Dir.W: false },

		# проход открыт?
		"doors_open": { Dir.N: false, Dir.E: false, Dir.S: false, Dir.W: false },

		"template": tpl,
		"instance": null,
		"visited": false,
	}

func _link_rooms(a: Vector2i, b: Vector2i, dir_from_a_to_b: int) -> void:
	map[a]["doors_exist"][dir_from_a_to_b] = true
	map[b]["doors_exist"][OPPOSITE[dir_from_a_to_b]] = true

	# по умолчанию эти проходы закрыты, пока не откроют ключом
	map[a]["doors_open"][dir_from_a_to_b] = false
	map[b]["doors_open"][OPPOSITE[dir_from_a_to_b]] = false

func load_room(pos: Vector2i, entered_from: int) -> void:
	if not map.has(pos):
		return

	var room_data: Dictionary = map[pos]
	current_pos = pos
	room_data["visited"] = true
	emit_signal("room_loaded", pos)

	if current_room_instance != null:
		if current_room_instance.get_parent() == room_root:
			room_root.remove_child(current_room_instance)
		current_room_instance = null

	var room_instance: Node = room_data.get("instance", null)
	if room_instance == null:
		var tpl: PackedScene = room_data["template"]
		if tpl == null:
			push_error("Room template is null. Assign room_templates.")
			return

		room_instance = tpl.instantiate()
		room_data["instance"] = room_instance
		map[pos] = room_data

	current_room_instance = room_instance
	if current_room_instance.get_parent() != room_root:
		if current_room_instance.get_parent() != null:
			current_room_instance.get_parent().remove_child(current_room_instance)
		room_root.add_child(current_room_instance)

	if current_room_instance.has_method("apply_room_data"):
		current_room_instance.apply_room_data(room_data)

	_spawn_player_at_entry(entered_from)

func try_move(dir: int) -> void:
	if is_room_transitioning:
		return
	if not map.has(current_pos):
		return

	# должен существовать проход
	if map[current_pos]["doors_exist"][dir] != true:
		return

	# и он должен быть открыт
	if map[current_pos]["doors_open"][dir] != true:
		return

	var next_pos: Vector2i = current_pos + DIR_VECTORS[dir]
	if not map.has(next_pos):
		return

	_start_room_transition(next_pos, OPPOSITE[dir], dir)

func request_move(dir: int) -> void:
	try_move(dir)

# открывает связь "насквозь"
func unlock_connection(dir: int) -> void:
	var a: Vector2i = current_pos
	var b: Vector2i = current_pos + DIR_VECTORS[dir]
	if not map.has(b):
		return

	# если прохода нет, нечего открывать
	if map[a]["doors_exist"][dir] != true:
		return

	map[a]["doors_open"][dir] = true
	map[b]["doors_open"][OPPOSITE[dir]] = true

	# обновляем текущую комнату, чтобы дверь визуально открылась
	if current_room_instance != null and current_room_instance.has_method("apply_room_data"):
		current_room_instance.apply_room_data(map[a])

	emit_signal("connection_unlocked", current_pos, dir)

func _spawn_player_at_entry(entered_from: int) -> void:
	var marker_name: String = ""
	match entered_from:
		Dir.N: marker_name = "Spawn_N"
		Dir.E: marker_name = "Spawn_E"
		Dir.S: marker_name = "Spawn_S"
		Dir.W: marker_name = "Spawn_W"

	var marker := current_room_instance.get_node_or_null(marker_name)
	if marker == null:
		marker = current_room_instance.get_node_or_null("Spawns/" + marker_name)
	if marker != null and marker is Node2D:
		var spawn_pos := (marker as Node2D).global_position
		spawn_pos += ENTRY_OFFSETS.get(entered_from, Vector2.ZERO)
		player.global_position = spawn_pos
	else:
		player.global_position = Vector2.ZERO

	# блокируем двери на короткое время, чтобы не цепляло триггеры сразу
	if player.has_method("lock_doors"):
		player.lock_doors()

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

	if player != null and player.has_method("end_room_transition"):
		player.end_room_transition()

	await _activate_current_room_enemies_after_delay()

	is_room_transitioning = false

func _activate_current_room_enemies() -> void:
	if current_room_instance != null and current_room_instance.has_method("set_enemies_active"):
		current_room_instance.set_enemies_active(true)

func _activate_current_room_enemies_after_delay() -> void:
	if enemy_activation_delay > 0.0:
		await get_tree().create_timer(enemy_activation_delay).timeout
	_activate_current_room_enemies()

func _clear_active_bullets() -> void:
	for bullet in get_tree().get_nodes_in_group("bullet"):
		if bullet != null:
			bullet.queue_free()

func _assign_boss_room() -> void:
	if boss_room_template == null:
		return

	var farthest_pos := _find_farthest_room_from_start()
	if farthest_pos == Vector2i.ZERO:
		return
	if not map.has(farthest_pos):
		return

	map[farthest_pos]["template"] = boss_room_template

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
