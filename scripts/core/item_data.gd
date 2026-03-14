extends Resource
class_name ItemData

@export var id: String
@export var display_name: String
@export var icon: Texture2D
@export var stackable: bool = true
@export var max_stack: int = 99
@export var pickup_kind: String = "inventory"
@export var heal_amount: int = 0
@export var damage_delta: int = 0
@export var attack_speed_delta: float = 0.0
@export var max_health_delta: int = 0
@export var display_lines: PackedStringArray = PackedStringArray()
@export var active_kind: String = ""
@export var active_cooldown_seconds: float = 0.0
