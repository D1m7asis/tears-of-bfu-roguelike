extends CharacterBody2D

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

@export var max_health: int = 5
var health: int = 0
@onready var hud = null

@export var game_over_scene_path: String = "res://scenes/ui/GameOver.tscn"
@export var victory_scene_path: String = "res://scenes/ui/Victory.tscn"
@export var death_fade_duration: float = 0.5
@export var death_hold_duration: float = 0.2

var door_lock_time: float = 0.0
@export var door_lock_after_teleport: float = 0.25
var is_dying: bool = false

func _ready() -> void:
	add_to_group("player")

	health = max_health
	restart_overlay = get_tree().get_first_node_in_group("restart_overlay")
	hud = get_tree().get_first_node_in_group("hud")
	_resolve_screen_fader()
	_update_hud_all()

func _physics_process(delta: float) -> void:
	if is_dying:
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
	if is_dying:
		return

	if door_lock_time > 0.0:
		door_lock_time -= delta

	if Input.is_action_just_pressed("pause_game"):
		get_tree().paused = not get_tree().paused

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

func shoot(dir: Vector2) -> void:
	if is_dying or not can_shoot:
		return
	can_shoot = false

	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position + dir * bullet_spawn_offset
	bullet.direction = dir
	bullet.add_to_group("bullet")
	get_tree().current_scene.add_child(bullet)

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

func lock_doors() -> void:
	door_lock_time = door_lock_after_teleport

func can_use_doors() -> bool:
	return door_lock_time <= 0.0

func _resolve_screen_fader() -> void:
	if screen_fader == null:
		screen_fader = get_tree().get_first_node_in_group("screen_fader")
	if screen_fader == null and get_parent() != null:
		screen_fader = get_parent().get_node_or_null("ScreenFader")
