# GameState - 全局游戏状态管理
# 管理局内临时数据和局外全局数据
extends Node

# ─── 局内临时数据（每局重置） ───
var current_hp: float = 100.0
var max_hp: float = 100.0
var current_exp: float = 0.0
var exp_to_next_level: float = 100.0
var player_level: int = 1
var max_player_level: int = 50
var kills: int = 0
var gold_earned: int = 0
var survival_time: float = 0.0
var is_game_over: bool = false
var is_paused: bool = false
var modal_active: bool = false          # 模态面板（升级/结算）显示中，抑制 ESC 暂停菜单（D-2）
var game_seed: String = ""

# 连杀系统
var kill_streak: int = 0                # 当前连杀数
var kill_streak_timer: float = 0.0      # 连杀计时器
var kill_streak_bonus: float = 0.0      # 连杀经验加成倍率
const KILL_STREAK_TIMEOUT: float = 3.0  # 连杀中断时间
const KILL_STREAK_THRESHOLDS: Array = [10, 25, 50, 100, 200]  # 连杀阈值

# 战斗统计
var total_damage_dealt: float = 0.0     # 总伤害输出
var total_damage_taken: float = 0.0     # 总受伤量
var rng := RandomNumberGenerator.new()   # 统一随机源（种子复刻，P2-11）
var is_custom_seed: bool = false
var current_difficulty: String = "normal"
var current_mode: String = "level"     # "level" 关卡模式 / "infinite" 无尽模式
var current_character: String = "mage"
var current_map: String = "grassland"

# 武器/被动状态
var active_weapons: Dictionary = {}       # {weapon_id: level}
var active_passives: Dictionary = {}      # {passive_id: level}
var weapon_affixes: Dictionary = {}       # {weapon_id: [affix_list]}
var max_weapon_slots: int = 6
var super_weapons: Array[String] = []     # 已合成的超武列表
var mega_weapons: Array[String] = []      # 已合成的双重超武列表（Mega-Evolution）
var mega_evolution_available: bool = false # 击杀 BOSS 掉落宝箱可触发融合

# 道具状态
var revive_count: int = 0
var max_revive_count: int = 1
var shield_hp: float = 0.0
var shield_max: float = 0.0

# Buff 计时器
var active_buffs: Dictionary = {}         # {buff_id: remaining_seconds}

# 玩家基础属性（用于伤害计算）
var base_damage: float = 1.0
var damage_bonus: float = 0.0            # 累加增幅
var crit_chance: float = 0.0
var crit_multiplier: float = 1.5
var move_speed: float = 200.0
var base_move_speed: float = 200.0
var pickup_range: float = 60.0
var base_pickup_range: float = 60.0
var armor: float = 0.0
var hp_regen: float = 0.0                # 每秒回血
var lifesteal: float = 0.0               # 吸血比例
var exp_bonus: float = 0.0               # 经验加成
var drop_rate: float = 0.0               # 掉率加成
var shield_passive_lv: int = 0           # 护盾被动等级

# 移速乘区（减速 / 限时加速 buff）
var slow_amount: float = 0.0             # 0~0.6，减速比例
var speed_buff_mult: float = 1.0         # 限时加速 buff 乘数
var damage_buff_mult: float = 1.0        # 限时增伤 buff 乘数
var exp_buff_mult: float = 1.0           # 限时经验翻倍 buff
var invincible_buff: bool = false        # 限时无敌 buff
var cheat_godmode: bool = false          # 金手指无敌（F3 菜单）
var game_speed_mult: float = 1.0         # 游戏速度倍率（1.0正常/2.0双倍）

# 全局词条加成占位（D-4，P1 接入词条时写入；现仅 lifesteal 接入以避免回归）
var affix_move_speed: float = 0.0        # 轻盈：每层 +0.05
var affix_armor: float = 0.0             # 坚毅：每层 +2
var affix_exp_bonus: float = 0.0         # 贪婪：每层 +0.10
var affix_damage_bonus: float = 0.0
var affix_lifesteal: float = 0.0         # 武器吸血词条累加
var char_crit_bonus: float = 0.0         # 角色专属暴击加成（弓手·鹰眼）

const BASE_MAX_HP := 100.0

# Meta 永久强化
var meta_hp_bonus: int = 0
var meta_speed_bonus: int = 0
var meta_exp_bonus: int = 0
var meta_armor_bonus: int = 0
var meta_damage_bonus: int = 0
var meta_magnet_bonus: int = 0
var meta_drop_rate_bonus: int = 0

# ─── 局外全局数据（跨局持久化） ───
var total_gold: int = 0
var total_kills: int = 0
var total_playtime: float = 0.0
var highest_survival: float = 0.0
var total_games: int = 0

# 解锁状态
var unlocked_characters: Array = ["mage"]   # 非 typed：便于从存档 Array 直接赋值
var unlocked_weapons: Array[String] = ["magic_bolt"]
var unlocked_achievements: Array = []   # 非 typed：便于从存档赋值
var unlocked_skins: Array = ["default"]
var selected_skin: String = "default"

const SKINS := {
	"default": {"name": "星蓝", "color": Color(1, 1, 1), "price": 0},
	"gold": {"name": "星金", "color": Color(1.3, 1.15, 0.6), "price": 100},
	"shadow": {"name": "暗影", "color": Color(0.65, 0.55, 0.95), "price": 150},
	"emerald": {"name": "翡翠", "color": Color(0.6, 1.15, 0.7), "price": 150},
	"crimson": {"name": "绯红", "color": Color(1.35, 0.6, 0.6), "price": 200},
}

# 图鉴记录
var bestiary_kills: Dictionary = {}       # {enemy_type: kill_count}
var weapons_used: Dictionary = {}         # {weapon_id: games_used}

# ─── 难度配置 ───
const DIFFICULTY_CONFIG = {
	"easy":    {"hp_mult": 0.7, "speed_mult": 0.8, "count_mult": 0.7, "exp_mult": 1.2, "drop_mult": 1.0},
	"normal":  {"hp_mult": 1.0, "speed_mult": 1.0, "count_mult": 1.0, "exp_mult": 1.0, "drop_mult": 1.0},
	"hard":    {"hp_mult": 1.5, "speed_mult": 1.2, "count_mult": 1.3, "exp_mult": 1.0, "drop_mult": 1.2},
	"nightmare": {"hp_mult": 2.5, "speed_mult": 1.5, "count_mult": 1.6, "exp_mult": 0.8, "drop_mult": 1.5},
	"starfall":  {"hp_mult": 4.0, "speed_mult": 2.0, "count_mult": 2.0, "exp_mult": 0.6, "drop_mult": 2.0},
}

# ─── 组缓存（P-1 优化：减少 get_nodes_in_group 重复遍历） ───
var _group_cache_valid: bool = false
var _cached_enemies: Array[Node] = []
var _cached_players: Array[Node] = []
var _cached_gems: Array[Node] = []


func invalidate_group_cache() -> void:
	_group_cache_valid = false


func get_cached_group(group_name: String) -> Array[Node]:
	if not _group_cache_valid:
		_refresh_group_cache()
	match group_name:
		"enemy":  return _cached_enemies
		"player": return _cached_players
		"gem":    return _cached_gems
		_:        return get_tree().get_nodes_in_group(group_name)


func _refresh_group_cache() -> void:
	_cached_enemies = get_tree().get_nodes_in_group("enemy")
	_cached_players = get_tree().get_nodes_in_group("player")
	_cached_gems = get_tree().get_nodes_in_group("gem")
	_group_cache_valid = true


# ─── 方法 ───

func reset_game_data() -> void:
	#
	current_hp = max_hp
	current_exp = 0.0
	exp_to_next_level = _calculate_exp_for_level(1)
	player_level = 1
	kills = 0
	gold_earned = 0
	survival_time = 0.0
	is_game_over = false
	is_paused = false
	modal_active = false
	active_weapons.clear()
	active_passives.clear()
	weapon_affixes.clear()
	super_weapons.clear()
	mega_weapons.clear()
	mega_evolution_available = false
	revive_count = 0
	shield_hp = 0.0
	shield_max = 0.0
	active_buffs.clear()
	slow_amount = 0.0
	speed_buff_mult = 1.0
	damage_buff_mult = 1.0
	exp_buff_mult = 1.0
	invincible_buff = false
	affix_move_speed = 0.0
	affix_armor = 0.0
	affix_exp_bonus = 0.0
	affix_damage_bonus = 0.0
	affix_lifesteal = 0.0
	char_crit_bonus = 0.0
	kill_streak = 0
	kill_streak_timer = 0.0
	kill_streak_bonus = 0.0
	total_damage_dealt = 0.0
	total_damage_taken = 0.0
	_reset_player_stats()
	current_hp = max_hp


func add_kill_streak() -> void:
	kill_streak += 1
	kill_streak_timer = KILL_STREAK_TIMEOUT
	# 检查是否达到阈值
	for threshold in KILL_STREAK_THRESHOLDS:
		if kill_streak == threshold:
			# 经验加成：10连杀+20%，25连杀+40%，50连杀+60%，100连杀+80%，200连杀+100%
			kill_streak_bonus = 0.2 * (KILL_STREAK_THRESHOLDS.find(threshold) + 1)
			EventBus.streak_reached.emit(kill_streak)
			break


func update_kill_streak(delta: float) -> void:
	if kill_streak_timer > 0:
		kill_streak_timer -= delta
		if kill_streak_timer <= 0:
			kill_streak = 0
			kill_streak_bonus = 0.0

func _reset_player_stats() -> void:
	# 兼容旧调用：统一走 recalc_stats()
	crit_multiplier = 1.5
	hp_regen = 0.0
	shield_passive_lv = 0
	recalc_stats()


# 依据 meta + 被动(active_passives) + 全局词条 统一重算玩家运行时数值。
# 单一数据源（D-1）：被动等级以字典为准，避免各处直接赋值互相覆盖。
func recalc_stats() -> void:
	var sp_lv := int(active_passives.get("speed", 0))
	move_speed = base_move_speed * (1.0 + meta_speed_bonus * 0.02 + sp_lv * 0.15 + affix_move_speed)

	var mag_lv := int(active_passives.get("magnet", 0))
	pickup_range = base_pickup_range * (1.0 + meta_magnet_bonus * 0.05 + mag_lv * 0.30)

	armor = meta_armor_bonus * 1.0 + int(active_passives.get("armor", 0)) * 2.0 + affix_armor
	exp_bonus = meta_exp_bonus * 0.03 + int(active_passives.get("exp_bonus", 0)) * 0.20 + affix_exp_bonus
	damage_bonus = meta_damage_bonus * 0.03 + affix_damage_bonus
	crit_chance = min(0.60, int(active_passives.get("crit", 0)) * 0.05 + char_crit_bonus)
	lifesteal = int(active_passives.get("lifesteal", 0)) * 0.03 + affix_lifesteal
	drop_rate = int(active_passives.get("luck", 0)) * 0.10

	# 最大 HP：上限提升时当前 HP 同步增加（修复 B-3「幻血」）
	var hp_lv := int(active_passives.get("max_hp", 0))
	var new_max := BASE_MAX_HP + meta_hp_bonus * 5.0 + hp_lv * 25.0
	var gain := new_max - max_hp
	max_hp = new_max
	if gain > 0.0:
		current_hp = min(current_hp + gain, max_hp)
	else:
		current_hp = min(current_hp, max_hp)


# 含减速 / 加速 buff 的实际移速（供 Player 每帧读取，修复 B-4）
func effective_move_speed() -> float:
	return move_speed * (1.0 - slow_amount) * speed_buff_mult

func _calculate_exp_for_level(level: int) -> float:
	#
	return 100.0 + pow(float(level), 1.5) * 20.0

func get_difficulty_config() -> Dictionary:
	return DIFFICULTY_CONFIG.get(current_difficulty, DIFFICULTY_CONFIG["normal"])


# 初始化随机种子（空=随机生成；自定义=可复刻），P2-11
func init_rng(seed_str: String) -> void:
	var s := seed_str.strip_edges()
	if s == "":
		rng.randomize()
		game_seed = "%08X" % (int(rng.seed) & 0xFFFFFFFF)
		is_custom_seed = false
	else:
		rng.seed = hash(s)
		game_seed = s.to_upper()
		is_custom_seed = true

func apply_meta_bonuses() -> void:
	recalc_stats()
	current_hp = max_hp


# 角色专属被动（开局应用）
func apply_character_passive() -> void:
	char_crit_bonus = 0.0
	if current_character == "selene":
		char_crit_bonus = 0.10   # 弓手·鹰眼：暴击 +10%（射程见 effective_range_mult）
	elif current_character == "little_fried_egg":
		pass  # 小煎蛋：灼烧持续时间翻倍（见 get_burn_duration_mult）
	recalc_stats()


func get_burn_duration_mult() -> float:
	if current_character == "little_fried_egg":
		return 2.0
	return 1.0


# 攻击范围倍率：法师·星尘共鸣（每 5 级 +5%）/ 弓手·鹰眼（+25%）
func effective_range_mult() -> float:
	if current_character == "selene":
		return 1.25
	elif current_character == "mage":
		return 1.0 + floor(player_level / 5.0) * 0.05
	return 1.0

func get_damage_multiplier() -> float:
	return (1.0 + damage_bonus) * damage_buff_mult


# ─── 有效值计算（Meta 数值分层解离） ───
# 公式: 最终值 = (局外基础 + Meta强化) * (1 + 局内被动加成% + 局内Buff加成%)
# 所有局内逻辑和HUD刷新必须调用这些方法，禁止直接修改基础常量

func get_effective_max_hp() -> float:
	"""计算玩家最终最大 HP"""
	var hp_lv := int(active_passives.get("max_hp", 0))
	return BASE_MAX_HP + meta_hp_bonus * 5.0 + hp_lv * 25.0


func get_effective_move_speed() -> float:
	"""计算玩家最终移速（含减速/加速 buff）"""
	var sp_lv := int(active_passives.get("speed", 0))
	var base := base_move_speed * (1.0 + meta_speed_bonus * 0.02 + sp_lv * 0.15 + affix_move_speed)
	return base * (1.0 - slow_amount) * speed_buff_mult


func get_effective_damage_mult() -> float:
	"""计算最终伤害倍率"""
	return (1.0 + damage_bonus) * damage_buff_mult


func get_effective_exp_rate() -> float:
	"""计算经验获取倍率"""
	return 1.0 + exp_bonus + exp_buff_mult - 1.0  # buff_mult 已是 1.0/2.0


func get_effective_drop_rate() -> float:
	"""计算掉率加成"""
	return 1.0 + drop_rate


func get_effective_pickup_range() -> float:
	"""计算拾取范围"""
	var mag_lv := int(active_passives.get("magnet", 0))
	return base_pickup_range * (1.0 + meta_magnet_bonus * 0.05 + mag_lv * 0.30)


func get_effective_armor() -> float:
	"""计算最终护甲"""
	return meta_armor_bonus * 1.0 + int(active_passives.get("armor", 0)) * 2.0 + affix_armor


func get_effective_crit_chance() -> float:
	"""计算最终暴击率"""
	return min(0.60, int(active_passives.get("crit", 0)) * 0.05 + char_crit_bonus)


func get_effective_lifesteal() -> float:
	"""计算最终吸血比例"""
	return int(active_passives.get("lifesteal", 0)) * 0.03 + affix_lifesteal


func get_effective_range_mult() -> float:
	"""计算攻击范围倍率"""
	return effective_range_mult()  # 已有实现，保持兼容


# ─── 共享 UI 样式（避免每个面板重复创建相同的 StyleBoxFlat） ───
static var _shared_panel_style: StyleBoxFlat = null

func get_shared_panel_style() -> StyleBoxFlat:
	if not _shared_panel_style:
		_shared_panel_style = StyleBoxFlat.new()
		_shared_panel_style.bg_color = Color(0.12, 0.15, 0.20, 0.98)
		_shared_panel_style.border_width_left = 2
		_shared_panel_style.border_width_right = 2
		_shared_panel_style.border_width_top = 2
		_shared_panel_style.border_width_bottom = 2
		_shared_panel_style.border_color = Color(0.4, 0.5, 0.7, 1.0)
		_shared_panel_style.corner_radius_top_left = 12
		_shared_panel_style.corner_radius_top_right = 12
		_shared_panel_style.corner_radius_bottom_left = 12
		_shared_panel_style.corner_radius_bottom_right = 12
		_shared_panel_style.content_margin_left = 24
		_shared_panel_style.content_margin_right = 24
		_shared_panel_style.content_margin_top = 24
		_shared_panel_style.content_margin_bottom = 24
	return _shared_panel_style
