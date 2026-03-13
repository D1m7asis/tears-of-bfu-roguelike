extends Node2D

@export var spawn_enemy_layouts: bool = true
@export var enemy_variants_folder: String = "res://scenes/enemies/variants"
@export var enemy_presets_folder: String = "res://scenes/enemies/presets"
@export var boss_variants_folder: String = "res://scenes/enemies/bosses"
@export var victory_hatch_scene: PackedScene
@export var boss_spawn_path: NodePath = ^"BossSpawn"
@export var hatch_spawn_path: NodePath = ^"HatchSpawn"

@onready var door_n = $Doors/Door_N
@onready var door_e = $Doors/Door_E
@onready var door_s = $Doors/Door_S
@onready var door_w = $Doors/Door_W
@onready var enemies_root: Node = $Enemies

var _enemy_layout_generated: bool = false
var _rng := RandomNumberGenerator.new()
var _boss_spawned: bool = false
var _boss_defeated: bool = false
var _boss_instance: Node = null
var _victory_hatch_instance: Node = null

func _ready() -> void:
	_rng.randomize()

func apply_room_data(data: Dictionary) -> void:
	var exist = data["doors_exist"]
	var open = data["doors_open"]

	_apply_one(door_n, exist[RoomManager.Dir.N], open[RoomManager.Dir.N])
	_apply_one(door_e, exist[RoomManager.Dir.E], open[RoomManager.Dir.E])
	_apply_one(door_s, exist[RoomManager.Dir.S], open[RoomManager.Dir.S])
	_apply_one(door_w, exist[RoomManager.Dir.W], open[RoomManager.Dir.W])
	_ensure_enemy_layout()
	_ensure_boss_content()
	set_enemies_active(false)

func _apply_one(door, exists: bool, opened: bool) -> void:
	if door.has_method("set_exists"):
		door.set_exists(exists)
	door.starts_open = opened
	door.set_open(opened)

func _ensure_enemy_layout() -> void:
	if _enemy_layout_generated or not spawn_enemy_layouts or enemies_root == null:
		return

	_enemy_layout_generated = true
	_clear_existing_enemies()

	var preset_scene := _pick_random_scene(enemy_presets_folder)
	if preset_scene == null:
		return

	var preset_instance := preset_scene.instantiate()
	var spawn_points := _collect_spawn_points(preset_instance)
	preset_instance.free()

	for spawn_point in spawn_points:
		var enemy_scene := _pick_random_scene(enemy_variants_folder)
		if enemy_scene == null:
			continue

		var enemy_instance := enemy_scene.instantiate()
		if enemy_instance is Node2D:
			(enemy_instance as Node2D).position = spawn_point
		enemies_root.add_child(enemy_instance)

func _clear_existing_enemies() -> void:
	for child in enemies_root.get_children():
		child.queue_free()

func _pick_random_scene(folder_path: String) -> PackedScene:
	var scene_paths := _list_scene_paths(folder_path)
	if scene_paths.is_empty():
		return null

	var scene_path: String = scene_paths[_rng.randi_range(0, scene_paths.size() - 1)]
	return load(scene_path) as PackedScene

func _list_scene_paths(folder_path: String) -> Array[String]:
	var scene_paths: Array[String] = []
	var dir := DirAccess.open(folder_path)
	if dir == null:
		return scene_paths

	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		if file_name.get_extension().to_lower() != "tscn":
			continue
		scene_paths.append(folder_path.path_join(file_name))
	dir.list_dir_end()
	return scene_paths

func _collect_spawn_points(root: Node) -> Array[Vector2]:
	var result: Array[Vector2] = []
	_collect_spawn_points_recursive(root, result)
	return result

func _collect_spawn_points_recursive(node: Node, result: Array[Vector2]) -> void:
	if node is Marker2D:
		result.append((node as Marker2D).position)

	for child in node.get_children():
		_collect_spawn_points_recursive(child, result)

func _ensure_boss_content() -> void:
	if _boss_spawned or enemies_root == null:
		return

	var boss_spawn := get_node_or_null(boss_spawn_path)
	if boss_spawn == null or not (boss_spawn is Node2D):
		return

	var boss_scene := _pick_random_scene(boss_variants_folder)
	if boss_scene == null:
		return

	_boss_spawned = true
	_boss_instance = boss_scene.instantiate()
	if _boss_instance is Node2D:
		(_boss_instance as Node2D).position = (boss_spawn as Node2D).position
	enemies_root.add_child(_boss_instance)

	if _boss_instance.has_signal("died"):
		_boss_instance.died.connect(_on_boss_died)

func set_enemies_active(active: bool) -> void:
	if enemies_root == null:
		return

	for child in enemies_root.get_children():
		if child.has_method("set_active"):
			child.set_active(active)

func _on_boss_died(_enemy: CharacterBody2D) -> void:
	if _boss_defeated:
		return

	_boss_defeated = true
	_spawn_victory_hatch()

func _spawn_victory_hatch() -> void:
	if victory_hatch_scene == null or _victory_hatch_instance != null:
		return

	var hatch_spawn := get_node_or_null(hatch_spawn_path)
	if hatch_spawn == null or not (hatch_spawn is Node2D):
		hatch_spawn = get_node_or_null(boss_spawn_path)
	if hatch_spawn == null or not (hatch_spawn is Node2D):
		return

	_victory_hatch_instance = victory_hatch_scene.instantiate()
	if _victory_hatch_instance is Node2D:
		(_victory_hatch_instance as Node2D).position = (hatch_spawn as Node2D).position
	add_child(_victory_hatch_instance)
