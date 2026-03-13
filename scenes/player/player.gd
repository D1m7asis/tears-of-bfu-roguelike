extends CharacterBody2D

const SfxLibrary = preload("res://scripts/core/sfx_library.gd")
const PLAYER_BASE_TEXTURE = preload("res://assets/sprites/player/player.png")
const PLAYER_NEO_TEXTURE = preload("res://assets/sprites/player/player_neo.png")

@export var speed: float = 300.0

@onready var bullet_scene: PackedScene = preload("res://scenes/player/bullet.tscn")
@export var fire_cooldown: float = 0.3
var can_shoot: bool = true
@export var bullet_spawn_offset: float = 55.0

@export var inventory_size: int = 12
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

@export var game_over_scene_path: String = "res://scenes/ui/GameOver.tscn"
@export var victory_scene_path: String = "res://scenes/ui/Victory.tscn"
@export var death_fade_duration: float = 0.5
@export var death_hold_duration: float = 0.2
@export var bullet_time_max_seconds: float = 5.0
@export var bullet_time_kill_recharge_seconds: float = 1.0
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

func _ready() -> void:
	add_to_group("player")
	process_mode = Node.PROCESS_MODE_ALWAYS

	if sprite != null:
		_base_sprite_scale = sprite.scale
	health = max_health
	bullet_time_charge = bullet_time_max_seconds
	restart_overlay = get_tree().get_first_node_in_group("restart_overlay")
	hud = get_tree().get_first_node_in_group("hud")
	background_music = get_tree().get_first_node_in_group("background_music")
	_resolve_screen_fader()
	_update_hud_all()

func _physics_process(_delta: float) -> void:
	if get_tree().paused:
		velocity = Vector2.ZERO
		return
	if is_dying or is_room_transitioning:
		velocity = Vector2.ZERO
		return

	var direction := Vector2.ZERO

	if Input.is_action_pressed("move_right"):
		rotation_degrees += 5
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		rotation_degrees -= 5
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		rotation_degrees -= 2
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		rotation_degrees += 2
		direction.y -= 1

	direction = direction.normalized()
	velocity = direction * speed
	move_and_slide()

func _process(delta: float) -> void:
	if get_tree().paused:
		_set_bullet_time_active(false)
		return
	if is_dying or is_room_transitioning:
		_set_bullet_time_active(false)
		return

	if door_lock_time > 0.0:
		door_lock_time -= delta

	if Input.is_action_pressed("bullet_time") and bullet_time_charge > 0.0:
		_set_bullet_time_active(true)
	else:
		_set_bullet_time_active(false)

	if is_bullet_time_active:
		bullet_time_charge = maxf(0.0, bullet_time_charge - delta)
		if bullet_time_charge <= 0.0:
			_set_bullet_time_active(false)

	_update_bullet_time_blend(delta)

	if Input.is_action_just_pressed("shoot_right"):
		shoot(Vector2.RIGHT)
	elif Input.is_action_just_pressed("shoot_left"):
		shoot(Vector2.LEFT)
	elif Input.is_action_just_pressed("shoot_up"):
		shoot(Vector2.UP)
	elif Input.is_action_just_pressed("shoot_down"):
		shoot(Vector2.DOWN)

	if Input.is_action_pressed("restart_hold"):
		restart_hold_time += delta
		if restart_overlay != null:
			restart_overlay.set_visible_active(true)
			restart_overlay.set_progress(restart_hold_time / restart_hold_seconds)

		if restart_hold_time >= restart_hold_seconds:
			get_tree().reload_current_scene()
	else:
		restart_hold_time = 0.0
		if restart_overlay != null:
			restart_overlay.set_visible_active(false)
			restart_overlay.set_progress(0.0)

	_update_hud_bullet_time()

func shoot(dir: Vector2) -> void:
	if is_dying or is_room_transitioning or not can_shoot:
		return
	can_shoot = false

	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position + dir * bullet_spawn_offset
	bullet.direction = dir
	bullet.add_to_group("bullet")
	get_tree().current_scene.add_child(bullet)
	SfxLibrary.play_shoot(self)

	await get_tree().create_timer(fire_cooldown).timeout
	can_shoot = true

func add_item(item: ItemData, amount: int = 1) -> bool:
	print(item)

	if item == null or amount <= 0:
		return false

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
	if is_dying:
		return

	health -= amount
	if health < 0:
		health = 0

	_update_hud_health()

	if health <= 0:
		die()

func die() -> void:
	if is_dying:
		return

	is_dying = true
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
	if victory_scene_path != "":
		get_tree().change_scene_to_file(victory_scene_path)

func _update_hud_health() -> void:
	if hud != null and hud.has_method("update_health"):
		hud.update_health(health)

func _update_hud_keys() -> void:
	if hud != null and hud.has_method("update_keys"):
		hud.update_keys(count_item_id("key"))

func _update_hud_all() -> void:
	_update_hud_health()
	_update_hud_keys()
	_update_hud_bullet_time()

func lock_doors() -> void:
	door_lock_time = door_lock_after_teleport

func can_use_doors() -> bool:
	return door_lock_time <= 0.0 and not is_room_transitioning

func begin_room_transition(exit_dir: int) -> void:
	is_room_transitioning = true
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
	velocity = Vector2.ZERO

func play_room_arrival_effect(entered_from: int) -> void:
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

func on_enemy_killed() -> void:
	bullet_time_charge = minf(bullet_time_max_seconds, bullet_time_charge + bullet_time_kill_recharge_seconds)
	_update_hud_bullet_time()

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
		hud.update_bullet_time(bullet_time_charge, bullet_time_max_seconds, is_bullet_time_active or bullet_time_blend > 0.0)

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
