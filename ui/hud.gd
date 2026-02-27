extends CanvasLayer

@onready var health_label: Label = $VBoxContainer/HealthLabel
@onready var key_label: Label = $VBoxContainer/KeyLabel
@onready var hint_label: Label = $VBoxContainer/HintLabel

func _ready() -> void:
	# стартовые значения, чтобы не было пусто
	update_health(0)
	update_keys(0)
	set_hint("WASD move, Arrows shoot, Hold R restart, Esc pause")

func update_health(value: int) -> void:
	health_label.text = "HP: " + str(value)

func update_keys(value: int) -> void:
	key_label.text = "Keys: " + str(value)

func set_hint(text: String) -> void:
	hint_label.text = text

func clear_hint() -> void:
	hint_label.text = ""
