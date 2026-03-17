extends CharacterBody2D

const SfxLib = preload("res://scripts/core/sfx_library.gd")
const RunStateLib = preload("res://scripts/core/run_state.gd")
const PLAYER_BASE_TEXTURE = preload("res://assets/sprites/player/player.png")
const PLAYER_NEO_TEXTURE = preload("res://assets/sprites/player/player_neo.png")
const KEY_ITEM_DATA = preload("res://assets/items/key.tres")
const ITEM_PICKUP_SCENE = preload("res://scenes/ItemPickup.tscn")
const KEY_W_PHYSICAL: Key = 87
const KEY_A_PHYSICAL: Key = 65
const KEY_S_PHYSICAL: Key = 83
const KEY_D_PHYSICAL: Key = 68
const KEY_Q_PHYSICAL: Key = 81
const KEY_E_PHYSICAL: Key = 69
const KEY_R_PHYSICAL: Key = 82
const KEY_SHIFT_PHYSICAL: Key = 4194325
const KEY_ARROW_LEFT_PHYSICAL: Key = 4194319
const KEY_ARROW_UP_PHYSICAL: Key = 4194320
const KEY_ARROW_RIGHT_PHYSICAL: Key = 4194321
const KEY_ARROW_DOWN_PHYSICAL: Key = 4194322

@export var speed: float = 325.0
@export var base_damage: int = 1
@export var base_attack_speed: float = 3.33
@export var base_projectile_speed: float = 600.0

@onready var bullet_scene: PackedScene = preload("res://scenes/player/Bullet.tscn")
var can_shoot: bool = true
@export var bullet_spawn_offset: float = 55.0

@export var inventory_size: int = 12
@export var starting_keys: int = 3
var inventory: Array[Dictionary] = []

@export var restart_hold_seconds: float = 3.0
var restart_hold_time: float = 0.0
@onready var restart_overlay = null
@onready var screen_fader = null
@onready var camera: Camera2D = get_node_or_null("Camera2D")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")

@export var max_health: int = 5
var health: int = 0
@onready var hud = null
var _max_health_bonus: int = 0
var _damage_bonus: int = 0
var _attack_speed_bonus: float = 0.0
var _move_speed_bonus: float = 0.0
var _bullet_time_capacity_bonus: float = 0.0
var _bullet_time_kill_recharge_bonus: float = 0.0
var _heal_on_kill: int = 0
var _damage_reduction: int = 0
var _active_cooldown_multiplier: float = 1.0
var _bonus_bullet_count: int = 0
var _projectile_speed_bonus: float = 0.0
var collected_passive_items: Array[ItemData] = []

@export var game_over_scene_path: String = "res://scenes/ui/GameOver.tscn"
@export var victory_scene_path: String = "res://scenes/ui/Victory.tscn"
@export var death_fade_duration: float = 0.5
@export var death_hold_duration: float = 0.2
@export var bullet_time_max_seconds: float = 3.0
@export var bullet_time_kill_recharge_seconds: float = 0.3
@export var bullet_time_ramp_in_duration: float = 0.22
@export var bullet_time_ramp_out_duration: float = 0.12
@export var bullet_time_slowdown_power: float = 3.2

var door_lock_time: float = 0.0
@export var door_lock_after_teleport: float = 0.25
var is_dying: bool = false
var is_room_transitioning: bool = false
var room_transition_tween: Tween = null
var bullet_time_charge: float = 0.0
var is_bullet_time_active: bool = false
var bullet_time_blend: float = 0.0
var background_music = null
var _base_sprite_scale: Vector2 = Vector2.ONE
@export var pickup_hint_radius: float = 145.0
var active_item: ItemData = null
var active_item_cooldown_remaining: float = 0.0
var _active_overdrive_bonus_damage: int = 0
var _active_overdrive_bonus_ats: float = 0.0
var _is_active_invulnerable: bool = false
var _aegis_cast_id: int = 0
var _berserk_cast_id: int = 0
var _phase_cloak_cast_id: int = 0
var _blood_pact_cast_id: int = 0
var _iron_choir_cast_id: int = 0
var _speed_boost_cast_id: int = 0
var _temporary_speed_bonus: float = 0.0
var _damage_feedback_tween: Tween = null
var _physical_key_previous_state: Dictionary = {}
var _room_transition_watchdog: float = 0.0
var run_elapsed_seconds: float = 0.0
var run_score: int = 0
var run_kill_count: int = 0

func _ready() -> void:
	add_to_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS

	if sprite != null:
		_base_sprite_scale = sprite.scale
	health = max_health
	if RunStateLib.continue_run:
		_import_run_state(RunStateLib.consume_player_state())
	elif KEY_ITEM_DATA != null and starting_keys > 0:
		add_item(KEY_ITEM_DATA, starting_keys)
	bullet_time_charge = get_bullet_time_capacity()
	restart_overlay = get_tree().get_first_node_in_group("restart_overlay")
	hud = get_tree().get_first_node_in_group("hud")
	background_music = get_tree().get_first_node_in_group("background_music")
	_resolve_screen_fader()
	_update_hud_all()

func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		velocity = Vector2.ZERO
		return
	if is_dying:
		velocity = Vector2.ZERO
		return
	if is_room_transitioning:
		_room_transition_watchdog += _delta
		if _room_transition_watchdog >= 2.5:
			end_room_transition()
		velocity = Vector2.ZERO
		return
	_room_transition_watchdog = 0.0

	var direction := Vector2.ZERO

	if _is_action_or_key_pressed("move_right", KEY_D_PHYSICAL):
		rotation_degrees += 5
		direction.x += 1
	if _is_action_or_key_pressed("move_left", KEY_A_PHYSICAL):
		rotation_degrees -= 5
		direction.x -= 1
	if _is_action_or_key_pressed("move_down", KEY_S_PHYSICAL):
		rotation_degrees -= 2
		direction.y += 1
	if _is_action_or_key_pressed("move_up", KEY_W_PHYSICAL):
		rotation_degrees += 2
		direction.y -= 1

	direction = direction.normalized()
	velocity = direction * (speed + _move_speed_bonus + _temporary_speed_bonus)
	move_and_slide()

func _process(delta: float) -> void:
	if get_tree().paused:
		_set_bullet_time_active(false)
		return
	if _is_action_or_key_just_pressed("inventory", KEY_Q_PHYSICAL):
		_toggle_inventory()
	if is_dying:
		_set_bullet_time_active(false)
		return
	if is_room_transitioning:
		_room_transition_watchdog += delta
		if _room_transition_watchdog >= 2.5:
			end_room_transition()
		_set_bullet_time_active(false)
		return
	_room_transition_watchdog = 0.0
	run_elapsed_seconds += delta

	if door_lock_time > 0.0:
		door_lock_time -= delta
	if active_item_cooldown_remaining > 0.0:
		active_item_cooldown_remaining = maxf(0.0, active_item_cooldown_remaining - delta)

	if _is_action_or_key_pressed("bullet_time", KEY_SHIFT_PHYSICAL) and bullet_time_charge > 0.0:
		_set_bullet_time_active(true)
	else:
		_set_bullet_time_active(false)

	if is_bullet_time_active:
		bullet_time_charge = maxf(0.0, bullet_time_charge - delta)
		if bullet_time_charge <= 0.0:
			_set_bullet_time_active(false)

	_update_bullet_time_blend(delta)

	var shoot_direction := _get_held_shoot_direction()
	if shoot_direction != Vector2.ZERO:
		shoot(shoot_direction)
	if _is_action_or_key_just_pressed("active_item", KEY_E_PHYSICAL):
		use_active_item()

	if _is_action_or_key_pressed("restart_hold", KEY_R_PHYSICAL):
		restart_hold_time += delta
		if restart_overlay != null:
			restart_overlay.set_visible_active(true)
			restart_overlay.set_progress(restart_hold_time / restart_hold_seconds)

		if restart_hold_time >= restart_hold_seconds:
			RunStateLib.reset_run()
			get_tree().reload_current_scene()
	else:
		restart_hold_time = 0.0
		if restart_overlay != null:
			restart_overlay.set_visible_active(false)
			restart_overlay.set_progress(0.0)

	_update_hud_bullet_time()
	_update_hud_active_item()
	_update_pickup_hint()
	_update_hud_run_meta()

func shoot(dir: Vector2) -> void:
	if is_dying or is_room_transitioning or not can_shoot:
		return
	can_shoot = false
	_spawn_bullet(dir)
	SfxLib.play_shoot(self)

	await get_tree().create_timer(get_fire_cooldown_current()).timeout
	can_shoot = true

func _get_held_shoot_direction() -> Vector2:
	if _is_action_or_key_pressed("shoot_right", KEY_ARROW_RIGHT_PHYSICAL):
		return Vector2.RIGHT
	if _is_action_or_key_pressed("shoot_left", KEY_ARROW_LEFT_PHYSICAL):
		return Vector2.LEFT
	if _is_action_or_key_pressed("shoot_up", KEY_ARROW_UP_PHYSICAL):
		return Vector2.UP
	if _is_action_or_key_pressed("shoot_down", KEY_ARROW_DOWN_PHYSICAL):
		return Vector2.DOWN
	return Vector2.ZERO


func _is_action_or_key_pressed(action_name: String, physical_key: Key) -> bool:
	return Input.is_action_pressed(action_name) or Input.is_physical_key_pressed(physical_key)


func _is_action_or_key_just_pressed(action_name: String, physical_key: Key) -> bool:
	if Input.is_action_just_pressed(action_name):
		_physical_key_previous_state[physical_key] = true
		return true
	var is_pressed: bool = Input.is_physical_key_pressed(physical_key)
	var was_pressed: bool = bool(_physical_key_previous_state.get(physical_key, false))
	_physical_key_previous_state[physical_key] = is_pressed
	return is_pressed and not was_pressed

func add_item(item: ItemData, amount: int = 1) -> bool:
	if item == null or amount <= 0:
		return false
	if item.pickup_kind == "heal":
		return heal(item.heal_amount * amount)
	if item.pickup_kind == "active_item":
		set_active_item(item)
		return true
	if item.pickup_kind == "passive_item":
		var added_any := false
		for _i in range(amount):
			apply_passive_item(item)
			added_any = true
		return added_any

	if item.stackable:
		for slot in inventory:
			if slot["data"].id == item.id and int(slot["count"]) < item.max_stack:
				var space: int = item.max_stack - int(slot["count"])
				var add_now: int = min(space, amount)
				slot["count"] = int(slot["count"]) + add_now
				amount -= add_now
				if amount <= 0:
					_update_hud_all()
					return true

	while amount > 0:
		if inventory.size() >= inventory_size:
			_update_hud_all()
			return false

		var put: int = 1
		if item.stackable:
			put = min(item.max_stack, amount)

		inventory.append({ "data": item, "count": put })
		amount -= put

	_update_hud_all()
	return true

func has_item_id(item_id: String, amount: int = 1) -> bool:
	var total: int = 0
	for slot in inventory:
		if slot["data"].id == item_id:
			total += int(slot["count"])
			if total >= amount:
				return true
	return false

func remove_item_id(item_id: String, amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if not has_item_id(item_id, amount):
		return false

	var remaining: int = amount
	for i in range(inventory.size() - 1, -1, -1):
		var slot = inventory[i]
		if slot["data"].id != item_id:
			continue

		var take: int = min(int(slot["count"]), remaining)
		slot["count"] = int(slot["count"]) - take
		remaining -= take

		if int(slot["count"]) <= 0:
			inventory.remove_at(i)

		if remaining <= 0:
			_update_hud_all()
			return true

	_update_hud_all()
	return true

func count_item_id(item_id: String) -> int:
	var total: int = 0
	for slot in inventory:
		if slot["data"].id == item_id:
			total += int(slot["count"])
	return total

func take_damage(amount: int) -> void:
	if is_dying or _is_active_invulnerable:
		return

	var final_damage: int = max(1, amount - _damage_reduction)
	health -= final_damage
	if health < 0:
		health = 0

	SfxLib.play_player_hurt(self)
	_play_damage_feedback()
	_update_hud_health()

	if health <= 0:
		die()

func heal(amount: int) -> bool:
	if amount <= 0 or health >= max_health:
		return false

	health = min(max_health, health + amount)
	_update_hud_health()
	return true

func needs_healing() -> bool:
	return health < max_health

func get_health() -> int:
	return health

func get_max_health() -> int:
	return max_health

func get_damage_per_shot() -> int:
	return max(1, base_damage + _damage_bonus + _active_overdrive_bonus_damage)

func get_fire_cooldown_current() -> float:
	return 1.0 / get_attack_speed_current()

func get_attack_speed_current() -> float:
	return maxf(0.75, base_attack_speed + _attack_speed_bonus + _active_overdrive_bonus_ats)

func get_projectile_speed_current() -> float:
	return maxf(220.0, base_projectile_speed + _projectile_speed_bonus)

func get_bullet_time_capacity() -> float:
	return maxf(1.0, bullet_time_max_seconds + _bullet_time_capacity_bonus)

func get_current_stats() -> Dictionary:
	return {
		"damage": get_damage_per_shot(),
		"attack_speed": get_attack_speed_current(),
		"max_health": max_health,
		"move_speed": speed + _move_speed_bonus,
		"armor": _damage_reduction,
		"heal_on_kill": _heal_on_kill,
		"extra_shots": _bonus_bullet_count,
		"projectile_speed": get_projectile_speed_current(),
		"focus_max": get_bullet_time_capacity(),
		"focus_kill_gain": bullet_time_kill_recharge_seconds + _bullet_time_kill_recharge_bonus,
		"active_cooldown_multiplier": _active_cooldown_multiplier,
	}

func set_active_item(item: ItemData) -> void:
	if item == null:
		return
	if active_item != null and active_item != item:
		_drop_active_item_on_floor(active_item)
	active_item = item
	active_item_cooldown_remaining = 0.0
	_update_hud_all()
	if hud != null and hud.has_method("show_passive_item_card"):
		hud.show_passive_item_card(item)

func use_active_item() -> void:
	if active_item == null or active_item_cooldown_remaining > 0.0 or is_room_transitioning or is_dying:
		return

	match active_item.active_kind:
		"judgement":
			_active_judgement()
		"red_nova":
			_active_red_nova()
		"time_flask":
			_active_time_flask()
		"aegis_sigil":
			_active_aegis_sigil()
		"berserk_engine":
			_active_berserk_engine()
		"meteor_bell":
			_active_meteor_bell()
		"mirror_fan":
			_active_mirror_fan()
		"chrono_surge":
			_active_chrono_surge()
		"phase_cloak":
			_active_phase_cloak()
		"execution_order":
			_active_execution_order()
		"rail_hymn":
			_active_rail_hymn()
		"blood_pact":
			_active_blood_pact()
		"iron_choir":
			_active_iron_choir()
		"stasis_mine":
			_active_stasis_mine()
		"soul_lantern":
			_active_soul_lantern()
		_:
			return

	active_item_cooldown_remaining = maxf(active_item.active_cooldown_seconds * _active_cooldown_multiplier, 0.1)
	_update_hud_all()

func _active_judgement() -> void:
	_damage_all_enemies(999999)

func _active_red_nova() -> void:
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		_spawn_bullet(Vector2.RIGHT.rotated(angle))

func _active_time_flask() -> void:
	bullet_time_charge = get_bullet_time_capacity()
	_update_hud_bullet_time()

func _active_aegis_sigil() -> void:
	_aegis_cast_id += 1
	_is_active_invulnerable = true
	modulate = Color(0.72, 0.95, 1.0, 1.0)
	call_deferred("_end_aegis_after_delay", _aegis_cast_id)

func _end_aegis_after_delay(cast_id: int) -> void:
	await get_tree().create_timer(4.0).timeout
	if cast_id != _aegis_cast_id:
		return
	_is_active_invulnerable = false
	modulate = Color.WHITE

func _active_berserk_engine() -> void:
	_berserk_cast_id += 1
	_active_overdrive_bonus_damage += 2
	_active_overdrive_bonus_ats += 2.0
	_update_hud_all()
	call_deferred("_end_berserk_after_delay", _berserk_cast_id)

func _end_berserk_after_delay(cast_id: int) -> void:
	await get_tree().create_timer(8.0).timeout
	if cast_id != _berserk_cast_id:
		return
	_active_overdrive_bonus_damage = max(0, _active_overdrive_bonus_damage - 2)
	_active_overdrive_bonus_ats = maxf(0.0, _active_overdrive_bonus_ats - 2.0)
	_update_hud_all()

func _active_meteor_bell() -> void:
	_damage_all_enemies(8)

func _active_mirror_fan() -> void:
	_spawn_burst(24, 1.0, 1.0)

func _active_chrono_surge() -> void:
	bullet_time_charge = get_bullet_time_capacity()
	_set_bullet_time_active(true)
	_update_hud_bullet_time()

func _active_phase_cloak() -> void:
	_phase_cloak_cast_id += 1
	_apply_temporary_invulnerability(2.6, _phase_cloak_cast_id, "_end_phase_cloak")
	_apply_temporary_speed_boost(150.0, 2.6)
	modulate = Color(0.72, 0.88, 1.0, 1.0)

func _end_phase_cloak(cast_id: int) -> void:
	await get_tree().create_timer(2.6).timeout
	if cast_id != _phase_cloak_cast_id:
		return
	_is_active_invulnerable = false
	modulate = Color.WHITE

func _active_execution_order() -> void:
	for enemy in _get_current_room_enemies():
		var enemy_max_health: int = 1
		var enemy_health: int = 1
		if "max_health" in enemy:
			enemy_max_health = int(enemy.get("max_health"))
		if "health" in enemy:
			enemy_health = int(enemy.get("health"))
		if enemy_health <= int(ceil(float(enemy_max_health) * 0.5)):
			if enemy.has_method("take_damage"):
				enemy.take_damage(999999)
		elif enemy.has_method("take_damage"):
			enemy.take_damage(5)

func _active_rail_hymn() -> void:
	var dirs := [
		Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN,
		Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
		Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()
	]
	for dir in dirs:
		_spawn_custom_bullet(dir, get_damage_per_shot() * 3, 780.0)

func _active_blood_pact() -> void:
	if health > 1:
		health -= 1
		_update_hud_health()
	_blood_pact_cast_id += 1
	_apply_temporary_overdrive(5, 2.5, _blood_pact_cast_id, "_end_blood_pact")
	bullet_time_charge = minf(get_bullet_time_capacity(), bullet_time_charge + 1.4)
	_update_hud_bullet_time()

func _end_blood_pact(cast_id: int) -> void:
	await get_tree().create_timer(12.0).timeout
	if cast_id != _blood_pact_cast_id:
		return
	_active_overdrive_bonus_damage = max(0, _active_overdrive_bonus_damage - 5)
	_active_overdrive_bonus_ats = maxf(0.0, _active_overdrive_bonus_ats - 2.5)
	_update_hud_all()

func _active_iron_choir() -> void:
	heal(2)
	_iron_choir_cast_id += 1
	_apply_temporary_invulnerability(1.8, _iron_choir_cast_id, "_end_iron_choir")
	modulate = Color(1.0, 0.92, 0.72, 1.0)

func _end_iron_choir(cast_id: int) -> void:
	await get_tree().create_timer(1.8).timeout
	if cast_id != _iron_choir_cast_id:
		return
	_is_active_invulnerable = false
	modulate = Color.WHITE

func _active_stasis_mine() -> void:
	for enemy in _get_current_room_enemies():
		if enemy.has_method("apply_stasis"):
			enemy.apply_stasis(2.6)
		if enemy.has_method("take_damage"):
			enemy.take_damage(2)

func _active_soul_lantern() -> void:
	heal(1)
	bullet_time_charge = minf(get_bullet_time_capacity(), bullet_time_charge + 1.0)
	_update_hud_bullet_time()
	_spawn_burst(12, 1.0, 1.6)

func get_active_item_name() -> String:
	return "" if active_item == null else active_item.get_localized_name()

func _damage_all_enemies(amount: int) -> void:
	for enemy in _get_current_room_enemies():
		if enemy.has_method("take_damage"):
			enemy.take_damage(amount)

func _spawn_burst(count: int, damage_multiplier: float = 1.0, speed_multiplier: float = 1.0) -> void:
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		_spawn_custom_bullet(Vector2.RIGHT.rotated(angle), max(1, int(round(get_damage_per_shot() * damage_multiplier))), 600.0 * speed_multiplier)

func _apply_temporary_invulnerability(_duration: float, cast_id: int, callback_name: String) -> void:
	_is_active_invulnerable = true
	call_deferred(callback_name, cast_id)

func _apply_temporary_overdrive(damage_bonus: int, ats_bonus: float, cast_id: int, callback_name: String) -> void:
	_active_overdrive_bonus_damage += damage_bonus
	_active_overdrive_bonus_ats += ats_bonus
	_update_hud_all()
	call_deferred(callback_name, cast_id)

func _apply_temporary_speed_boost(speed_bonus: float, duration: float) -> void:
	_speed_boost_cast_id += 1
	_temporary_speed_bonus += speed_bonus
	call_deferred("_end_speed_boost", _speed_boost_cast_id, speed_bonus, duration)

func _end_speed_boost(cast_id: int, speed_bonus: float, duration: float) -> void:
	await get_tree().create_timer(duration).timeout
	if cast_id != _speed_boost_cast_id:
		return
	_temporary_speed_bonus = maxf(0.0, _temporary_speed_bonus - speed_bonus)

func _get_current_room_enemies() -> Array:
	var result: Array = []
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager == null:
		return result
	var room: Node = room_manager.get("current_room_instance") as Node
	if room == null:
		return result
	var enemies_root: Node = room.get_node_or_null("Enemies") as Node
	if enemies_root == null:
		return result
	for child in enemies_root.get_children():
		if child == null or child.get("is_dead") == true:
			continue
		result.append(child)
	return result

func apply_passive_item(item: ItemData) -> void:
	if item == null:
		return

	collected_passive_items.append(item)
	_damage_bonus += item.damage_delta
	_attack_speed_bonus += item.attack_speed_delta
	_move_speed_bonus += item.move_speed_delta
	_bullet_time_capacity_bonus += item.bullet_time_capacity_delta
	_bullet_time_kill_recharge_bonus += item.bullet_time_kill_recharge_delta
	_heal_on_kill += item.heal_on_kill
	_damage_reduction += item.damage_reduction
	_active_cooldown_multiplier *= item.active_cooldown_multiplier
	_bonus_bullet_count += item.bonus_bullet_count
	_projectile_speed_bonus += item.projectile_speed_delta

	var old_max_health := max_health
	_max_health_bonus += item.max_health_delta
	max_health = max(1, old_max_health + item.max_health_delta)
	if item.max_health_delta > 0:
		health = min(max_health, health + item.max_health_delta)
	else:
		health = min(health, max_health)
	bullet_time_charge = minf(get_bullet_time_capacity(), bullet_time_charge)

	_update_hud_all()
	if hud != null and hud.has_method("show_passive_item_card"):
		hud.show_passive_item_card(item)

func die() -> void:
	if is_dying:
		return

	is_dying = true
	RunStateLib.store_death_summary({
		"kills": run_kill_count,
		"score": run_score,
		"time_seconds": run_elapsed_seconds,
		"basement": max(RunStateLib.floor_index, RunStateLib.floor_reached_max),
	})
	_set_bullet_time_active(false)
	can_shoot = false
	velocity = Vector2.ZERO
	set_physics_process(false)

	if restart_overlay != null:
		restart_overlay.set_visible_active(false)
		restart_overlay.set_progress(0.0)

	_resolve_screen_fader()
	if screen_fader != null and screen_fader.has_method("fade_to_black"):
		await screen_fader.fade_to_black(death_fade_duration)

	if death_hold_duration > 0.0:
		await get_tree().create_timer(death_hold_duration).timeout

	if game_over_scene_path != "":
		get_tree().change_scene_to_file(game_over_scene_path)
	else:
		get_tree().reload_current_scene()

func win() -> void:
	var run_state := _export_run_state()
	RunStateLib.advance_to_next_floor(run_state)
	call_deferred("_go_to_next_floor")

func win_at_hatch(hatch_global_position: Vector2) -> void:
	is_room_transitioning = true
	can_shoot = false
	velocity = Vector2.ZERO
	_set_bullet_time_active(false)
	if hud != null and hud.has_method("play_cinematic_banner"):
		hud.play_cinematic_banner("СПУСК...", 0.42)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "global_position", hatch_global_position, 0.34)
	tween.parallel().tween_property(self, "scale", Vector2(0.12, 0.12), 0.34)
	if camera != null:
		tween.parallel().tween_property(camera, "zoom", Vector2(1.16, 1.16), 0.34)
	await tween.finished
	win()

func _update_hud_health() -> void:
	if hud != null and hud.has_method("update_health"):
		hud.update_health(health, max_health)

func _update_hud_keys() -> void:
	if hud != null and hud.has_method("update_keys"):
		hud.update_keys(count_item_id("key"))

func _update_hud_all() -> void:
	_update_hud_health()
	_update_hud_keys()
	_update_hud_bullet_time()
	_update_hud_stats()
	_update_hud_active_item()
	_update_hud_run_meta()
	_update_hud_inventory()

func _update_hud_stats() -> void:
	if hud != null and hud.has_method("update_player_stats"):
		hud.update_player_stats(get_current_stats())
	if hud != null and hud.has_method("update_collected_items"):
		hud.update_collected_items(collected_passive_items)

func _update_hud_active_item() -> void:
	if hud != null and hud.has_method("update_active_item"):
		hud.update_active_item(active_item, active_item_cooldown_remaining)


func _update_hud_run_meta() -> void:
	if hud != null and hud.has_method("update_run_meta"):
		hud.update_run_meta(run_elapsed_seconds, run_score, RunStateLib.floor_index)


func _update_hud_inventory() -> void:
	if hud == null or not hud.has_method("update_inventory_view"):
		return
	hud.update_inventory_view(active_item, inventory.duplicate(), collected_passive_items.duplicate(), get_current_stats())


func _toggle_inventory() -> void:
	if hud == null or not hud.has_method("set_inventory_open"):
		return
	var next_state: bool = true
	if hud.has_method("is_inventory_open"):
		next_state = not bool(hud.is_inventory_open())
	hud.set_inventory_open(next_state)
	_update_hud_inventory()


func _is_inventory_open() -> bool:
	if hud == null or not hud.has_method("is_inventory_open"):
		return false
	return bool(hud.is_inventory_open())

func _update_pickup_hint() -> void:
	if hud == null or not hud.has_method("set_pickup_hint"):
		return
	if get_tree() == null:
		return

	var nearest_hint := ""
	var nearest_distance_sq := pickup_hint_radius * pickup_hint_radius
	var nearest_hint_position := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("floor_pickup"):
		if not (node is Node2D):
			continue
		if not node.has_method("get_interaction_hint"):
			continue
		var hint := str(node.call("get_interaction_hint"))
		if hint == "":
			continue
		var distance_sq := global_position.distance_squared_to((node as Node2D).global_position)
		if distance_sq > nearest_distance_sq:
			continue
		nearest_distance_sq = distance_sq
		nearest_hint = hint
		if node.has_method("get_hint_anchor_world_position"):
			nearest_hint_position = node.call("get_hint_anchor_world_position")
		else:
			nearest_hint_position = (node as Node2D).global_position

	hud.set_pickup_hint(nearest_hint, nearest_hint_position)

func _go_to_next_floor() -> void:
	if hud != null and hud.has_method("play_cinematic_banner"):
		await hud.play_cinematic_banner("ПОДВАЛ %d" % [RunStateLib.floor_index], 1.6)
	_resolve_screen_fader()
	if screen_fader != null and screen_fader.has_method("fade_to_black"):
		await screen_fader.fade_to_black(0.55)
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func play_boss_room_intro() -> void:
	is_room_transitioning = true
	velocity = Vector2.ZERO
	_resolve_screen_fader()
	if screen_fader != null and screen_fader.has_method("set_black_instant"):
		screen_fader.set_black_instant(0.38)
	if hud != null and hud.has_method("play_cinematic_banner"):
		hud.play_cinematic_banner("БОСС ЖДЁТ", 1.15)
	if screen_fader != null and screen_fader.has_method("fade_from_black"):
		await screen_fader.fade_from_black(0.32)
	if camera != null:
		_stop_room_transition_tween()
		room_transition_tween = create_tween()
		room_transition_tween.set_trans(Tween.TRANS_SINE)
		room_transition_tween.set_ease(Tween.EASE_OUT)
		room_transition_tween.parallel().tween_property(camera, "zoom", Vector2(1.14, 1.14), 0.28)
		room_transition_tween.parallel().tween_property(camera, "offset", Vector2(0, -18), 0.28)
		await room_transition_tween.finished
		room_transition_tween = create_tween()
		room_transition_tween.set_trans(Tween.TRANS_SINE)
		room_transition_tween.set_ease(Tween.EASE_IN_OUT)
		room_transition_tween.parallel().tween_property(camera, "zoom", Vector2.ONE, 0.34)
		room_transition_tween.parallel().tween_property(camera, "offset", Vector2.ZERO, 0.34)
		await room_transition_tween.finished
	is_room_transitioning = false

func play_floor_spawn_intro(floor_number: int) -> void:
	is_room_transitioning = true
	velocity = Vector2.ZERO
	_resolve_screen_fader()
	if screen_fader != null and screen_fader.has_method("set_black_instant"):
		screen_fader.set_black_instant(1.0)
	if hud != null and hud.has_method("play_cinematic_banner"):
		await hud.play_cinematic_banner("ПОДВАЛ %d" % [floor_number], 2.9)
	if screen_fader != null and screen_fader.has_method("fade_from_black"):
		await screen_fader.fade_from_black(0.95)
	if camera != null:
		camera.zoom = Vector2(1.16, 1.16)
		var tween := create_tween()
		tween.set_trans(Tween.TRANS_SINE)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(camera, "zoom", Vector2.ONE, 0.75)
		await tween.finished
	is_room_transitioning = false

func _export_run_state() -> Dictionary:
	var passive_paths: Array[String] = []
	for item in collected_passive_items:
		if item != null and item.resource_path != "":
			passive_paths.append(item.resource_path)

	return {
		"health": health,
		"max_health": max_health,
		"damage_bonus": _damage_bonus,
		"attack_speed_bonus": _attack_speed_bonus,
		"move_speed_bonus": _move_speed_bonus,
		"bullet_time_capacity_bonus": _bullet_time_capacity_bonus,
		"bullet_time_kill_recharge_bonus": _bullet_time_kill_recharge_bonus,
		"heal_on_kill": _heal_on_kill,
		"damage_reduction": _damage_reduction,
		"active_cooldown_multiplier": _active_cooldown_multiplier,
		"bonus_bullet_count": _bonus_bullet_count,
		"projectile_speed_bonus": _projectile_speed_bonus,
		"passive_paths": passive_paths,
		"keys": count_item_id("key"),
		"bullet_time_charge": bullet_time_charge,
		"active_item_path": "" if active_item == null else active_item.resource_path,
		"active_item_cooldown_remaining": active_item_cooldown_remaining,
		"run_elapsed_seconds": run_elapsed_seconds,
		"run_score": run_score,
		"run_kill_count": run_kill_count,
	}

func _import_run_state(state: Dictionary) -> void:
	inventory.clear()
	collected_passive_items.clear()
	_damage_bonus = int(state.get("damage_bonus", 0))
	_attack_speed_bonus = float(state.get("attack_speed_bonus", 0.0))
	_move_speed_bonus = float(state.get("move_speed_bonus", 0.0))
	_bullet_time_capacity_bonus = float(state.get("bullet_time_capacity_bonus", 0.0))
	_bullet_time_kill_recharge_bonus = float(state.get("bullet_time_kill_recharge_bonus", 0.0))
	_heal_on_kill = int(state.get("heal_on_kill", 0))
	_damage_reduction = int(state.get("damage_reduction", 0))
	_active_cooldown_multiplier = float(state.get("active_cooldown_multiplier", 1.0))
	_bonus_bullet_count = int(state.get("bonus_bullet_count", 0))
	_projectile_speed_bonus = float(state.get("projectile_speed_bonus", 0.0))
	max_health = int(state.get("max_health", max_health))
	health = min(int(state.get("health", max_health)), max_health)
	bullet_time_charge = minf(float(state.get("bullet_time_charge", get_bullet_time_capacity())), get_bullet_time_capacity())
	active_item_cooldown_remaining = float(state.get("active_item_cooldown_remaining", 0.0))
	run_elapsed_seconds = float(state.get("run_elapsed_seconds", 0.0))
	run_score = int(state.get("run_score", 0))
	run_kill_count = int(state.get("run_kill_count", 0))

	var passive_paths: Array = state.get("passive_paths", [])
	for path_variant in passive_paths:
		var path := str(path_variant)
		if path == "":
			continue
		var item := load(path) as ItemData
		if item != null:
			collected_passive_items.append(item)

	var active_item_path := str(state.get("active_item_path", ""))
	if active_item_path != "":
		active_item = load(active_item_path) as ItemData

	var keys := int(state.get("keys", starting_keys))
	if KEY_ITEM_DATA != null and keys > 0:
		add_item(KEY_ITEM_DATA, keys)

func lock_doors() -> void:
	door_lock_time = door_lock_after_teleport

func can_use_doors() -> bool:
	return door_lock_time <= 0.0 and not is_room_transitioning

func begin_room_transition(exit_dir: int) -> void:
	is_room_transitioning = true
	_room_transition_watchdog = 0.0
	_set_bullet_time_active(false)
	velocity = Vector2.ZERO

	if camera == null:
		return

	var direction := _transition_direction(exit_dir)
	_stop_room_transition_tween()

	room_transition_tween = create_tween()
	room_transition_tween.set_trans(Tween.TRANS_SINE)
	room_transition_tween.set_ease(Tween.EASE_IN)
	room_transition_tween.parallel().tween_property(camera, "offset", direction * 10.0, 0.16)
	room_transition_tween.parallel().tween_property(camera, "zoom", Vector2(1.025, 1.025), 0.16)

func end_room_transition() -> void:
	is_room_transitioning = false
	_room_transition_watchdog = 0.0
	velocity = Vector2.ZERO

func play_room_arrival_effect(_entered_from: int) -> void:
	if camera == null:
		return

	_stop_room_transition_tween()

	room_transition_tween = create_tween()
	room_transition_tween.set_trans(Tween.TRANS_SINE)
	room_transition_tween.set_ease(Tween.EASE_OUT)
	room_transition_tween.parallel().tween_property(camera, "offset", Vector2.ZERO, 0.26)
	room_transition_tween.parallel().tween_property(camera, "zoom", Vector2.ONE, 0.28)
	await room_transition_tween.finished

func _resolve_screen_fader() -> void:
	if screen_fader == null:
		screen_fader = get_tree().get_first_node_in_group("screen_fader")
	if screen_fader == null and get_parent() != null:
		screen_fader = get_parent().get_node_or_null("ScreenFader")

func _transition_direction(dir: int) -> Vector2:
	match dir:
		RoomManager.Dir.N:
			return Vector2(0, -1)
		RoomManager.Dir.E:
			return Vector2(1, 0)
		RoomManager.Dir.S:
			return Vector2(0, 1)
		RoomManager.Dir.W:
			return Vector2(-1, 0)
	return Vector2.ZERO

func _stop_room_transition_tween() -> void:
	if room_transition_tween != null:
		room_transition_tween.kill()
		room_transition_tween = null

func is_time_stopped() -> bool:
	return get_bullet_time_world_scale() <= 0.02

func is_bullet_time_engaged() -> bool:
	return bullet_time_blend > 0.01

func get_bullet_time_world_scale() -> float:
	var eased := pow(clampf(1.0 - bullet_time_blend, 0.0, 1.0), bullet_time_slowdown_power)
	if bullet_time_blend <= 0.0:
		return 1.0
	return eased

func on_enemy_killed(enemy: Node = null) -> void:
	bullet_time_charge = minf(get_bullet_time_capacity(), bullet_time_charge + bullet_time_kill_recharge_seconds + _bullet_time_kill_recharge_bonus)
	if _heal_on_kill > 0:
		heal(_heal_on_kill)
	run_kill_count += 1
	var score_gain: int = 10
	if enemy != null and "is_boss" in enemy and bool(enemy.get("is_boss")):
		score_gain = 250
	elif enemy != null and "max_health" in enemy:
		score_gain += int(enemy.get("max_health"))
	run_score += score_gain
	_update_hud_bullet_time()
	_update_hud_run_meta()
	_update_hud_inventory()

func _set_bullet_time_active(active: bool) -> void:
	if is_bullet_time_active == active:
		return
	is_bullet_time_active = active
	_update_player_sprite()
	if background_music == null:
		background_music = get_tree().get_first_node_in_group("background_music")
	if background_music != null and background_music.has_method("set_bullet_time_audio"):
		background_music.set_bullet_time_audio(active)
	_update_hud_bullet_time()

func _update_hud_bullet_time() -> void:
	if hud != null and hud.has_method("update_bullet_time"):
		hud.update_bullet_time(bullet_time_charge, get_bullet_time_capacity(), is_bullet_time_active or bullet_time_blend > 0.0)

func _update_bullet_time_blend(delta: float) -> void:
	var target := 0.0
	var duration := bullet_time_ramp_out_duration
	if is_bullet_time_active:
		target = 1.0
		duration = bullet_time_ramp_in_duration

	if duration <= 0.0:
		bullet_time_blend = target
		return

	bullet_time_blend = move_toward(bullet_time_blend, target, delta / duration)

func _update_player_sprite() -> void:
	if sprite == null:
		return

	var target_texture := PLAYER_BASE_TEXTURE
	if is_bullet_time_active:
		target_texture = PLAYER_NEO_TEXTURE

	sprite.texture = target_texture
	sprite.scale = _scaled_sprite_size_for(target_texture)

func _scaled_sprite_size_for(texture: Texture2D) -> Vector2:
	if texture == null:
		return _base_sprite_scale

	var base_size := PLAYER_BASE_TEXTURE.get_size()
	var texture_size := texture.get_size()
	if base_size.x <= 0 or base_size.y <= 0 or texture_size.x <= 0 or texture_size.y <= 0:
		return _base_sprite_scale

	return Vector2(
		_base_sprite_scale.x * float(base_size.x) / float(texture_size.x),
		_base_sprite_scale.y * float(base_size.y) / float(texture_size.y)
	)

func _drop_active_item_on_floor(item: ItemData) -> void:
	if item == null or ITEM_PICKUP_SCENE == null or get_tree() == null:
		return
	var pickup := ITEM_PICKUP_SCENE.instantiate()
	if pickup == null:
		return
	pickup.set("item_data", item)
	pickup.set("amount", 1)
	if pickup.has_method("prepare_spawn_protection"):
		pickup.call("prepare_spawn_protection", 0.12, true)
	var drop_offset := Vector2(36, -10)
	var room_parent: Node = null
	var room_manager := get_tree().get_first_node_in_group("room_manager")
	if room_manager != null:
		var room_instance: Node = room_manager.get("current_room_instance")
		if room_instance != null:
			room_parent = room_instance
	if room_parent == null:
		var room_root := get_tree().get_first_node_in_group("room_root")
		if room_root != null:
			room_parent = room_root
	if room_parent == null:
		room_parent = get_tree().current_scene
	if room_parent != null:
		room_parent.call_deferred("add_child", pickup)
		if pickup is Node2D:
			(pickup as Node2D).set_deferred("global_position", global_position + drop_offset)

func _play_damage_feedback() -> void:
	if sprite == null:
		return
	if _damage_feedback_tween != null:
		_damage_feedback_tween.kill()
	_damage_feedback_tween = create_tween()
	sprite.modulate = Color(1.0, 0.35, 0.35, 1.0)
	_damage_feedback_tween.set_trans(Tween.TRANS_SINE)
	_damage_feedback_tween.set_ease(Tween.EASE_OUT)
	_damage_feedback_tween.parallel().tween_property(sprite, "modulate", Color.WHITE, 0.16)
	if camera != null:
		camera.offset += Vector2(10, -6)
		_damage_feedback_tween.parallel().tween_property(camera, "offset", Vector2.ZERO, 0.18)

func _spawn_bullet(dir: Vector2) -> void:
	_spawn_custom_bullet(dir, get_damage_per_shot(), get_projectile_speed_current())
	if _bonus_bullet_count <= 0:
		return
	for index in range(_bonus_bullet_count):
		var side_sign := -1.0 if index % 2 == 0 else 1.0
		var ring := int(index / 2) + 1
		var angle_offset := 0.12 * float(ring) * side_sign
		_spawn_custom_bullet(dir.rotated(angle_offset), get_damage_per_shot(), get_projectile_speed_current())

func _spawn_custom_bullet(dir: Vector2, custom_damage: int, custom_speed: float) -> void:
	if bullet_scene == null:
		return
	var bullet = bullet_scene.instantiate()
	if bullet == null:
		return
	bullet.global_position = global_position + dir.normalized() * bullet_spawn_offset
	bullet.direction = dir.normalized()
	bullet.damage = custom_damage
	bullet.speed = custom_speed
	bullet.add_to_group("bullet")
	get_tree().current_scene.add_child(bullet)
