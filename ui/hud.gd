extends CanvasLayer

@onready var health_label: Label = $VBoxContainer/HealthLabel
@onready var key_label: Label = $VBoxContainer/KeyLabel
@onready var hint_label: Label = $VBoxContainer/HintLabel
@onready var minimap: Control = $Minimap


func _ready() -> void:
	# стартовые значения, чтобы не было пусто
	update_health(0)
	update_keys(0)
	set_hint("WASD move, Arrows shoot, Hold R restart, Esc pause")

	var rm := get_tree().get_first_node_in_group("room_manager")
	if rm != null and minimap != null and minimap.has_method("bind_room_manager"):
		minimap.bind_room_manager(rm)

func update_health(value: int) -> void:
	health_label.text = "HP: " + str(value)

func update_keys(value: int) -> void:
	key_label.text = "Keys: " + str(value)

func set_hint(text: String) -> void:
	hint_label.text = text

func clear_hint() -> void:
	hint_label.text = ""
