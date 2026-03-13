extends CharacterBody2D

@export var speed: float = 100.0
@export var damage: int = 1
@export var attack_cooldown: float = 1.0

@export var max_health: int = 3
var health: int = 0

var can_attack: bool = true
var player: CharacterBody2D = null

func _ready():
	player = get_tree().get_first_node_in_group("player")
	health = max_health

func _physics_process(delta):
	if player == null:
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
	if health > 0:
		health -= amount
		modulate = Color(1, 0.5, 0.5)
		await get_tree().create_timer(0.1).timeout
		modulate = Color(1, 1, 1)
	
	if health < 0:
		health = 0
	
	# update_hud_above_head()

	if health <= 0:
		die()

func die():
	self.speed = 0
	modulate = Color(0.388, 0.0, 0.137, 1.0)


func _on_damage_area_area_entered(area: Area2D) -> void:
	print("area is: ", area)
	
			
	if area.is_in_group("bullet"):
		take_damage(1)  # Enemy takes 1 damage from bullet
		area.queue_free()  # Remove the bullet
