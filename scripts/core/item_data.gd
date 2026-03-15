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
@export var move_speed_delta: float = 0.0
@export var bullet_time_capacity_delta: float = 0.0
@export var bullet_time_kill_recharge_delta: float = 0.0
@export var heal_on_kill: int = 0
@export var damage_reduction: int = 0
@export var active_cooldown_multiplier: float = 1.0
@export var bonus_bullet_count: int = 0
@export var projectile_speed_delta: float = 0.0
@export var display_lines: PackedStringArray = PackedStringArray()
@export var active_kind: String = ""
@export var active_cooldown_seconds: float = 0.0
@export var rarity_tier: String = "common"


func build_stat_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if pickup_kind == "active_item":
		return display_lines
	if damage_delta != 0:
		lines.append("DMG %s%d" % ["+" if damage_delta > 0 else "", damage_delta])
	if attack_speed_delta != 0.0:
		lines.append("ATS %s%.1f" % ["+" if attack_speed_delta > 0.0 else "", attack_speed_delta])
	if max_health_delta != 0:
		lines.append("MAX HP %s%d" % ["+" if max_health_delta > 0 else "", max_health_delta])
	if move_speed_delta != 0.0:
		lines.append("SPD %s%d" % ["+" if move_speed_delta > 0.0 else "", int(round(move_speed_delta))])
	if bullet_time_capacity_delta != 0.0:
		lines.append("FOCUS MAX %s%.1f" % ["+" if bullet_time_capacity_delta > 0.0 else "", bullet_time_capacity_delta])
	if bullet_time_kill_recharge_delta != 0.0:
		lines.append("FOCUS/KILL %s%.1f" % ["+" if bullet_time_kill_recharge_delta > 0.0 else "", bullet_time_kill_recharge_delta])
	if heal_on_kill != 0:
		lines.append("HEAL/KILL +%d" % heal_on_kill)
	if damage_reduction != 0:
		lines.append("ARMOR +%d" % damage_reduction)
	if active_cooldown_multiplier < 0.999:
		lines.append("ACTIVE CD x%.2f" % active_cooldown_multiplier)
	if bonus_bullet_count != 0:
		lines.append("EXTRA SHOTS +%d" % bonus_bullet_count)
	if projectile_speed_delta != 0.0:
		lines.append("SHOT SPD %s%d" % ["+" if projectile_speed_delta > 0.0 else "", int(round(projectile_speed_delta))])
	if lines.is_empty():
		return display_lines
	return lines


func get_rarity_color() -> Color:
	match rarity_tier:
		"uncommon":
			return Color(0.53, 0.95, 0.78, 1.0)
		"rare":
			return Color(0.54, 0.77, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.84, 0.42, 1.0)
		_:
			return Color(0.9, 0.9, 0.9, 1.0)
