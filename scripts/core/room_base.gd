extends Node2D

const KEY_ITEM_DATA = preload("res://assets/items/key.tres")
const CHEST_SCENE = preload("res://scenes/ui/Chest.tscn")
const LootTableLib = preload("res://scripts/core/loot_tables.gd")
const ITEM_PICKUP_SCENE = preload("res://scenes/ItemPickup.tscn")
const RunStateLib = preload("res://scripts/core/run_state.gd")
const ResourceRegistryLib = preload("res://scripts/core/resource_registry.gd")
const FLOOR_VARIANT_TEXTURE = preload("res://assets/sprites/environment/floor.png")

signal room_cleared(pos: Vector2i)

@export var spawn_enemy_layouts: bool = true
@export var enemy_variants_folder: String = "res://scenes/enemies/variants"
@export var enemy_presets_folder: String = "res://scenes/enemies/presets"
@export var boss_variants_folder: String = "res://scenes/enemies/bosses"
@export var decor_presets_folder: String = "res://scenes/decor/presets"
@export var start_decor_presets_folder: String = ""
@export var boss_decor_presets_folder: String = ""
@export var victory_hatch_scene: PackedScene
@export var boss_spawn_path: NodePath = ^"BossSpawn"
@export var hatch_spawn_path: NodePath = ^"HatchSpawn"
@export var enemy_mutation_chance: float = 0.10

@onready var door_n: Node = $Doors/Door_N
@onready var door_e: Node = $Doors/Door_E
@onready var door_s: Node = $Doors/Door_S
@onready var door_w: Node = $Doors/Door_W
@onready var floor_root: Node2D = $Floor
@onready var floor_tile_map: TileMap = $Floor/TileMap
@onready var enemies_root: Node = $Enemies
@onready var reward_key_pickup: Area2D = get_node_or_null("ItemPickup")

const FLOOR_ROOM_TINTS: Array[Color] = [
	Color(0.98, 0.98, 1.02, 1.0),
	Color(0.95, 0.99, 0.95, 1.0),
	Color(1.0, 0.96, 0.92, 1.0),
	Color(0.92, 0.96, 1.02, 1.0),
]
const FLOOR_PATCH_BOUNDS := Rect2(-460.0, -220.0, 920.0, 440.0)
const ENTRY_SPAWN_SAFE_RADIUS: float = 170.0
const CENTER_SPAWN_SAFE_RADIUS: float = 110.0

var _enemy_layout_generated: bool = false
var _decor_layout_generated: bool = false
var _floor_visuals_generated: bool = false
var _rng := RandomNumberGenerator.new()
var _boss_spawned: bool = false
var _boss_defeated: bool = false
var _boss_instance: Node = null
var _victory_hatch_instance: Node = null
var _reward_chest_instance: Node = null
var _reward_active_pickup: Node = null
var _decor_root: Node2D = null
var _room_pos: Vector2i = Vector2i.ZERO
var _room_kind: String = "normal"
var _boss_door_dirs: Dictionary = {}
var _room_cleared_state: bool = false
var _reward_type: String = "none"
var _reward_claimed: bool = false
var _reward_item_path: String = ""
var _reward_pickup_present: bool = false
var _living_enemy_count: int = 0
var _dead_enemy_ids: Dictionary = {}
var _enemy_mutations: Array[String] = ["titan", "swift", "brutal", "sniper", "rabid"]
var _enemy_preset_spawn_count_cache: Dictionary = {}
var _room_seed: int = 0
var _decor_scene_path: String = ""
var _boss_scene_path: String = ""
var _enemy_state_snapshot: Array[Dictionary] = []
var _floor_pickup_snapshots: Array[Dictionary] = []
var _reward_chest_opened: bool = false
var _victory_hatch_spawned: bool = false


func _ready() -> void:
	_rng.randomize()
	if reward_key_pickup != null and is_instance_valid(reward_key_pickup):
		reward_key_pickup.set("item_data", KEY_ITEM_DATA)
		reward_key_pickup.set("amount", 1)
		reward_key_pickup.position = _reward_spawn_position()
		if reward_key_pickup.has_method("set_pickup_enabled"):
			reward_key_pickup.call("set_pickup_enabled", false)


func apply_room_data(data: Dictionary) -> void:
	_room_pos = data.get("pos", Vector2i.ZERO)
	_room_kind = str(data.get("room_kind", "normal"))
	_boss_door_dirs = data.get("boss_door_dirs", {})
	_room_cleared_state = bool(data.get("cleared", _room_kind == "start"))
	if _room_kind == "boss" and _room_cleared_state:
		_boss_defeated = true
	_reward_type = str(data.get("reward_type", "none"))
	_reward_claimed = bool(data.get("reward_claimed", false))
	_reward_item_path = str(data.get("reward_item_path", ""))
	_reward_pickup_present = bool(data.get("reward_pickup_present", false))
	_room_seed = int(data.get("room_seed", _room_visual_seed()))
	if _room_seed == 0:
		_room_seed = _room_visual_seed()

	var door_exists: Dictionary = data.get("doors_exist", {})
	var door_open: Dictionary = data.get("doors_open", {})

	_apply_one(door_n, bool(door_exists.get(RoomManager.Dir.N, false)), bool(door_open.get(RoomManager.Dir.N, false)))
	_apply_one(door_e, bool(door_exists.get(RoomManager.Dir.E, false)), bool(door_open.get(RoomManager.Dir.E, false)))
	_apply_one(door_s, bool(door_exists.get(RoomManager.Dir.S, false)), bool(door_open.get(RoomManager.Dir.S, false)))
	_apply_one(door_w, bool(door_exists.get(RoomManager.Dir.W, false)), bool(door_open.get(RoomManager.Dir.W, false)))


func apply_room_state(state: Dictionary) -> void:
	_decor_scene_path = str(state.get("decor_scene_path", ""))
	_boss_scene_path = str(state.get("boss_scene_path", ""))
	_enemy_state_snapshot = _duplicate_dict_array(state.get("enemy_entries", []))
	_floor_pickup_snapshots = _duplicate_dict_array(state.get("floor_pickups", []))
	_reward_chest_opened = bool(state.get("reward_chest_opened", false))
	_victory_hatch_spawned = bool(state.get("victory_hatch_spawned", _room_kind == "boss" and _boss_defeated))
	_ensure_floor_visuals()
	_ensure_decor_layout()
	_ensure_enemy_layout()
	_ensure_boss_content()
	_restore_floor_pickups_from_snapshot()
	_bind_enemy_signals()
	_rebuild_enemy_tracking()
	_configure_reward_objects()
	set_enemies_active(false)
	_set_doors_combat_locked(_should_lock_doors())
	_sync_room_pickup_markers()
	_notify_room_state_changed()


func export_room_state() -> Dictionary:
	return {
		"decor_scene_path": _decor_scene_path,
		"boss_scene_path": _boss_scene_path,
		"enemy_entries": _capture_enemy_state(),
		"floor_pickups": _capture_floor_pickup_snapshots(),
		"reward_chest_opened": _reward_chest_opened,
		"victory_hatch_spawned": _victory_hatch_instance != null or _victory_hatch_spawned,
	}


func start_encounter() -> void:
	if _should_lock_doors():
		_set_doors_combat_locked(true)
		set_enemies_active(true)
		return

	_set_doors_combat_locked(false)
	set_enemies_active(false)
	if _living_enemy_count <= 0 and not _room_cleared_state and _room_kind != "start":
		_finish_room_clear()


func set_enemies_active(active: bool) -> void:
	if enemies_root == null:
		return

	for child in enemies_root.get_children():
		if child.has_method("set_active"):
			child.set_active(active)


func get_floor_pickup_markers() -> Array[String]:
	var pickups: Array[String] = []
	for pickup in _get_dynamic_item_pickups():
		if pickup != null and pickup.has_method("get_minimap_icon_id"):
			var icon_id := str(pickup.call("get_minimap_icon_id"))
			if icon_id != "":
				pickups.append(icon_id)
	return pickups


func on_room_pickup_changed() -> void:
	_sync_room_pickup_markers()
	_notify_room_state_changed()


func on_floor_pickup_collected(pickup: Node) -> void:
	if pickup == reward_key_pickup or pickup == _reward_active_pickup:
		_mark_reward_claimed()
	_sync_room_pickup_markers()
	_notify_room_state_changed()


func on_chest_opened(_chest: Node) -> void:
	_reward_chest_opened = true
	_sync_room_pickup_markers()
	_mark_reward_claimed()
	_notify_room_state_changed()


func on_room_unloaded() -> void:
	_sync_room_pickup_markers()
	if _reward_active_pickup != null and is_instance_valid(_reward_active_pickup):
		_reward_active_pickup.queue_free()
	_reward_active_pickup = null


func _apply_one(door: Node, exists: bool, opened: bool) -> void:
	if door == null:
		return
	if door.has_method("set_exists"):
		door.set_exists(exists)
	if door.has_method("set_special_style"):
		var door_dir := int(door.get("dir"))
		var style := "boss" if bool(_boss_door_dirs.get(door_dir, false)) else "normal"
		door.set_special_style(style)
	door.set("starts_open", opened)
	door.call("set_open", opened)


func _ensure_decor_layout() -> void:
	if _decor_layout_generated:
		return

	_decor_layout_generated = true
	_rng.seed = int(_room_seed) ^ 0x2D4F
	var preset_scene := _load_scene_from_path(_decor_scene_path)
	if preset_scene == null:
		preset_scene = _pick_random_scene(_decor_folder_for_room())
		if preset_scene != null:
			_decor_scene_path = preset_scene.resource_path
	if preset_scene == null:
		return

	_ensure_decor_root()
	var preset_instance := preset_scene.instantiate()
	if preset_instance == null:
		return

	_decor_root.add_child(preset_instance)


func _decor_folder_for_room() -> String:
	if _room_kind == "start" and start_decor_presets_folder != "":
		return start_decor_presets_folder
	if _room_kind == "boss":
		return ""
	return decor_presets_folder


func _ensure_decor_root() -> void:
	if _decor_root != null:
		return

	_decor_root = get_node_or_null("DecorRoot")
	if _decor_root == null:
		_decor_root = Node2D.new()
		_decor_root.name = "DecorRoot"
		add_child(_decor_root)
		move_child(_decor_root, 0)


func _ensure_enemy_layout() -> void:
	if _enemy_layout_generated or not spawn_enemy_layouts or enemies_root == null:
		return
	if _room_kind == "boss":
		return
	if _room_cleared_state:
		return

	_enemy_layout_generated = true
	_clear_existing_enemies()
	_rng.seed = int(_room_seed) ^ 0x51A7

	if not _enemy_state_snapshot.is_empty():
		_restore_enemies_from_snapshot()
		return

	var preset_scene := _pick_enemy_preset_scene()
	if preset_scene == null:
		return

	var preset_instance := preset_scene.instantiate()
	var spawn_points := _sanitize_spawn_points(_collect_spawn_points(preset_instance))
	preset_instance.queue_free()

	for spawn_point in spawn_points:
		var enemy_scene := _pick_random_scene(enemy_variants_folder)
		if enemy_scene == null:
			continue

		var enemy_instance := enemy_scene.instantiate()
		if enemy_instance is Node2D:
			(enemy_instance as Node2D).position = spawn_point
		_apply_floor_scaling(enemy_instance)
		_apply_random_enemy_mutation(enemy_instance)
		enemies_root.add_child(enemy_instance)


func _ensure_boss_content() -> void:
	if _boss_spawned or enemies_root == null or _room_kind != "boss":
		return
	if _room_cleared_state:
		_boss_defeated = true
		_spawn_victory_hatch()
		return

	var boss_spawn := get_node_or_null(boss_spawn_path)
	if boss_spawn == null or not (boss_spawn is Node2D):
		return

	if not _enemy_state_snapshot.is_empty():
		_restore_enemies_from_snapshot()
		_boss_spawned = true
		for child in enemies_root.get_children():
			if child != null and child.get("is_boss") == true:
				_boss_instance = child
				break
		return

	_rng.seed = int(_room_seed) ^ 0x7B19
	var boss_scene := _pick_random_scene(boss_variants_folder)
	if _boss_scene_path != "":
		var restored_boss_scene := _load_scene_from_path(_boss_scene_path)
		if restored_boss_scene != null:
			boss_scene = restored_boss_scene
	if boss_scene == null:
		return

	_boss_spawned = true
	_boss_scene_path = boss_scene.resource_path
	_boss_instance = boss_scene.instantiate()
	if _boss_instance is Node2D:
		(_boss_instance as Node2D).position = (boss_spawn as Node2D).position
	_apply_floor_scaling(_boss_instance)
	_apply_random_enemy_mutation(_boss_instance)
	enemies_root.add_child(_boss_instance)


func _clear_existing_enemies() -> void:
	for child in enemies_root.get_children():
		child.queue_free()


func _pick_random_scene(folder_path: String) -> PackedScene:
	var scene_pool: Array[PackedScene] = _get_scene_pool_for_folder(folder_path)
	if scene_pool.is_empty():
		return null
	return scene_pool[_rng.randi_range(0, scene_pool.size() - 1)]


func _pick_enemy_preset_scene() -> PackedScene:
	var scene_pool: Array[PackedScene] = _get_scene_pool_for_folder(enemy_presets_folder)
	if scene_pool.is_empty():
		return null

	var weighted_scenes: Array[PackedScene] = []
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for scene in scene_pool:
		var spawn_count := _get_enemy_preset_spawn_count(scene)
		var weight := _get_enemy_preset_weight(spawn_count)
		if weight <= 0.0:
			continue
		weighted_scenes.append(scene)
		weights.append(weight)
		total_weight += weight

	if weighted_scenes.is_empty() or total_weight <= 0.0:
		return scene_pool[_rng.randi_range(0, scene_pool.size() - 1)]

	var roll := _rng.randf() * total_weight
	for index in range(weighted_scenes.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return weighted_scenes[index]

	return weighted_scenes[weighted_scenes.size() - 1]


func _get_enemy_preset_spawn_count(scene: PackedScene) -> int:
	if scene == null:
		return 0
	var scene_key: String = scene.resource_path
	if _enemy_preset_spawn_count_cache.has(scene_key):
		return int(_enemy_preset_spawn_count_cache[scene_key])

	if scene == null:
		_enemy_preset_spawn_count_cache[scene_key] = 0
		return 0
	var instance := scene.instantiate()
	if instance == null:
		_enemy_preset_spawn_count_cache[scene_key] = 0
		return 0
	var spawn_count := _collect_spawn_points(instance).size()
	instance.queue_free()
	_enemy_preset_spawn_count_cache[scene_key] = spawn_count
	return spawn_count


func _get_scene_pool_for_folder(folder_path: String) -> Array[PackedScene]:
	match folder_path:
		enemy_variants_folder:
			return ResourceRegistryLib.get_enemy_variant_scenes()
		enemy_presets_folder:
			return ResourceRegistryLib.get_enemy_preset_scenes()
		boss_variants_folder:
			return ResourceRegistryLib.get_boss_scenes()
		decor_presets_folder:
			return ResourceRegistryLib.get_decor_preset_scenes()
		_:
			if folder_path == "" and _room_kind == "boss":
				return []
			var scene_paths := _list_scene_paths(folder_path)
			var scenes: Array[PackedScene] = []
			for scene_path in scene_paths:
				var scene := load(scene_path) as PackedScene
				if scene != null:
					scenes.append(scene)
			return scenes


func _get_enemy_preset_weight(spawn_count: int) -> float:
	if spawn_count <= 0:
		return 0.0
	var floor_level: int = max(1, RunStateLib.floor_index)
	var target_count: float = clampf(2.1 + float(floor_level - 1) * 0.75, 2.1, 6.0)
	var distance_weight: float = 1.0 / (1.0 + absf(float(spawn_count) - target_count))
	var weight: float = 0.18 + distance_weight * 2.2
	if floor_level == 1 and spawn_count > 3:
		weight *= 0.18
	elif floor_level == 2 and spawn_count > 4:
		weight *= 0.55
	if floor_level >= 3 and spawn_count <= 2:
		weight *= 0.55
	if floor_level >= 4 and spawn_count >= 5:
		weight *= 1.35
	return maxf(0.02, weight)


func _list_scene_paths(folder_path: String) -> Array[String]:
	var scene_paths: Array[String] = []
	if folder_path == "":
		return scene_paths

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


func _apply_floor_scaling(enemy_instance: Node) -> void:
	var floor_scale: int = max(0, RunStateLib.floor_index - 1)
	if floor_scale <= 0 or enemy_instance == null:
		return
	if "max_health" in enemy_instance:
		var base_health: int = int(enemy_instance.get("max_health"))
		var health_multiplier: float = 1.0 + floor_scale * 0.58 + floor_scale * floor_scale * 0.24
		var is_boss_enemy: bool = false
		if "is_boss" in enemy_instance:
			is_boss_enemy = bool(enemy_instance.get("is_boss"))
		if is_boss_enemy:
			health_multiplier += floor_scale * 0.45 + floor_scale * floor_scale * 0.22
		var scaled_health: int = max(base_health + floor_scale * 3, int(round(base_health * health_multiplier)))
		enemy_instance.set("max_health", scaled_health)
		if "health" in enemy_instance:
			enemy_instance.set("health", scaled_health)
	if "damage" in enemy_instance:
		var base_damage: int = int(enemy_instance.get("damage"))
		var scaled_damage: int = base_damage + max(1, int(round(floor_scale * 0.55 + floor_scale * floor_scale * 0.1)))
		enemy_instance.set("damage", scaled_damage)
	if "speed" in enemy_instance:
		var base_speed: float = float(enemy_instance.get("speed"))
		enemy_instance.set("speed", base_speed * (1.0 + floor_scale * 0.08))


func _ensure_floor_visuals() -> void:
	if _floor_visuals_generated:
		return
	_floor_visuals_generated = true
	if floor_tile_map == null:
		return

	var room_seed := _room_seed if _room_seed != 0 else _room_visual_seed()
	_rng.seed = room_seed
	floor_tile_map.modulate = FLOOR_ROOM_TINTS[_rng.randi_range(0, FLOOR_ROOM_TINTS.size() - 1)]
	_build_floor_patch_overlays()


func _room_visual_seed() -> int:
	var x_seed: int = int(_room_pos.x) * 73856093
	var y_seed: int = int(_room_pos.y) * 19349663
	var floor_seed: int = int(max(1, RunStateLib.floor_index)) * 83492791
	return abs(x_seed ^ y_seed ^ floor_seed ^ int(_room_kind.hash()))


func _build_floor_patch_overlays() -> void:
	if floor_root == null or FLOOR_VARIANT_TEXTURE == null:
		return

	var overlays := floor_root.get_node_or_null("FloorVariants")
	if overlays != null:
		overlays.queue_free()

	overlays = Node2D.new()
	overlays.name = "FloorVariants"
	overlays.z_index = -9
	floor_root.add_child(overlays)

	var patch_count: int = 4 + _rng.randi_range(0, 2)
	var texture_size := FLOOR_VARIANT_TEXTURE.get_size()
	for _i in range(patch_count):
		var patch := Sprite2D.new()
		patch.texture = FLOOR_VARIANT_TEXTURE
		patch.centered = true
		patch.region_enabled = true
		var region_width: float = 120.0 + _rng.randi_range(0, 56)
		var region_height: float = 88.0 + _rng.randi_range(0, 52)
		var region_position := Vector2(
			_rng.randf_range(0.0, maxf(0.0, texture_size.x - region_width)),
			_rng.randf_range(0.0, maxf(0.0, texture_size.y - region_height))
		)
		patch.region_rect = Rect2(region_position, Vector2(region_width, region_height))
		patch.position = Vector2(
			_rng.randf_range(FLOOR_PATCH_BOUNDS.position.x, FLOOR_PATCH_BOUNDS.end.x),
			_rng.randf_range(FLOOR_PATCH_BOUNDS.position.y, FLOOR_PATCH_BOUNDS.end.y)
		)
		patch.rotation = _rng.randf_range(-0.12, 0.12)
		patch.scale = Vector2.ONE * _rng.randf_range(0.75, 1.15)
		patch.modulate = Color(
			0.92 + _rng.randf_range(-0.06, 0.05),
			0.92 + _rng.randf_range(-0.05, 0.05),
			0.92 + _rng.randf_range(-0.08, 0.05),
			0.08 + _rng.randf_range(0.0, 0.06)
		)
		overlays.add_child(patch)

func _apply_random_enemy_mutation(enemy_instance: Node) -> void:
	if enemy_instance == null:
		return
	if _rng.randf() > _get_mutation_chance_for_floor():
		return
	if not enemy_instance.has_method("apply_mutation"):
		return
	if _enemy_mutations.is_empty():
		return
	var mutation_id: String = _enemy_mutations[_rng.randi_range(0, _enemy_mutations.size() - 1)]
	enemy_instance.call("apply_mutation", mutation_id)


func _get_mutation_chance_for_floor() -> float:
	var floor_level: int = max(1, RunStateLib.floor_index)
	var chance: float = 0.035 + float(floor_level - 1) * 0.042
	return clampf(maxf(chance, enemy_mutation_chance * 0.35), 0.035, 0.42)


func _sanitize_spawn_points(raw_points: Array[Vector2]) -> Array[Vector2]:
	var safe_points: Array[Vector2] = []
	for spawn_point in raw_points:
		if _is_spawn_point_safe(spawn_point):
			safe_points.append(spawn_point)

	if not safe_points.is_empty():
		return safe_points

	var fallback_points: Array[Vector2] = [
		Vector2(-280, -150),
		Vector2(280, -150),
		Vector2(-280, 150),
		Vector2(280, 150),
		Vector2(0, -180),
		Vector2(0, 180),
	]
	for fallback_point in fallback_points:
		if _is_spawn_point_safe(fallback_point):
			safe_points.append(fallback_point)
		if safe_points.size() >= max(1, raw_points.size()):
			break
	return safe_points


func _is_spawn_point_safe(spawn_point: Vector2) -> bool:
	for entry_point in _get_entry_spawn_points():
		if spawn_point.distance_to(entry_point) < ENTRY_SPAWN_SAFE_RADIUS:
			return false
	var center_spawn := get_node_or_null("Spawns/CenterSpawn")
	if center_spawn != null and center_spawn is Node2D:
		if spawn_point.distance_to((center_spawn as Node2D).position) < CENTER_SPAWN_SAFE_RADIUS:
			return false
	return true


func _get_entry_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for marker_name in ["Spawn_N", "Spawn_E", "Spawn_S", "Spawn_W"]:
		var marker := get_node_or_null("Spawns/%s" % marker_name)
		if marker != null and marker is Node2D:
			points.append((marker as Node2D).position)
	return points


func _bind_enemy_signals() -> void:
	if enemies_root == null:
		return

	var on_enemy_died := Callable(self, "_on_enemy_died")
	for child in enemies_root.get_children():
		if child.has_signal("died") and not child.is_connected("died", on_enemy_died):
			child.connect("died", on_enemy_died)


func _rebuild_enemy_tracking() -> void:
	_living_enemy_count = 0
	_dead_enemy_ids.clear()
	if enemies_root == null:
		return

	for child in enemies_root.get_children():
		if child.get("is_dead") == true:
			_dead_enemy_ids[child.get_instance_id()] = true
			continue
		_living_enemy_count += 1


func _on_enemy_died(enemy: CharacterBody2D) -> void:
	if enemy == _boss_instance:
		_boss_defeated = true
		_spawn_victory_hatch()
		_reward_type = "active_item"
		_reward_claimed = false
		_ensure_reward_active_pickup()

	var enemy_id := enemy.get_instance_id()
	if _dead_enemy_ids.has(enemy_id):
		return

	_dead_enemy_ids[enemy_id] = true
	_living_enemy_count = max(_living_enemy_count - 1, 0)
	if _living_enemy_count <= 0 and not _room_cleared_state:
		_finish_room_clear()


func _finish_room_clear() -> void:
	if _room_cleared_state:
		return

	_room_cleared_state = true
	_set_doors_combat_locked(false)
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("lock_doors"):
		player.lock_doors()
	set_enemies_active(false)
	emit_signal("room_cleared", _room_pos)
	_notify_room_state_changed()


func _configure_reward_objects() -> void:
	if reward_key_pickup != null and is_instance_valid(reward_key_pickup):
		reward_key_pickup.set("item_data", KEY_ITEM_DATA)
		reward_key_pickup.set("amount", 1)
		reward_key_pickup.position = _reward_spawn_position()
		if reward_key_pickup.has_method("set_pickup_enabled"):
			var should_show_key := _room_kind == "normal" and _room_cleared_state and _reward_type == "key" and not _reward_claimed and not reward_key_pickup.is_queued_for_deletion()
			reward_key_pickup.call("set_pickup_enabled", should_show_key)

	var should_show_chest := false
	if _room_kind == "normal" and _room_cleared_state and _reward_type == "chest" and (not _reward_claimed or _reward_chest_opened):
		should_show_chest = true

	if should_show_chest:
		_ensure_reward_chest()
	else:
		_remove_reward_chest()

	if _room_kind == "boss" and (_boss_defeated or _victory_hatch_spawned):
		_spawn_victory_hatch()

	if _room_kind == "boss" and _boss_defeated and not _reward_claimed:
		_ensure_reward_active_pickup()
	else:
		_remove_reward_active_pickup()


func _ensure_reward_chest() -> void:
	if CHEST_SCENE == null:
		return
	if _reward_chest_instance != null and is_instance_valid(_reward_chest_instance):
		if _reward_chest_instance is Node2D:
			(_reward_chest_instance as Node2D).position = to_local(find_free_drop_position(global_position + _reward_spawn_position(), 96.0))
		if _reward_chest_instance.has_method("set_opened"):
			_reward_chest_instance.set_opened(_reward_chest_opened)
		return

	_reward_chest_instance = CHEST_SCENE.instantiate()
	if _reward_chest_instance is Node2D:
		(_reward_chest_instance as Node2D).position = to_local(find_free_drop_position(global_position + _reward_spawn_position(), 96.0))
	if _reward_chest_instance.has_method("set_opened"):
		_reward_chest_instance.set_opened(_reward_chest_opened)
	call_deferred("_add_reward_chest_deferred")


func _remove_reward_chest() -> void:
	if _reward_chest_instance != null and is_instance_valid(_reward_chest_instance):
		_reward_chest_instance.queue_free()
	_reward_chest_instance = null


func _ensure_reward_active_pickup() -> void:
	if _reward_active_pickup != null and is_instance_valid(_reward_active_pickup):
		return
	if ITEM_PICKUP_SCENE == null:
		return
	var item: ItemData = null
	if _reward_item_path != "":
		item = load(_reward_item_path) as ItemData
	if item == null:
		item = LootTableLib.pick_random_active_item(_rng)
	if item == null:
		return
	_reward_item_path = item.resource_path
	_reward_pickup_present = true
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null and room_manager.has_method("set_room_reward_item"):
		room_manager.set_room_reward_item(_room_pos, _reward_item_path)
	_reward_active_pickup = ITEM_PICKUP_SCENE.instantiate()
	_reward_active_pickup.set("item_data", item)
	_reward_active_pickup.set("amount", 1)
	if _reward_active_pickup.has_method("prepare_spawn_protection"):
		_reward_active_pickup.call("prepare_spawn_protection", 0.08, true)
	var reward_world_pos := find_free_drop_position(global_position + _reward_spawn_position(), 120.0)
	if _reward_active_pickup is Node2D:
		(_reward_active_pickup as Node2D).position = to_local(reward_world_pos)
	call_deferred("_add_reward_active_pickup_deferred")


func _remove_reward_active_pickup() -> void:
	if _reward_active_pickup != null and is_instance_valid(_reward_active_pickup):
		_reward_active_pickup.queue_free()
	_reward_active_pickup = null
	_reward_pickup_present = false if _reward_claimed else _reward_pickup_present


func _reward_spawn_position() -> Vector2:
	if _room_kind == "boss":
		var boss_spawn := get_node_or_null(boss_spawn_path)
		if boss_spawn != null and boss_spawn is Node2D:
			return (boss_spawn as Node2D).position + Vector2(210, 20)
	var spawn := get_node_or_null("KeySpawn")
	if spawn != null and spawn is Node2D:
		return (spawn as Node2D).position
	return Vector2.ZERO


func find_free_drop_position(origin: Vector2, search_radius: float = 88.0) -> Vector2:
	var candidates: Array[Vector2] = [
		origin,
		origin + Vector2(0, -28),
		origin + Vector2(34, -20),
		origin + Vector2(-34, -20),
	]

	for ring in [36.0, 58.0, search_radius]:
		for angle_deg in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
			candidates.append(origin + Vector2.RIGHT.rotated(deg_to_rad(angle_deg)) * ring)

	for point in candidates:
		if _is_drop_point_free(point):
			return point

	return origin + Vector2(0, -24)


func _is_drop_point_free(world_point: Vector2) -> bool:
	var state := get_world_2d().direct_space_state
	var shape := CircleShape2D.new()
	shape.radius = 18.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, world_point)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = 0xFFFFFFFF
	var hits := state.intersect_shape(query, 8)
	return hits.is_empty()


func _should_lock_doors() -> bool:
	return not _room_cleared_state and _living_enemy_count > 0


func _set_doors_combat_locked(locked: bool) -> void:
	for door in [door_n, door_e, door_s, door_w]:
		if door != null and door.has_method("set_combat_locked"):
			door.set_combat_locked(locked)


func _spawn_victory_hatch() -> void:
	if victory_hatch_scene == null or _victory_hatch_instance != null:
		return

	var hatch_spawn := get_node_or_null(hatch_spawn_path)
	if hatch_spawn == null or not (hatch_spawn is Node2D):
		hatch_spawn = get_node_or_null(boss_spawn_path)
	if hatch_spawn == null or not (hatch_spawn is Node2D):
		return

	_victory_hatch_instance = victory_hatch_scene.instantiate()
	_victory_hatch_spawned = true
	if _victory_hatch_instance is Node2D:
		(_victory_hatch_instance as Node2D).position = (hatch_spawn as Node2D).position
	call_deferred("_add_victory_hatch_deferred")


func _mark_reward_claimed() -> void:
	_reward_claimed = true
	_reward_pickup_present = false
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null and room_manager.has_method("mark_room_reward_claimed"):
		room_manager.mark_room_reward_claimed(_room_pos)


func _notify_room_state_changed() -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null and room_manager.has_method("notify_room_state_changed"):
		room_manager.notify_room_state_changed(_room_pos)


func _sync_room_pickup_markers() -> void:
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null and room_manager.has_method("set_room_pickup_markers"):
		room_manager.set_room_pickup_markers(_room_pos, get_floor_pickup_markers())


func _capture_enemy_state() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if enemies_root == null:
		return result
	for child in enemies_root.get_children():
		if child == null or child.get("is_dead") == true:
			continue
		if not child.has_method("export_runtime_state"):
			continue
		result.append({
			"scene_path": child.scene_file_path,
			"state": child.export_runtime_state(),
		})
	return result


func _restore_enemies_from_snapshot() -> void:
	if enemies_root == null:
		return
	for entry_variant in _enemy_state_snapshot:
		var entry: Dictionary = entry_variant
		var scene := _load_scene_from_path(str(entry.get("scene_path", "")))
		if scene == null:
			continue
		var enemy_instance := scene.instantiate()
		if enemy_instance == null:
			continue
		if enemy_instance.has_method("apply_runtime_state"):
			enemy_instance.apply_runtime_state(entry.get("state", {}))
		enemies_root.add_child(enemy_instance)
		if enemy_instance.get("is_boss") == true:
			_boss_instance = enemy_instance


func _capture_floor_pickup_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	for pickup in _get_dynamic_item_pickups():
		if pickup.has_method("export_floor_state"):
			snapshots.append(pickup.export_floor_state())
	return snapshots


func _restore_floor_pickups_from_snapshot() -> void:
	_clear_dynamic_floor_pickups()
	for pickup_state_variant in _floor_pickup_snapshots:
		var pickup_state: Dictionary = pickup_state_variant
		var pickup := ITEM_PICKUP_SCENE.instantiate()
		if pickup == null:
			continue
		add_child(pickup)
		if pickup.has_method("apply_floor_state"):
			pickup.apply_floor_state(pickup_state)


func _clear_dynamic_floor_pickups() -> void:
	for pickup in _get_dynamic_item_pickups():
		pickup.queue_free()


func _get_dynamic_item_pickups() -> Array:
	var pickups: Array = []
	_collect_dynamic_item_pickups_recursive(self, pickups)
	return pickups


func _collect_dynamic_item_pickups_recursive(node: Node, pickups: Array) -> void:
	for child in node.get_children():
		if child == reward_key_pickup or child == _reward_active_pickup or child == _reward_chest_instance or child == _victory_hatch_instance:
			continue
		if child != null and child.is_in_group("floor_pickup") and child.has_method("export_floor_state"):
			pickups.append(child)
			continue
		_collect_dynamic_item_pickups_recursive(child, pickups)


func _load_scene_from_path(scene_path: String) -> PackedScene:
	if scene_path == "":
		return null
	return load(scene_path) as PackedScene


func _duplicate_dict_array(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_variant in source:
		var entry: Dictionary = entry_variant
		result.append(entry.duplicate(true))
	return result


func _collect_floor_pickups_recursive(node: Node, pickups: Array[String]) -> void:
	if node.is_in_group("floor_pickup") and node.has_method("get_minimap_icon_id"):
		var icon_id := str(node.call("get_minimap_icon_id"))
		if icon_id != "":
			pickups.append(icon_id)

	for child in node.get_children():
		_collect_floor_pickups_recursive(child, pickups)


func _add_reward_chest_deferred() -> void:
	if _reward_chest_instance != null and is_instance_valid(_reward_chest_instance) and _reward_chest_instance.get_parent() == null:
		add_child(_reward_chest_instance)

func _add_reward_active_pickup_deferred() -> void:
	if _reward_active_pickup != null and is_instance_valid(_reward_active_pickup) and _reward_active_pickup.get_parent() == null:
		add_child(_reward_active_pickup)


func _add_victory_hatch_deferred() -> void:
	if _victory_hatch_instance != null and is_instance_valid(_victory_hatch_instance) and _victory_hatch_instance.get_parent() == null:
		add_child(_victory_hatch_instance)
