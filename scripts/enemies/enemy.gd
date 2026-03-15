extends CharacterBody2D

const SfxLib = preload("res://scripts/core/sfx_library.gd")
const LootTableLib = preload("res://scripts/core/loot_tables.gd")
const HEART_PICKUP_SCENE = preload("res://scenes/ItemPickup.tscn")
const HEART_ITEM_DATA = preload("res://assets/items/heart.tres")
const ENEMY_PROJECTILE_SCENE = preload("res://scenes/enemies/EnemyProjectile.tscn")

signal died(enemy: CharacterBody2D)

@export var speed: float = 100.0
@export var damage: int = 1
@export var attack_cooldown: float = 1.0
@export var corpse_hold_duration: float = 0.5
@export var corpse_dissolve_duration: float = 0.28
@export var attack_style: String = "contact"
@export var projectile_cooldown: float = 1.4
@export var projectile_speed: float = 360.0
@export var projectile_range: float = 360.0
@export var preferred_distance: float = 210.0
@export var leap_cooldown: float = 1.6
@export var leap_speed: float = 540.0
@export var leap_duration: float = 0.24
@export var leap_trigger_range: float = 240.0
@export var boss_phase_2_threshold: float = 0.66
@export var boss_phase_3_threshold: float = 0.33
@export var boss_burst_cooldown: float = 2.4
@export var boss_burst_projectiles: int = 10

@export var max_health: int = 3
@export var heart_drop_chance: float = 0.25
@export var special_item_drop_chance: float = 0.05
@export var can_drop_special_items: bool = true
@export var is_boss: bool = false
@export var avoidance_probe_distance: float = 22.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var damage_area: Area2D = $DamageArea
@onready var damage_shape: CollisionShape2D = $DamageArea/CollisionShape2D
@onready var health_bar: Node2D = get_node_or_null("EnemyHealthBar")

var health: int = 0

var can_attack: bool = true
var player: CharacterBody2D = null
var is_dead: bool = false
var is_active: bool = false
var _rng := RandomNumberGenerator.new()
var _avoidance_turn_bias: float = 1.0
var _projectile_cooldown_remaining: float = 0.0
var _leap_cooldown_remaining: float = 0.0
var _leap_time_remaining: float = 0.0
var _leap_direction: Vector2 = Vector2.ZERO
var _boss_burst_cooldown_remaining: float = 0.0
var _current_phase: int = 1
var _mutation_id: String = ""
var _mutation_tint: Color = Color.WHITE
var _phase_tint: Color = Color.WHITE
var _alive_modulate: Color = Color.WHITE

func _ready():
	player = get_tree().get_first_node_in_group("player")
	health = max_health
	_rng.randomize()
	_avoidance_turn_bias = -1.0 if _rng.randf() < 0.5 else 1.0
	_alive_modulate = modulate

func _physics_process(delta):
	if player == null or is_dead or not is_active:
		velocity = Vector2.ZERO
		return

	var world_scale: float = 1.0
	if player.has_method("get_bullet_time_world_scale"):
		world_scale = player.get_bullet_time_world_scale()
	var time_scale_delta: float = delta * world_scale
	var is_time_frozen: bool = world_scale <= 0.02

	if not is_time_frozen:
		_projectile_cooldown_remaining = maxf(0.0, _projectile_cooldown_remaining - time_scale_delta)
		_leap_cooldown_remaining = maxf(0.0, _leap_cooldown_remaining - time_scale_delta)
		_boss_burst_cooldown_remaining = maxf(0.0, _boss_burst_cooldown_remaining - time_scale_delta)
	_update_phase_state()

	if _leap_time_remaining > 0.0:
		if not is_time_frozen:
			_leap_time_remaining = maxf(0.0, _leap_time_remaining - time_scale_delta)
		velocity = _leap_direction * leap_speed * world_scale
		move_and_slide()
		_attempt_contact_damage()
		return

	var direction := _get_behavior_direction()
	velocity = direction * speed * world_scale
	move_and_slide()
	_attempt_contact_damage()

func _attempt_contact_damage() -> void:
	if damage_area == null or not can_attack or is_dead or not is_active:
		return

	for body in damage_area.get_overlapping_bodies():
		if _can_damage_body(body):
			_deal_contact_damage(body)
			return

func _can_damage_body(body: Node) -> bool:
	if body == null or not body.has_method("take_damage") or health <= 0:
		return false
	if body.has_method("is_bullet_time_engaged") and body.is_bullet_time_engaged():
		return false
	return true

func _deal_contact_damage(body: Node) -> void:
	can_attack = false
	body.take_damage(damage)
	_start_attack_cooldown()

func _start_attack_cooldown() -> void:
	if get_tree() == null:
		return
	await get_tree().create_timer(attack_cooldown).timeout
	if not is_dead:
		can_attack = true

func _on_damage_area_body_entered(body):
	if is_active and can_attack and _can_damage_body(body):
		_deal_contact_damage(body)


func _get_behavior_direction() -> Vector2:
	if attack_style == "shooter":
		return _get_shooter_direction()
	if attack_style == "jumper":
		return _get_jumper_direction()
	if attack_style == "boss":
		return _get_boss_direction()
	return _get_navigation_direction()

func _get_navigation_direction() -> Vector2:
	var desired := (player.global_position - global_position).normalized()
	if desired == Vector2.ZERO:
		return Vector2.ZERO
	if not _is_direction_blocked(desired):
		return desired

	var angles := [
		25.0 * _avoidance_turn_bias,
		-25.0 * _avoidance_turn_bias,
		50.0 * _avoidance_turn_bias,
		-50.0 * _avoidance_turn_bias,
		80.0 * _avoidance_turn_bias,
		-80.0 * _avoidance_turn_bias,
		120.0 * _avoidance_turn_bias,
		-120.0 * _avoidance_turn_bias,
	]

	for angle in angles:
		var candidate := desired.rotated(deg_to_rad(angle))
		if not _is_direction_blocked(candidate):
			_avoidance_turn_bias = 1.0 if angle >= 0.0 else -1.0
			return candidate

	return desired

func _get_shooter_direction() -> Vector2:
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var world_scale: float = 1.0
	if player.has_method("get_bullet_time_world_scale"):
		world_scale = player.get_bullet_time_world_scale()
	if world_scale > 0.02 and distance <= projectile_range and _projectile_cooldown_remaining <= 0.0:
		_fire_projectile(to_player.normalized())
		_projectile_cooldown_remaining = projectile_cooldown

	if distance > preferred_distance + 26.0:
		return _get_navigation_direction()
	if distance < preferred_distance * 0.7:
		var retreat := (-to_player).normalized()
		if not _is_direction_blocked(retreat):
			return retreat
	var strafe := to_player.normalized().rotated(deg_to_rad(90.0 * _avoidance_turn_bias))
	if not _is_direction_blocked(strafe):
		return strafe
	return Vector2.ZERO

func _get_boss_direction() -> Vector2:
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	if distance == 0.0:
		return Vector2.ZERO
	var world_scale: float = 1.0
	if player.has_method("get_bullet_time_world_scale"):
		world_scale = player.get_bullet_time_world_scale()
	var can_advance_attacks: bool = world_scale > 0.02

	if can_advance_attacks and _boss_burst_cooldown_remaining <= 0.0 and _current_phase >= 2:
		_fire_boss_burst()
		_boss_burst_cooldown_remaining = maxf(0.7, boss_burst_cooldown - float(_current_phase - 1) * 0.45)

	if can_advance_attacks and _projectile_cooldown_remaining <= 0.0 and distance <= projectile_range:
		_fire_projectile(to_player.normalized())
		if _current_phase >= 3:
			_fire_projectile(to_player.normalized().rotated(0.18))
			_fire_projectile(to_player.normalized().rotated(-0.18))
		_projectile_cooldown_remaining = maxf(0.32, projectile_cooldown - float(_current_phase - 1) * 0.22)

	if can_advance_attacks and _current_phase >= 2 and _leap_cooldown_remaining <= 0.0 and distance <= leap_trigger_range:
		_leap_direction = to_player.normalized()
		_leap_time_remaining = leap_duration + float(_current_phase - 2) * 0.05
		_leap_cooldown_remaining = maxf(0.7, leap_cooldown - float(_current_phase - 1) * 0.25)
		return Vector2.ZERO

	if distance > preferred_distance + 36.0:
		return _get_navigation_direction()
	if distance < preferred_distance * 0.72:
		var retreat := (-to_player).normalized()
		if not _is_direction_blocked(retreat):
			return retreat
	var strafe := to_player.normalized().rotated(deg_to_rad(90.0 * _avoidance_turn_bias))
	if not _is_direction_blocked(strafe):
		return strafe
	return _get_navigation_direction() * 0.45

func _get_jumper_direction() -> Vector2:
	var to_player := player.global_position - global_position
	var distance := to_player.length()
	var world_scale: float = 1.0
	if player.has_method("get_bullet_time_world_scale"):
		world_scale = player.get_bullet_time_world_scale()
	if world_scale > 0.02 and distance <= leap_trigger_range and _leap_cooldown_remaining <= 0.0:
		_leap_direction = to_player.normalized()
		_leap_time_remaining = leap_duration
		_leap_cooldown_remaining = leap_cooldown
		return Vector2.ZERO
	return _get_navigation_direction() * 0.72

func _fire_projectile(direction: Vector2) -> void:
	if ENEMY_PROJECTILE_SCENE == null or direction == Vector2.ZERO:
		return
	var projectile := ENEMY_PROJECTILE_SCENE.instantiate()
	if projectile == null:
		return
	projectile.set("direction", direction.normalized())
	projectile.set("speed", projectile_speed)
	projectile.set("damage", damage)
	if projectile is Node2D:
		(projectile as Node2D).global_position = global_position + direction.normalized() * 34.0
	get_tree().current_scene.add_child(projectile)

func _fire_boss_burst() -> void:
	var count: int = max(6, boss_burst_projectiles + (_current_phase - 2) * 2)
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		var dir := Vector2.RIGHT.rotated(angle)
		_fire_projectile(dir)

func _update_phase_state() -> void:
	if not is_boss or max_health <= 0:
		return
	var ratio := float(health) / float(max_health)
	var next_phase := 1
	if ratio <= boss_phase_3_threshold:
		next_phase = 3
	elif ratio <= boss_phase_2_threshold:
		next_phase = 2
	if next_phase == _current_phase:
		return
	_current_phase = next_phase
	match _current_phase:
		2:
			_phase_tint = Color(1.0, 0.66, 0.66, 1.0)
		3:
			_phase_tint = Color(1.0, 0.34, 0.34, 1.0)
		_:
			_phase_tint = Color.WHITE
	_refresh_alive_modulate()


func _is_direction_blocked(direction: Vector2) -> bool:
	if direction == Vector2.ZERO:
		return false
	return test_move(global_transform, direction.normalized() * avoidance_probe_distance)


func take_damage(amount: int):
	if is_dead:
		return

	if health > 0:
		health -= amount
	
	if health < 0:
		health = 0
	if health_bar != null and health_bar.has_method("show_health"):
		health_bar.show_health(health, max_health)

	if health <= 0:
		modulate = Color(0.86, 0.18, 0.22, 1.0)
		die()
		return

	modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		modulate = _alive_modulate

func die():
	if is_dead:
		return
	is_dead = true
	is_active = false
	self.speed = 0
	velocity = Vector2.ZERO
	modulate = Color(0.62, 0.08, 0.12, 1.0)
	if health_bar != null and health_bar.has_method("hide_immediately"):
		health_bar.hide_immediately()
	_disable_collision()
	SfxLib.play_enemy_death(self)
	call_deferred("_maybe_drop_heart_deferred")
	call_deferred("_maybe_drop_special_item_deferred")
	emit_signal("died", self)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("on_enemy_killed"):
		player.on_enemy_killed(self)
	call_deferred("_dissolve_and_queue_free")


func _on_damage_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet"):
		var hit_damage: int = 1
		var area_damage = area.get("damage")
		if area_damage != null:
			hit_damage = int(area_damage)
		take_damage(hit_damage)
		area.queue_free()

func set_active(active: bool) -> void:
	is_active = active
	if not active:
		velocity = Vector2.ZERO

func apply_mutation(mutation_id: String) -> void:
	_mutation_id = mutation_id
	match mutation_id:
		"titan":
			max_health = int(round(float(max_health) * 1.8))
			health = max_health
			damage += 1
			speed *= 0.9
			scale *= 1.18
			_mutation_tint = Color(0.8, 1.0, 0.72, 1.0)
		"swift":
			speed *= 1.55
			attack_cooldown *= 0.78
			projectile_cooldown *= 0.78
			leap_cooldown *= 0.82
			leap_speed *= 1.18
			_mutation_tint = Color(0.72, 0.94, 1.0, 1.0)
		"brutal":
			damage += 2
			attack_cooldown *= 0.72
			projectile_cooldown *= 0.88
			_mutation_tint = Color(1.0, 0.82, 0.58, 1.0)
		"sniper":
			projectile_speed *= 1.35
			projectile_range *= 1.45
			preferred_distance += 90.0
			if attack_style == "contact":
				attack_style = "shooter"
			_mutation_tint = Color(0.92, 0.72, 1.0, 1.0)
		"rabid":
			leap_cooldown *= 0.68
			leap_speed *= 1.28
			leap_duration *= 1.18
			leap_trigger_range += 60.0
			if attack_style == "contact":
				attack_style = "jumper"
			elif attack_style == "shooter":
				projectile_cooldown *= 0.9
			_mutation_tint = Color(1.0, 0.62, 0.86, 1.0)
		_:
			_mutation_tint = Color.WHITE
	_refresh_alive_modulate()
	if health_bar != null and health_bar.has_method("show_health"):
		health_bar.show_health(health, max_health)

func _refresh_alive_modulate() -> void:
	_alive_modulate = _mutation_tint * _phase_tint
	_alive_modulate.a = 1.0
	if not is_dead:
		modulate = _alive_modulate

func _maybe_drop_heart_deferred() -> void:
	if HEART_PICKUP_SCENE == null or HEART_ITEM_DATA == null:
		return
	if randf() > heart_drop_chance:
		return
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.has_method("needs_healing") and not bool(player.call("needs_healing")):
		return

	var pickup := HEART_PICKUP_SCENE.instantiate()
	if pickup == null:
		return

	pickup.set("item_data", HEART_ITEM_DATA)
	pickup.set("amount", 1)

	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return

	var angle := randf_range(-1.1, 1.1)
	var distance := randf_range(34.0, 52.0)
	var offset := Vector2.RIGHT.rotated(angle) * distance
	offset.y -= randf_range(10.0, 18.0)

	parent.call_deferred("add_child", pickup)
	if pickup is Node2D:
		(pickup as Node2D).set_deferred("global_position", global_position + offset)
	if pickup.has_method("prepare_spawn_protection"):
		pickup.call_deferred("prepare_spawn_protection", 0.08, true)

func _maybe_drop_special_item_deferred() -> void:
	if not can_drop_special_items or is_boss:
		return
	if HEART_PICKUP_SCENE == null:
		return
	if _rng.randf() > special_item_drop_chance:
		return

	var reward := LootTableLib.pick_random_passive_item(_rng)
	if reward == null:
		return

	var pickup := HEART_PICKUP_SCENE.instantiate()
	if pickup == null:
		return

	pickup.set("item_data", reward)
	pickup.set("amount", 1)

	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	if parent == null:
		return

	var angle := _rng.randf_range(-0.75, 0.75)
	var distance := _rng.randf_range(28.0, 44.0)
	var offset := Vector2.RIGHT.rotated(angle) * distance
	offset.y -= _rng.randf_range(8.0, 16.0)

	parent.call_deferred("add_child", pickup)
	if pickup is Node2D:
		(pickup as Node2D).set_deferred("global_position", global_position + offset)
	if pickup.has_method("prepare_spawn_protection"):
		pickup.call_deferred("prepare_spawn_protection", 0.08, true)

func _disable_collision() -> void:
	set_collision_layer_value(6, false)
	set_collision_mask_value(1, false)
	if body_shape != null:
		body_shape.set_deferred("disabled", true)
	if damage_shape != null:
		damage_shape.set_deferred("disabled", true)
	if damage_area != null:
		damage_area.set_deferred("monitoring", false)
		damage_area.set_deferred("monitorable", false)

func _dissolve_and_queue_free() -> void:
	if corpse_hold_duration > 0.0 and get_tree() != null:
		await get_tree().create_timer(corpse_hold_duration).timeout
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", scale * 0.84, corpse_dissolve_duration)
	if sprite != null:
		tween.parallel().tween_property(sprite, "modulate:a", 0.0, corpse_dissolve_duration)
	tween.parallel().tween_property(self, "modulate:a", 0.0, corpse_dissolve_duration)
	await tween.finished
	queue_free()
