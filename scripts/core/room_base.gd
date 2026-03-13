extends Node2D

@onready var door_n = $Doors/Door_N
@onready var door_e = $Doors/Door_E
@onready var door_s = $Doors/Door_S
@onready var door_w = $Doors/Door_W

func apply_room_data(data: Dictionary) -> void:
	var exist = data["doors_exist"]
	var open = data["doors_open"]

	_apply_one(door_n, exist[RoomManager.Dir.N], open[RoomManager.Dir.N])
	_apply_one(door_e, exist[RoomManager.Dir.E], open[RoomManager.Dir.E])
	_apply_one(door_s, exist[RoomManager.Dir.S], open[RoomManager.Dir.S])
	_apply_one(door_w, exist[RoomManager.Dir.W], open[RoomManager.Dir.W])

func _apply_one(door, exists: bool, opened: bool) -> void:
	door.visible = exists
	door.starts_open = opened
	door.set_open(opened)
