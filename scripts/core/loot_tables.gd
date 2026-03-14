extends RefCounted
class_name LootTables

const PASSIVE_ITEM_PATHS := [
	"res://assets/items/passives/iron_heart.tres",
	"res://assets/items/passives/glass_cannon.tres",
	"res://assets/items/passives/quick_trigger.tres",
	"res://assets/items/passives/hollow_point.tres",
	"res://assets/items/passives/steel_nerves.tres",
	"res://assets/items/passives/deadeye_loop.tres",
	"res://assets/items/passives/fragile_core.tres",
	"res://assets/items/passives/blood_rush.tres",
	"res://assets/items/passives/guardian_shell.tres",
	"res://assets/items/passives/blue_fuse.tres",
	"res://assets/items/passives/adamant_spine.tres",
	"res://assets/items/passives/hot_clock.tres",
	"res://assets/items/passives/red_glass.tres",
	"res://assets/items/passives/survival_manual.tres",
	"res://assets/items/passives/heavy_caliber.tres",
	"res://assets/items/passives/silver_vein.tres",
	"res://assets/items/passives/ghost_trigger.tres",
	"res://assets/items/passives/war_drums.tres",
	"res://assets/items/passives/bone_furnace.tres",
	"res://assets/items/passives/eclipse_lens.tres",
]

const ACTIVE_ITEM_PATHS := [
	"res://assets/items/actives/judgement.tres",
	"res://assets/items/actives/red_nova.tres",
	"res://assets/items/actives/time_flask.tres",
	"res://assets/items/actives/aegis_sigil.tres",
	"res://assets/items/actives/berserk_engine.tres",
	"res://assets/items/actives/meteor_bell.tres",
	"res://assets/items/actives/mirror_fan.tres",
	"res://assets/items/actives/chrono_surge.tres",
	"res://assets/items/actives/phase_cloak.tres",
	"res://assets/items/actives/execution_order.tres",
	"res://assets/items/actives/rail_hymn.tres",
	"res://assets/items/actives/blood_pact.tres",
	"res://assets/items/actives/iron_choir.tres",
	"res://assets/items/actives/stasis_mine.tres",
	"res://assets/items/actives/soul_lantern.tres",
]


static func pick_random_passive_item(rng: RandomNumberGenerator) -> ItemData:
	if rng == null:
		return null

	if PASSIVE_ITEM_PATHS.is_empty():
		return null

	var path: String = PASSIVE_ITEM_PATHS[rng.randi_range(0, PASSIVE_ITEM_PATHS.size() - 1)]
	return load(path) as ItemData


static func pick_random_active_item(rng: RandomNumberGenerator) -> ItemData:
	if rng == null:
		return null
	if ACTIVE_ITEM_PATHS.is_empty():
		return null
	var path: String = ACTIVE_ITEM_PATHS[rng.randi_range(0, ACTIVE_ITEM_PATHS.size() - 1)]
	return load(path) as ItemData
