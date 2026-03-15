extends RefCounted
class_name ResourceRegistry

const ENEMY_VARIANT_SCENES: Array[PackedScene] = [
	preload("res://scenes/enemies/variants/Enemy_Bruiser.tscn"),
	preload("res://scenes/enemies/variants/Enemy_Fast.tscn"),
	preload("res://scenes/enemies/variants/Enemy_Grunt.tscn"),
]

const ENEMY_PRESET_SCENES: Array[PackedScene] = [
	preload("res://scenes/enemies/presets/EnemyPreset_Backline.tscn"),
	preload("res://scenes/enemies/presets/EnemyPreset_Corners.tscn"),
	preload("res://scenes/enemies/presets/EnemyPreset_Cross.tscn"),
	preload("res://scenes/enemies/presets/EnemyPreset_Diamond.tscn"),
	preload("res://scenes/enemies/presets/EnemyPreset_Duo.tscn"),
	preload("res://scenes/enemies/presets/EnemyPreset_Lanes.tscn"),
	preload("res://scenes/enemies/presets/EnemyPreset_Ring.tscn"),
	preload("res://scenes/enemies/presets/EnemyPreset_Swarm.tscn"),
	preload("res://scenes/enemies/presets/EnemyPreset_Triplet.tscn"),
]

const BOSS_SCENES: Array[PackedScene] = [
	preload("res://scenes/enemies/bosses/Enemy_Boss.tscn"),
]

const DECOR_PRESET_SCENES: Array[PackedScene] = [
	preload("res://scenes/decor/presets/DecorPreset_Barrels.tscn"),
	preload("res://scenes/decor/presets/DecorPreset_BrokenWalls.tscn"),
	preload("res://scenes/decor/presets/DecorPreset_Empty.tscn"),
	preload("res://scenes/decor/presets/DecorPreset_Labyrinth_A.tscn"),
	preload("res://scenes/decor/presets/DecorPreset_Labyrinth_B.tscn"),
	preload("res://scenes/decor/presets/DecorPreset_Labyrinth_C.tscn"),
	preload("res://scenes/decor/presets/DecorPreset_Mixed.tscn"),
	preload("res://scenes/decor/presets/DecorPreset_Rocks.tscn"),
]

const MUSIC_TRACKS: Array[AudioStream] = [
	preload("res://assets/audio/music/1773434215995-b77663e2-2fba-4dbd-bfd6-5b9dd0a4f6e3.mp3"),
	preload("res://assets/audio/music/Chrome_Horizon_Carnage.mp3"),
	preload("res://assets/audio/music/Chrome_Overdrive.mp3"),
	preload("res://assets/audio/music/Neon_Predator.mp3"),
]


static func get_enemy_variant_scenes() -> Array[PackedScene]:
	return ENEMY_VARIANT_SCENES.duplicate()


static func get_enemy_preset_scenes() -> Array[PackedScene]:
	return ENEMY_PRESET_SCENES.duplicate()


static func get_boss_scenes() -> Array[PackedScene]:
	return BOSS_SCENES.duplicate()


static func get_decor_preset_scenes() -> Array[PackedScene]:
	return DECOR_PRESET_SCENES.duplicate()


static func get_music_tracks() -> Array[AudioStream]:
	return MUSIC_TRACKS.duplicate()
