extends Node2D

const KEY_ITEM_DATA = preload("res://assets/items/key.tres")
const CHEST_SCENE = preload("res://scenes/ui/Chest.tscn")
const LootTableLib = preload("res://scripts/core/loot_tables.gd")
const ITEM_PICKUP_SCENE = preload("res://scenes/ItemPickup.tscn")
const RunStateLib = preload("res://scripts/core/run_state.gd")

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
@onready var enemies_root: Node = $Enemies
@onready var reward_key_pickup: Area2D = get_node_or_null("ItemPickup")

var _enemy_layout_generated: bool = false
var _decor_layout_generated: bool = false
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
	_reward_type = str(data.get("reward_type", "none"))
	_reward_claimed = bool(data.get("reward_claimed", false))
	_reward_item_path = str(data.get("reward_item_path", ""))
	_reward_pickup_present = bool(data.get("reward_pickup_present", false))

	var door_exists: Dictionary = data.get("doors_exist", {})
	var door_open: Dictionary = data.get("doors_open", {})

	_apply_one(door_n, bool(door_exists.get(RoomManager.Dir.N, false)), bool(door_open.get(RoomManager.Dir.N, false)))
	_apply_one(door_e, bool(door_exists.get(RoomManager.Dir.E, false)), bool(door_open.get(RoomManager.Dir.E, false)))
	_apply_one(door_s, bool(door_exists.get(RoomManager.Dir.S, false)), bool(door_open.get(RoomManager.Dir.S, false)))
	_apply_one(door_w, bool(door_exists.get(RoomManager.Dir.W, false)), bool(door_open.get(RoomManager.Dir.W, false)))

	_ensure_decor_layout()
	_ensure_enemy_layout()
	_ensure_boss_content()
	_bind_enemy_signals()
	_rebuild_enemy_tracking()
	_configure_reward_objects()
	set_enemies_active(false)
	_set_doors_combat_locked(_should_lock_doors())
	_notify_room_state_changed()


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
	_collect_floor_pickups_recursive(self, pickups)
	return pickups


func on_room_pickup_changed() -> void:
	_notify_room_state_changed()


func on_floor_pickup_collected(pickup: Node) -> void:
	if pickup == reward_key_pickup or pickup == _reward_active_pickup:
		_mark_reward_claimed()
	_notify_room_state_changed()


func on_chest_opened(_chest: Node) -> void:
	_mark_reward_claimed()
	_notify_room_state_changed()


func on_room_unloaded() -> void:
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
	var preset_scene := _pick_random_scene(_decor_folder_for_room())
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

	_enemy_layout_generated = true
	_clear_existing_enemies()

	var preset_scene := _pick_enemy_preset_scene()
	if preset_scene == null:
		return

	var preset_instance := preset_scene.instantiate()
	var spawn_points := _collect_spawn_points(preset_instance)
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
	_apply_floor_scaling(_boss_instance)
	_apply_random_enemy_mutation(_boss_instance)
	enemies_root.add_child(_boss_instance)


func _clear_existing_enemies() -> void:
	for child in enemies_root.get_children():
		child.queue_free()


func _pick_random_scene(folder_path: String) -> PackedScene:
	var scene_paths := _list_scene_paths(folder_path)
	if scene_paths.is_empty():
		return null

	var scene_path: String = scene_paths[_rng.randi_range(0, scene_paths.size() - 1)]
	return load(scene_path) as PackedScene


func _pick_enemy_preset_scene() -> PackedScene:
	var scene_paths := _list_scene_paths(enemy_presets_folder)
	if scene_paths.is_empty():
		return null

	var weighted_paths: Array[String] = []
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for scene_path in scene_paths:
		var spawn_count := _get_enemy_preset_spawn_count(scene_path)
		var weight := _get_enemy_preset_weight(spawn_count)
		if weight <= 0.0:
			continue
		weighted_paths.append(scene_path)
		weights.append(weight)
		total_weight += weight

	if weighted_paths.is_empty() or total_weight <= 0.0:
		return load(scene_paths[_rng.randi_range(0, scene_paths.size() - 1)]) as PackedScene

	var roll := _rng.randf() * total_weight
	for index in range(weighted_paths.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return load(weighted_paths[index]) as PackedScene

	return load(weighted_paths[weighted_paths.size() - 1]) as PackedScene


func _get_enemy_preset_spawn_count(scene_path: String) -> int:
	if _enemy_preset_spawn_count_cache.has(scene_path):
		return int(_enemy_preset_spawn_count_cache[scene_path])

	var scene := load(scene_path) as PackedScene
	if scene == null:
		_enemy_preset_spawn_count_cache[scene_path] = 0
		return 0
	var instance := scene.instantiate()
	if instance == null:
		_enemy_preset_spawn_count_cache[scene_path] = 0
		return 0
	var spawn_count := _collect_spawn_points(instance).size()
	instance.queue_free()
	_enemy_preset_spawn_count_cache[scene_path] = spawn_count
	return spawn_count


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
	if _room_kind == "normal" and _room_cleared_state and _reward_type == "chest" and not _reward_claimed:
		should_show_chest = true

	if should_show_chest:
		_ensure_reward_chest()
	else:
		_remove_reward_chest()

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
		return

	_reward_chest_instance = CHEST_SCENE.instantiate()
	if _reward_chest_instance is Node2D:
		(_reward_chest_instance as Node2D).position = to_local(find_free_drop_position(global_position + _reward_spawn_position(), 96.0))
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
	_reward_pickup_present = false


func _reward_spawn_position() -> Vector2:
	if _room_kind == "boss":
		var hatch_spawn := get_node_or_null(hatch_spawn_path)
		if hatch_spawn != null and hatch_spawn is Node2D:
			return (hatch_spawn as Node2D).position + Vector2(210, -44)
		var boss_spawn := get_node_or_null(boss_spawn_path)
		if boss_spawn != null and boss_spawn is Node2D:
			return (boss_spawn as Node2D).position + Vector2(210, 12)
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
