extends Control

@export var cell_size: int = 14
@export var gap: int = 4
@export var show_unvisited_neighbors: bool = true

var rm: Node = null
var map_data: Dictionary = {} # Dictionary[Vector2i, Dictionary]
var current_pos: Vector2i = Vector2i.ZERO

func bind_room_manager(room_manager: Node) -> void:
	rm = room_manager

	if rm.has_signal("map_generated"):
		rm.map_generated.connect(_on_map_generated)
	if rm.has_signal("room_loaded"):
		rm.room_loaded.connect(_on_room_loaded)
	if rm.has_signal("connection_unlocked"):
		rm.connection_unlocked.connect(_on_connection_unlocked)

	_pull_state_from_rm()
	queue_redraw()

func _pull_state_from_rm() -> void:
	if rm == null:
		return

	# Важно: без := чтобы не словить Variant инференс
	if "map" in rm:
		map_data = rm.map as Dictionary
	if "current_pos" in rm:
		current_pos = rm.current_pos as Vector2i

func _on_map_generated(new_map: Dictionary) -> void:
	map_data = new_map
	_pull_state_from_rm()
	queue_redraw()

func _on_room_loaded(pos: Vector2i) -> void:
	current_pos = pos
	_pull_state_from_rm()
	queue_redraw()

func _on_connection_unlocked(_from_pos: Vector2i, _dir: int) -> void:
	_pull_state_from_rm()
	queue_redraw()

func _draw() -> void:
	if map_data.is_empty():
		return

	# "видимые" клетки: visited + (опционально) соседи visited комнат
	var visible_rooms: Dictionary = {} # Dictionary[Vector2i, bool]
	for p in map_data.keys():
		var room: Dictionary = map_data[p] as Dictionary
		if room.get("visited", false) == true:
			visible_rooms[p] = true

			if show_unvisited_neighbors:
				var doors_exist: Dictionary = room.get("doors_exist", {}) as Dictionary
				for d in doors_exist.keys():
					if doors_exist[d] == true:
						var np: Vector2i = (p as Vector2i) + _dir_vec(int(d))
						if map_data.has(np) and not visible_rooms.has(np):
							visible_rooms[np] = false

	if visible_rooms.is_empty():
		return

	var min_x: int = 999999
	var min_y: int = 999999
	var max_x: int = -999999
	var max_y: int = -999999

	for vp in visible_rooms.keys():
		var pp: Vector2i = vp as Vector2i
		min_x = min(min_x, pp.x)
		min_y = min(min_y, pp.y)
		max_x = max(max_x, pp.x)
		max_y = max(max_y, pp.y)

	var cols: int = max_x - min_x + 1
	var rows: int = max_y - min_y + 1

	var step: int = cell_size + gap
	var map_w: int = cols * step - gap
	var map_h: int = rows * step - gap

	var origin: Vector2 = Vector2(
		(size.x - float(map_w)) * 0.5,
		(size.y - float(map_h)) * 0.5
	)

	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35), true)

	# коридоры от visited комнат
	for p in map_data.keys():
		var pos: Vector2i = p as Vector2i
		var room2: Dictionary = map_data[pos] as Dictionary
		if room2.get("visited", false) != true:
			continue

		var doors_exist2: Dictionary = room2.get("doors_exist", {}) as Dictionary
		var doors_open2: Dictionary = room2.get("doors_open", {}) as Dictionary

		var a_center: Vector2 = _cell_center(pos, origin, min_x, min_y, step)

		for dk in doors_exist2.keys():
			var d: int = int(dk)
			if doors_exist2[d] != true:
				continue

			var np: Vector2i = pos + _dir_vec(d)
			if not map_data.has(np):
				continue
			if not visible_rooms.has(np):
				continue

			var b_center: Vector2 = _cell_center(np, origin, min_x, min_y, step)

			var open: bool = bool(doors_open2.get(d, false))
			var width: float = 3.0 if open else 2.0
			var col: Color = Color(1, 1, 1, 0.9) if open else Color(1, 1, 1, 0.35)

			draw_line(a_center, b_center, col, width)

	# комнаты
	for vp in visible_rooms.keys():
		var pos2: Vector2i = vp as Vector2i
		var is_visited: bool = bool(visible_rooms[pos2])
		var is_current: bool = (pos2 == current_pos)

		var top_left: Vector2 = _cell_top_left(pos2, origin, min_x, min_y, step)
		var r: Rect2 = Rect2(top_left, Vector2(cell_size, cell_size))

		if is_visited:
			draw_rect(r, Color(1, 1, 1, 0.85), true)
		else:
			draw_rect(r, Color(1, 1, 1, 0.35), false, 2.0)

		if is_current:
			draw_rect(r.grow(2), Color(1, 0.9, 0.2, 0.95), false, 2.0)

func _cell_top_left(p: Vector2i, origin: Vector2, min_x: int, min_y: int, step: int) -> Vector2:
	var x: int = (p.x - min_x) * step
	var y: int = (p.y - min_y) * step
	return origin + Vector2(float(x), float(y))

func _cell_center(p: Vector2i, origin: Vector2, min_x: int, min_y: int, step: int) -> Vector2:
	return _cell_top_left(p, origin, min_x, min_y, step) + Vector2(float(cell_size), float(cell_size)) * 0.5

func _dir_vec(d: int) -> Vector2i:
	match d:
		0: return Vector2i(0, -1)
		1: return Vector2i(1, 0)
		2: return Vector2i(0, 1)
		3: return Vector2i(-1, 0)
	return Vector2i.ZERO
