extends CharacterBody2D

@export var speed: float = 300.0

# shooting
@onready var bullet_scene: PackedScene = preload("res://scenes/player/bullet.tscn")
@export var fire_cooldown: float = 0.3
var can_shoot: bool = true
@export var bullet_spawn_offset: float = 55.0

# inventory
@export var inventory_size: int = 12
var inventory: Array[Dictionary] = [] # { "data": ItemData, "count": int }

# restart hold
@export var restart_hold_seconds: float = 3.0
var restart_hold_time: float = 0.0
@onready var restart_overlay = null

# UI / states (LR6)
@export var max_health: int = 5
var health: int = 0
@onready var hud = null

@export var game_over_scene_path: String = "res://scenes/ui/game_over.tscn"
@export var victory_scene_path: String = "res://scenes/ui/victory.tscn"

func _ready():
	health = max_health

	restart_overlay = get_tree().get_first_node_in_group("restart_overlay")
	hud = get_tree().get_first_node_in_group("hud")

	_update_hud_all()

func _physics_process(delta):
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

func _process(delta):
	# pause toggle
	if Input.is_action_just_pressed("pause_game"):
		get_tree().paused = not get_tree().paused

	# shooting
	if Input.is_action_just_pressed("shoot_right"):
		shoot(Vector2.RIGHT)
	elif Input.is_action_just_pressed("shoot_left"):
		shoot(Vector2.LEFT)
	elif Input.is_action_just_pressed("shoot_up"):
		shoot(Vector2.UP)
	elif Input.is_action_just_pressed("shoot_down"):
		shoot(Vector2.DOWN)

	# hold-to-restart
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

func shoot(dir: Vector2):
	if not can_shoot:
		return
	can_shoot = false

	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position + dir * bullet_spawn_offset
	bullet.direction = dir
	get_tree().current_scene.add_child(bullet)

	await get_tree().create_timer(fire_cooldown).timeout
	can_shoot = true

# -----------------------
# Inventory API
# -----------------------

func add_item(item: ItemData, amount: int = 1) -> bool:
	if item == null or amount <= 0:
		return false

	# stack into existing slot first
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

	# add new slots
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

# -----------------------
# Health / states
# -----------------------

func take_damage(amount: int):
	health -= amount
	modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)
	
	if health < 0:
		health = 0
	
	_update_hud_health()

	if health <= 0:
		die()

func heal(amount: int):
	health += amount
	if health > max_health:
		health = max_health
	_update_hud_health()

func die():
	# можно сделать анимацию, но для ЛР6 достаточно перехода сцены
	if game_over_scene_path != "":
		get_tree().change_scene_to_file(game_over_scene_path)
	else:
		get_tree().reload_current_scene()

func win():
	if victory_scene_path != "":
		get_tree().change_scene_to_file(victory_scene_path)

# -----------------------
# HUD helpers
# -----------------------

func _update_hud_health():
	if hud != null and hud.has_method("update_health"):
		hud.update_health(health)

func _update_hud_keys():
	if hud != null and hud.has_method("update_keys"):
		hud.update_keys(count_item_id("key"))

func _update_hud_all():
	_update_hud_health()
	_update_hud_keys()
