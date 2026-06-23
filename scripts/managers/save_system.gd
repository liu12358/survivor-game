# SaveSystem - 存档管理 Autoload
# 管理局外数据持久化（金币/解锁/最高纪录/Meta升级）
extends Node

const SAVE_PATH: String = "user://starfall_save.json"

const ACHIEVEMENTS := {
	"first_level":   {"name": "第一步", "gold": 10},
	"kill_100":      {"name": "割草机启动", "gold": 10},
	"kill_500":      {"name": "嗡——！", "gold": 25},
	"kill_1000":     {"name": "你确定不是Boss？", "gold": 50},
	"survive_5min":  {"name": "站稳脚跟", "gold": 25},
	"survive_15min": {"name": "星屑守护者", "gold": 100},
	"first_super":   {"name": "真正的力量", "gold": 50},
	"kill_boss":     {"name": "弑君者", "gold": 100},
	"unlock_argo":   {"name": "剑道即星道", "gold": 50},
	"unlock_selene": {"name": "百步穿杨", "gold": 50},
}

var data: Dictionary = {
	"total_gold": 0,
	"total_kills": 0,
	"total_games": 0,
	"highest_survival": 0.0,
	"unlocked_characters": ["mage"],
	"unlocked_achievements": [],
	"bestiary": {},
	"unlocked_skins": ["default"],
	"selected_skin": "default",
	"meta_upgrades": {
		"hp": 0,
		"damage": 0,
		"speed": 0,
		"magnet": 0,
		"exp": 0,
		"armor": 0,
	},
	"settings": {
		"master_volume": 0.8,
		"screen_shake": true,
		"particles": true,
		"damage_numbers": true,
		"fullscreen": false,
	}
}


func _ready() -> void:
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json = JSON.parse_string(file.get_as_text())
	if json and json is Dictionary:
		_merge_data(json)


func save_game() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(data))


func _merge_data(loaded: Dictionary) -> void:
	for key in loaded:
		if data.has(key):
			if typeof(data[key]) == TYPE_DICTIONARY and typeof(loaded[key]) == TYPE_DICTIONARY:
				for sub in loaded[key]:
					data[key][sub] = loaded[key][sub]
			else:
				data[key] = loaded[key]


func add_game_result(gold: int, kills: int, survival: float) -> void:
	data["total_gold"] += gold
	data["total_kills"] += kills
	data["total_games"] += 1
	if survival > data["highest_survival"]:
		data["highest_survival"] = survival
	# 累计击杀 10000 解锁弓手
	if data["total_kills"] >= 10000:
		unlock_character("selene")
	save_game()


func unlock_character(id: String) -> void:
	if not data.has("unlocked_characters"):
		data["unlocked_characters"] = ["mage"]
	if not data["unlocked_characters"].has(id):
		data["unlocked_characters"].append(id)
		GameState.unlocked_characters = data["unlocked_characters"].duplicate()
		save_game()
		var ach := "unlock_" + id
		if unlock_achievement(ach):
			EventBus.achievement_unlocked.emit(ach)


func unlock_achievement(id: String) -> bool:
	if not data.has("unlocked_achievements"):
		data["unlocked_achievements"] = []
	if data["unlocked_achievements"].has(id):
		return false
	data["unlocked_achievements"].append(id)
	data["total_gold"] += int(ACHIEVEMENTS.get(id, {}).get("gold", 0))
	GameState.unlocked_achievements = data["unlocked_achievements"].duplicate()
	save_game()
	return true


# 记录怪物击杀（图鉴），不每次写盘，结算时随 add_game_result 持久化
func record_kill(enemy_type: String) -> void:
	if not data.has("bestiary"):
		data["bestiary"] = {}
	data["bestiary"][enemy_type] = int(data["bestiary"].get(enemy_type, 0)) + 1


func buy_skin(id: String) -> bool:
	if data["unlocked_skins"].has(id):
		return false
	var price = int(GameState.SKINS.get(id, {}).get("price", 0))
	if data["total_gold"] < price:
		return false
	data["total_gold"] -= price
	data["unlocked_skins"].append(id)
	GameState.unlocked_skins = data["unlocked_skins"].duplicate()
	select_skin(id)
	return true


func select_skin(id: String) -> void:
	if data["unlocked_skins"].has(id):
		data["selected_skin"] = id
		GameState.selected_skin = id
		save_game()


func apply_meta_to_gamestate() -> void:
	var m = data["meta_upgrades"]
	GameState.meta_hp_bonus = m["hp"]
	GameState.meta_damage_bonus = m["damage"]
	GameState.meta_speed_bonus = m["speed"]
	GameState.meta_magnet_bonus = m["magnet"]
	GameState.meta_exp_bonus = m["exp"]
	GameState.meta_armor_bonus = m["armor"]
	if data.has("unlocked_characters"):
		GameState.unlocked_characters = data["unlocked_characters"].duplicate()
	if data.has("unlocked_achievements"):
		GameState.unlocked_achievements = data["unlocked_achievements"].duplicate()
	if data.has("unlocked_skins"):
		GameState.unlocked_skins = data["unlocked_skins"].duplicate()
	GameState.selected_skin = data.get("selected_skin", "default")


func buy_upgrade(upgrade_id: String) -> bool:
	var cost = get_upgrade_cost(upgrade_id)
	if cost > data["total_gold"]:
		return false
	data["total_gold"] -= cost
	data["meta_upgrades"][upgrade_id] += 1
	save_game()
	return true


func get_upgrade_cost(upgrade_id: String) -> int:
	var level = data["meta_upgrades"].get(upgrade_id, 0)
	return 50 + level * 25


func get_upgrade_level(upgrade_id: String) -> int:
	return data["meta_upgrades"].get(upgrade_id, 0)


func get_setting(key: String):
	return data["settings"].get(key, null)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	save_game()
