extends CharacterBody2D

@export var speed: float = 100.0
@export var damage: int = 1
@export var attack_cooldown: float = 1.0

@export var max_health: int = 3
var health: int = 0

var can_attack: bool = true
var player: CharacterBody2D = null
var is_dead: bool = false

func _ready():
	player = get_tree().get_first_node_in_group("player")
	health = max_health

func _physics_process(_delta):
	if player == null or is_dead:
		return
	if player.has_method("is_time_stopped") and player.is_time_stopped():
		velocity = Vector2.ZERO
		return
	
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	move_and_slide()

func _on_damage_area_body_entered(body):
	if body.has_method("take_damage") and can_attack and health > 0:
		can_attack = false
		body.take_damage(damage)
		print("get_tree() 2", str(get_tree()))
		if get_tree() != null:
			await get_tree().create_timer(attack_cooldown).timeout
		can_attack = true


func take_damage(amount: int):
	if is_dead:
		return

	if health > 0:
		health -= amount
	
	if health < 0:
		health = 0

	if health <= 0:
		modulate = Color(0.86, 0.18, 0.22, 1.0)
		die()
		return

	modulate = Color(1, 0.5, 0.5)
	await get_tree().create_timer(0.1).timeout
	if not is_dead:
		modulate = Color(1, 1, 1)

func die():
	if is_dead:
		return
	is_dead = true
	self.speed = 0
	velocity = Vector2.ZERO
	modulate = Color(0.62, 0.08, 0.12, 1.0)
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("on_enemy_killed"):
		player.on_enemy_killed()


func _on_damage_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("bullet"):
		take_damage(1)
		area.queue_free()
