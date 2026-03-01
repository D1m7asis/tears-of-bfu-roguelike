extends Node2D

@onready var door_n = $Doors/Door_N
@onready var door_e = $Doors/Door_E
@onready var door_s = $Doors/Door_S
@onready var door_w = $Doors/Door_W

func apply_room_data(data: Dictionary) -> void:
	var doors = data["doors"]
	door_n.visible = doors[RoomManager.Dir.N]
	door_e.visible = doors[RoomManager.Dir.E]
	door_s.visible = doors[RoomManager.Dir.S]
	door_w.visible = doors[RoomManager.Dir.W]

	door_n.trigger.monitoring = door_n.visible
	door_e.trigger.monitoring = door_e.visible
	door_s.trigger.monitoring = door_s.visible
	door_w.trigger.monitoring = door_w.visible
