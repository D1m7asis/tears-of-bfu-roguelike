extends Control

const HEART_TEXTURE = preload("res://assets/sprites/items/heart.svg")

@export var cell_size: int = 18
@export var gap: int = 5
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
	if rm.has_signal("room_state_changed"):
		rm.room_state_changed.connect(_on_room_state_changed)

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

func _on_room_state_changed(_pos: Vector2i) -> void:
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

	# иконки рисуем отдельным проходом поверх комнат и линий
	for vp in visible_rooms.keys():
		var pos3: Vector2i = vp as Vector2i
		var visited3: bool = bool(visible_rooms[pos3])
		var top_left3: Vector2 = _cell_top_left(pos3, origin, min_x, min_y, step)
		var rect3: Rect2 = Rect2(top_left3, Vector2(cell_size, cell_size))
		_draw_room_icon(pos3, map_data[pos3] as Dictionary, rect3, visited3)

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

func _draw_room_icon(_pos: Vector2i, room: Dictionary, rect: Rect2, is_visited: bool) -> void:
	var room_kind := str(room.get("room_kind", "normal"))
	if room_kind == "start":
		_draw_flag_icon(rect)
	elif room_kind == "boss":
		_draw_skull_icon(rect)

	if not is_visited:
		return

	var pickup_icons := _get_room_pickup_icons(room)
	for icon_index in range(pickup_icons.size()):
		var icon_id: String = pickup_icons[icon_index]
		var icon_rect := Rect2(
			rect.position + Vector2(rect.size.x - 8.0, 2.0 + icon_index * 7.0),
			Vector2(7.0, 7.0)
		)
		if icon_id == "key":
			_draw_key_icon(icon_rect)
		elif icon_id == "heart":
			_draw_heart_icon(icon_rect)
		elif icon_id == "chest":
			_draw_chest_icon(icon_rect)
		elif icon_id == "active_item":
			_draw_active_item_icon(icon_rect)
		elif icon_id == "passive_item":
			_draw_passive_item_icon(icon_rect)

func _get_room_pickup_icons(room: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var instance: Node = room.get("instance", null) as Node
	if instance == null or not instance.has_method("get_floor_pickup_markers"):
		return result
	return instance.get_floor_pickup_markers()

func _draw_flag_icon(rect: Rect2) -> void:
	var plate := rect.grow(-2.0)
	draw_rect(plate, Color(0.08, 0.1, 0.14, 0.92), true)
	draw_rect(plate, Color(0.96, 0.84, 0.24, 0.95), false, 1.4)
	var pole_x := rect.position.x + rect.size.x * 0.3
	draw_line(Vector2(pole_x, rect.position.y + 3.0), Vector2(pole_x, rect.end.y - 2.0), Color(0.18, 0.12, 0.06, 1.0), 2.0)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(pole_x, rect.position.y + 3.0),
			Vector2(rect.position.x + rect.size.x * 0.8, rect.position.y + rect.size.y * 0.34),
			Vector2(pole_x, rect.position.y + rect.size.y * 0.58),
		]),
		Color(1.0, 0.2, 0.2, 1.0)
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(pole_x + 1.0, rect.position.y + 4.0),
			Vector2(rect.position.x + rect.size.x * 0.72, rect.position.y + rect.size.y * 0.38),
			Vector2(pole_x + 1.0, rect.position.y + rect.size.y * 0.53),
		]),
		Color(1.0, 0.92, 0.82, 0.45)
	)

func _draw_skull_icon(rect: Rect2) -> void:
	draw_circle(rect.get_center(), rect.size.x * 0.42, Color(0.05, 0.05, 0.07, 0.88))
	var center := rect.get_center()
	draw_circle(center + Vector2(0, -1.0), rect.size.x * 0.28, Color(0.95, 0.94, 0.92, 1.0))
	draw_circle(center + Vector2(-2.0, -1.5), 0.8, Color(0.12, 0.08, 0.08, 1.0))
	draw_circle(center + Vector2(2.0, -1.5), 0.8, Color(0.12, 0.08, 0.08, 1.0))
	draw_rect(Rect2(center + Vector2(-2.0, 2.0), Vector2(4.0, 2.3)), Color(0.95, 0.94, 0.92, 1.0), true)
	draw_line(center + Vector2(-1.0, 2.0), center + Vector2(-1.0, 4.0), Color(0.12, 0.08, 0.08, 1.0), 0.8)
	draw_line(center + Vector2(1.0, 2.0), center + Vector2(1.0, 4.0), Color(0.12, 0.08, 0.08, 1.0), 0.8)

func _draw_key_icon(rect: Rect2) -> void:
	draw_circle(rect.get_center(), rect.size.x * 0.55, Color(0.07, 0.06, 0.03, 0.92))
	var center := rect.get_center()
	draw_circle(center + Vector2(-1.2, 0), rect.size.x * 0.28, Color(0.97, 0.83, 0.28, 1.0))
	draw_circle(center + Vector2(-1.2, 0), rect.size.x * 0.14, Color(0.18, 0.15, 0.08, 1.0))
	draw_line(center + Vector2(0.3, 0), center + Vector2(2.7, 0), Color(0.97, 0.83, 0.28, 1.0), 1.1)
	draw_line(center + Vector2(1.6, 0), center + Vector2(1.6, 1.7), Color(0.97, 0.83, 0.28, 1.0), 1.0)
	draw_line(center + Vector2(2.6, 0), center + Vector2(2.6, 1.1), Color(0.97, 0.83, 0.28, 1.0), 1.0)

func _draw_heart_icon(rect: Rect2) -> void:
	if HEART_TEXTURE != null:
		draw_circle(rect.get_center(), rect.size.x * 0.55, Color(0.09, 0.03, 0.04, 0.92))
		draw_texture_rect(HEART_TEXTURE, rect, false, Color(1, 1, 1, 0.95))

func _draw_chest_icon(rect: Rect2) -> void:
	draw_circle(rect.get_center(), rect.size.x * 0.58, Color(0.09, 0.06, 0.03, 0.94))
	var body_rect := Rect2(rect.position + Vector2(1.0, 2.0), rect.size - Vector2(2.0, 2.5))
	draw_rect(body_rect, Color(0.68, 0.45, 0.18, 1.0), true)
	draw_rect(Rect2(body_rect.position, Vector2(body_rect.size.x, body_rect.size.y * 0.35)), Color(0.88, 0.68, 0.32, 1.0), true)
	draw_line(Vector2(body_rect.position.x + body_rect.size.x * 0.5, body_rect.position.y), Vector2(body_rect.position.x + body_rect.size.x * 0.5, body_rect.end.y), Color(0.28, 0.16, 0.05, 1.0), 0.9)
	draw_circle(body_rect.get_center() + Vector2(0, 0.5), 0.65, Color(0.96, 0.84, 0.34, 1.0))

func _draw_passive_item_icon(rect: Rect2) -> void:
	draw_circle(rect.get_center(), rect.size.x * 0.58, Color(0.06, 0.06, 0.1, 0.94))
	var center := rect.get_center()
	var star := PackedVector2Array([
		center + Vector2(0, -2.8),
		center + Vector2(1.3, -1.0),
		center + Vector2(3.0, -0.6),
		center + Vector2(1.6, 0.8),
		center + Vector2(2.0, 2.8),
		center + Vector2(0, 1.8),
		center + Vector2(-2.0, 2.8),
		center + Vector2(-1.6, 0.8),
		center + Vector2(-3.0, -0.6),
		center + Vector2(-1.3, -1.0),
	])
	draw_colored_polygon(star, Color(0.78, 0.92, 1.0, 1.0))

func _draw_active_item_icon(rect: Rect2) -> void:
	draw_circle(rect.get_center(), rect.size.x * 0.58, Color(0.1, 0.06, 0.03, 0.95))
	var center := rect.get_center()
	var diamond := PackedVector2Array([
		center + Vector2(0.0, -3.1),
		center + Vector2(2.7, 0.0),
		center + Vector2(0.0, 3.1),
		center + Vector2(-2.7, 0.0),
	])
	draw_colored_polygon(diamond, Color(1.0, 0.72, 0.26, 1.0))
	draw_circle(center, 0.9, Color(1.0, 0.95, 0.75, 0.95))
