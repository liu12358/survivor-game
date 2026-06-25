# SaveSystem - 存档管理 Autoload
# 管理局外数据持久化（金币/解锁/最高纪录/Meta升级）
# v4.1: 哈希校验防篡改 + 字段级 Schema Migration
extends Node

const SAVE_PATH: String = "user://starfall_save.json"
const CHECKSUM_PATH: String = "user://starfall_save.checksum"
const SALT: String = "StarfallSurvivor_星屑割草_v4"  # 盐值防篡改

# ─── 默认存档模板（新增字段在此补充） ───

const DEFAULT_SAVE_DATA: Dictionary = {
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
		"language": "zh",                       # v4.1 新增
	}
}

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

var data: Dictionary = {}

# 存档完整性标记
var _integrity_ok: bool = true
var _tamper_warned: bool = false


func _ready() -> void:
	# 强制设置运行时 locale，确保 tr() 检索英文翻译列
	#（否则中文系统 OS.get_locale()="zh" 找不到匹配列 → 显示原始 key）
	TranslationServer.set_locale("en")
	load_game()


# ─── 哈希校验 ───

func _compute_checksum(raw: String) -> String:
	"""计算存档内容的 SHA256 哈希（盐值混入防篡改）"""
	var salted := raw + SALT
	return salted.sha256_text()


func _verify_integrity(json_str: String) -> bool:
	"""校验存档完整性"""
	if not FileAccess.file_exists(CHECKSUM_PATH):
		return true  # 无校验文件，不阻断（首次保存后才生成）
	var cfile := FileAccess.open(CHECKSUM_PATH, FileAccess.READ)
	if not cfile:
		return true
	var stored := cfile.get_as_text().strip_edges()
	var computed := _compute_checksum(json_str)
	if stored != computed:
		_integrity_ok = false
		printerr("[SaveSystem] 存档校验失败 — 存档可能被篡改！")
		return false
	return true


func _write_checksum(json_str: String) -> void:
	var cfile := FileAccess.open(CHECKSUM_PATH, FileAccess.WRITE)
	if cfile:
		cfile.store_string(_compute_checksum(json_str))


# ─── 加载 / 保存 ───

func load_game() -> void:
	data = DEFAULT_SAVE_DATA.duplicate(true)
	_integrity_ok = true
	_tamper_warned = false

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json_str := file.get_as_text()

	# 完整性校验
	var valid := _verify_integrity(json_str)
	if not valid:
		# 存档被篡改：使用默认数据 + 警告
		if not _tamper_warned:
			printerr("[SaveSystem] 存档被篡改，已重置为默认值")
			_tamper_warned = true
		return

	var json: Variant = JSON.parse_string(json_str)
	if json and json is Dictionary:
		_safe_merge(json)
	else:
		printerr("[SaveSystem] 存档 JSON 解析失败")


func save_game() -> void:
	var json_str := JSON.stringify(data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(json_str)
	_write_checksum(json_str)


func is_tampered() -> bool:
	return not _integrity_ok


# ─── 字段级安全合并（Schema Migration） ───

func _safe_merge(loaded: Dictionary) -> void:
	"""深度合并旧存档到最新模板 — 缺失字段自动默认值补齐"""
	_merge_recursive(data, loaded)


func _merge_recursive(target: Dictionary, source: Dictionary) -> void:
	for key in source:
		if not target.has(key):
			continue  # 忽略未知字段
		var tv = target[key]
		var sv = source[key]
		if typeof(tv) == TYPE_DICTIONARY and typeof(sv) == TYPE_DICTIONARY:
			# 二级深度合并（如 meta_upgrades, settings）
			_merge_recursive(tv, sv)
		elif typeof(tv) == typeof(sv):
			# 类型匹配则覆盖
			target[key] = sv
		else:
			# 类型不匹配：保留默认值，打印警告
			printerr("[SaveSystem] 字段 '%s' 类型不匹配: 期望 %s, 实际 %s" %
				[key, type_string(typeof(tv)), type_string(typeof(sv))])


# 兼容旧代码的 _merge_data
func _merge_data(loaded: Dictionary) -> void:
	_safe_merge(loaded)


# ─── 游戏结果记录 ───

func add_game_result(gold: int, kills: int, survival: float) -> void:
	data["total_gold"] += gold
	data["total_kills"] += kills
	data["total_games"] += 1
	if survival > data["highest_survival"]:
		data["highest_survival"] = survival
	if data["total_kills"] >= 10000:
		unlock_character("selene")
	save_game()


# ─── 角色/成就/皮肤 ───

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


# ─── Meta 永久强化 ───

func apply_meta_to_gamestate() -> void:
	var m = data["meta_upgrades"]
	GameState.meta_hp_bonus = m.get("hp", 0)
	GameState.meta_damage_bonus = m.get("damage", 0)
	GameState.meta_speed_bonus = m.get("speed", 0)
	GameState.meta_magnet_bonus = m.get("magnet", 0)
	GameState.meta_exp_bonus = m.get("exp", 0)
	GameState.meta_armor_bonus = m.get("armor", 0)
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
	if not data["meta_upgrades"].has(upgrade_id):
		data["meta_upgrades"][upgrade_id] = 1
	else:
		data["meta_upgrades"][upgrade_id] += 1
	save_game()
	return true


func get_upgrade_cost(upgrade_id: String) -> int:
	var level = data["meta_upgrades"].get(upgrade_id, 0)
	return 50 + level * 25


func get_upgrade_level(upgrade_id: String) -> int:
	return data["meta_upgrades"].get(upgrade_id, 0)


# ─── 设置 ───

func get_setting(key: String):
	return data["settings"].get(key, null)


func set_setting(key: String, value) -> void:
	if not data.has("settings"):
		data["settings"] = DEFAULT_SAVE_DATA["settings"].duplicate(true)
	data["settings"][key] = value
	save_game()
