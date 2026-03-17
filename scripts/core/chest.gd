extends Area2D

const LootTableLib = preload("res://scripts/core/loot_tables.gd")
const ITEM_PICKUP_SCENE = preload("res://scenes/ItemPickup.tscn")

@export var closed_texture: Texture2D
@export var open_texture: Texture2D
@export var rng_seed_offset: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _is_open: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("floor_pickup")
	_rng.randomize()
	z_index = 18
	_apply_visual_state()


func _on_body_entered(body: Node) -> void:
	if _is_open:
		return
	if body == null or not body.is_in_group("player"):
		return
	if not body.has_method("has_item_id") or not body.has_method("remove_item_id"):
		return
	if not body.has_item_id("key", 1):
		return

	body.remove_item_id("key", 1)
	call_deferred("_open_chest")


func _open_chest() -> void:
	_is_open = true
	_apply_visual_state()
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	var reward := LootTableLib.pick_random_passive_item(_rng)
	if reward != null and ITEM_PICKUP_SCENE != null:
		var pickup := ITEM_PICKUP_SCENE.instantiate()
		if pickup != null:
			pickup.set("item_data", reward)
			pickup.set("amount", 1)
			if pickup.has_method("prepare_spawn_protection"):
				pickup.call("prepare_spawn_protection", 0.08, true)
			var parent := get_parent()
			var spawn_position := global_position + Vector2(0, -24)
			var room_owner := _find_room_owner()
			if room_owner != null and room_owner.has_method("find_free_drop_position"):
				spawn_position = room_owner.find_free_drop_position(global_position, 92.0)
			if parent != null:
				parent.call_deferred("add_child", pickup)
			if pickup is Node2D:
				(pickup as Node2D).set_deferred("global_position", spawn_position)

	var room_owner := _find_room_owner()
	if room_owner != null and room_owner.has_method("on_chest_opened"):
		room_owner.call_deferred("on_chest_opened", self)
	if room_owner != null and room_owner.has_method("on_room_pickup_changed"):
		room_owner.call_deferred("on_room_pickup_changed")
func get_minimap_icon_id() -> String:
	return "" if _is_open else "chest"


func get_interaction_hint() -> String:
	if _is_open:
		return ""
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("has_item_id") and player.has_item_id("key", 1):
		return "Сундук\nПотрать 1 ключ, чтобы открыть"
	return "Сундук\nНужен 1 ключ"


func _apply_visual_state() -> void:
	if sprite == null:
		return
	sprite.texture = open_texture if _is_open and open_texture != null else closed_texture


func _find_room_owner() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("on_chest_opened"):
			return node
		node = node.get_parent()
	return null
