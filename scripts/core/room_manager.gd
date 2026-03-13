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

@export var room_templates: Array[PackedScene] = []
@export var room_count: int = 12
@export var branch_chance: float = 0.25

@onready var room_root: Node2D = get_parent().get_node("RoomRoot")
@onready var player: CharacterBody2D = get_parent().get_node("Player")

var map: Dictionary = {} # Vector2i -> Dictionary
var current_pos: Vector2i = Vector2i.ZERO
var current_room_instance: Node = null

func _ready() -> void:
	add_to_group("room_manager")
	generate_map()
	emit_signal("map_generated", map)
	print("rooms generated:", map.size())
	load_room(Vector2i.ZERO, Dir.S)

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
	if room_templates.size() > 0:
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

	load_room(next_pos, OPPOSITE[dir])

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
		player.global_position = (marker as Node2D).global_position
	else:
		player.global_position = Vector2.ZERO

	# блокируем двери на короткое время, чтобы не цепляло триггеры сразу
	if player.has_method("lock_doors"):
		player.lock_doors()
