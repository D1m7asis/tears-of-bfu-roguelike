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


func get_localized_name() -> String:
	match id:
		"aegis_sigil":
			return "Эгида"
		"berserk_engine":
			return "Берсерк-мотор"
		"blood_pact":
			return "Кровавый пакт"
		"chrono_surge":
			return "Хроно-всплеск"
		"execution_order":
			return "Приказ на казнь"
		"iron_choir":
			return "Железный хор"
		"judgement":
			return "Суд"
		"meteor_bell":
			return "Метеор-колокол"
		"mirror_fan":
			return "Зеркальный веер"
		"phase_cloak":
			return "Фазовый плащ"
		"rail_hymn":
			return "Рельсовый гимн"
		"red_nova":
			return "Красная нова"
		"soul_lantern":
			return "Фонарь душ"
		"stasis_mine":
			return "Стазис-мина"
		"time_flask":
			return "Фляга времени"
		"adamant_spine":
			return "Адамантовый хребет"
		"blood_rush":
			return "Кровавый рывок"
		"blue_fuse":
			return "Синий фитиль"
		"bone_furnace":
			return "Костяная печь"
		"deadeye_loop":
			return "Контур меткости"
		"eclipse_lens":
			return "Линза затмения"
		"fragile_core":
			return "Хрупкое ядро"
		"ghost_trigger":
			return "Призрачный спуск"
		"glass_cannon":
			return "Стеклянная пушка"
		"guardian_shell":
			return "Панцирь хранителя"
		"heavy_caliber":
			return "Тяжёлый калибр"
		"hollow_point":
			return "Экспансивная пуля"
		"hot_clock":
			return "Горячие часы"
		"iron_heart":
			return "Железное сердце"
		"quick_trigger":
			return "Быстрый спуск"
		"red_glass":
			return "Красное стекло"
		"silver_vein":
			return "Серебряная жила"
		"steel_nerves":
			return "Стальные нервы"
		"survival_manual":
			return "Пособие по выживанию"
		"war_drums":
			return "Боевые барабаны"
		"key":
			return "Ключ"
		"heart":
			return "Сердце"
	return display_name


func get_localized_display_lines() -> PackedStringArray:
	if pickup_kind != "active_item":
		return display_lines

	match id:
		"aegis_sigil":
			return PackedStringArray(["Неуязвимость на 4 сек.", "Перезарядка 22 сек."])
		"berserk_engine":
			return PackedStringArray(["УРОН +2, СКОР. АТКИ +2.0 на 8 сек.", "Перезарядка 20 сек."])
		"blood_pact":
			return PackedStringArray(["Потрать 1 HP ради чудовищной силы", "УРОН +5, СКОР. АТКИ +2.5 на 12 сек.", "Перезарядка 28 сек."])
		"chrono_surge":
			return PackedStringArray(["Полностью восстанавливает фокус", "Мгновенно включает замедление", "Перезарядка 24 сек."])
		"execution_order":
			return PackedStringArray(["Казнит ослабленных врагов", "Остальным наносит 5 урона", "Перезарядка 22 сек."])
		"iron_choir":
			return PackedStringArray(["Лечит на 2 и даёт неуязвимость", "Кнопка паники на короткий срок", "Перезарядка 24 сек."])
		"judgement":
			return PackedStringArray(["Стирает всех врагов в комнате", "Полная зачистка помещения", "Перезарядка 60 сек."])
		"meteor_bell":
			return PackedStringArray(["Бьёт всех врагов на 8 урона", "Надёжно ослабляет комнату", "Перезарядка 20 сек."])
		"mirror_fan":
			return PackedStringArray(["Выпускает веер из 24 пуль", "Накрывает почти весь экран", "Перезарядка 14 сек."])
		"phase_cloak":
			return PackedStringArray(["Неуязвимость и ускорение на 2.6 сек.", "Инструмент для отхода или врыва", "Перезарядка 26 сек."])
		"rail_hymn":
			return PackedStringArray(["Даёт 8 тяжёлых рельсовых выстрелов", "Колоссальный взрывной урон", "Перезарядка 18 сек."])
		"red_nova":
			return PackedStringArray(["Взрыв из 16 пуль", "Сносит ближние угрозы", "Перезарядка 10 сек."])
		"soul_lantern":
			return PackedStringArray(["Лечит 1 HP и даёт 1 сек. фокуса", "Выпускает сияющую вспышку", "Перезарядка 17 сек."])
		"stasis_mine":
			return PackedStringArray(["Оглушает всю комнату на 2.6 сек.", "Наносит 2 урона при срабатывании", "Перезарядка 30 сек."])
		"time_flask":
			return PackedStringArray(["Полностью восстанавливает фокус", "Перезарядка 16 сек."])
	return display_lines


func build_stat_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if pickup_kind == "active_item":
		for line in get_localized_display_lines():
			entries.append(_make_entry(line, "neutral"))
		return entries
	if damage_delta != 0:
		entries.append(_make_entry("УРОН %s%d" % [_plus_sign_int(damage_delta), damage_delta], _tone_for_numeric_change(damage_delta)))
	if attack_speed_delta != 0.0:
		entries.append(_make_entry("СКОР. АТКИ %s%.1f" % [_plus_sign_float(attack_speed_delta), attack_speed_delta], _tone_for_numeric_change(attack_speed_delta)))
	if max_health_delta != 0:
		entries.append(_make_entry("МАКС. HP %s%d" % [_plus_sign_int(max_health_delta), max_health_delta], _tone_for_numeric_change(max_health_delta)))
	if move_speed_delta != 0.0:
		entries.append(_make_entry("СКОРОСТЬ %s%d" % [_plus_sign_float(move_speed_delta), int(round(move_speed_delta))], _tone_for_numeric_change(move_speed_delta)))
	if bullet_time_capacity_delta != 0.0:
		entries.append(_make_entry("ФОКУС МАКС %s%.1f" % [_plus_sign_float(bullet_time_capacity_delta), bullet_time_capacity_delta], _tone_for_numeric_change(bullet_time_capacity_delta)))
	if bullet_time_kill_recharge_delta != 0.0:
		entries.append(_make_entry("ФОКУС/КИЛЛ %s%.2f" % [_plus_sign_float(bullet_time_kill_recharge_delta), bullet_time_kill_recharge_delta], _tone_for_numeric_change(bullet_time_kill_recharge_delta)))
	if heal_on_kill != 0:
		entries.append(_make_entry("ЛЕЧЕНИЕ/КИЛЛ +%d" % heal_on_kill, "positive"))
	if damage_reduction != 0:
		entries.append(_make_entry("БРОНЯ +%d" % damage_reduction, "positive"))
	if active_cooldown_multiplier != 1.0:
		var cooldown_tone := "positive" if active_cooldown_multiplier < 1.0 else "negative"
		entries.append(_make_entry("ПЕРЕЗАР. АКТИВКИ x%.2f" % active_cooldown_multiplier, cooldown_tone))
	if bonus_bullet_count != 0:
		entries.append(_make_entry("ДОП. ВЫСТРЕЛЫ +%d" % bonus_bullet_count, "positive"))
	if projectile_speed_delta != 0.0:
		entries.append(_make_entry("СКОР. ПУЛИ %s%d" % [_plus_sign_float(projectile_speed_delta), int(round(projectile_speed_delta))], _tone_for_numeric_change(projectile_speed_delta)))
	if entries.is_empty():
		for line in display_lines:
			entries.append(_make_entry(line, "neutral"))
	return entries


func build_stat_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for entry_variant in build_stat_entries():
		var entry: Dictionary = entry_variant
		lines.append(str(entry.get("text", "")))
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


func _make_entry(text: String, tone: String) -> Dictionary:
	return {
		"text": text,
		"tone": tone,
	}


func _plus_sign_int(value: int) -> String:
	return "+" if value > 0 else ""


func _plus_sign_float(value: float) -> String:
	return "+" if value > 0.0 else ""


func _tone_for_numeric_change(value: Variant) -> String:
	var numeric_value := float(value)
	if numeric_value > 0.0:
		return "positive"
	if numeric_value < 0.0:
		return "negative"
	return "neutral"
