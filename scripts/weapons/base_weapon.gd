# BaseWeapon - 武器基类
# 所有武器继承此类，实现各自的攻击逻辑
class_name BaseWeapon
extends Node2D

## 武器配置
@export var weapon_id: String = ""
@export var weapon_name: String = ""
@export var weapon_icon: Texture2D

# 数值属性
var level: int = 1
var max_level: int = 7
var base_damage: float = 10.0
var attack_speed: float = 1.0       # 次/秒
var attack_timer: float = 0.0
var projectile_speed: float = 400.0
var penetration: int = 0
var range: float = 200.0
var aoe_radius: float = 0.0

# DOT
var dot_enabled: bool = false
var dot_damage: float = 0.0
var dot_duration: float = 3.0
var dot_max_stacks: int = 1

# 暴击
var crit_chance: float = 0.0
var crit_multiplier: float = 1.5

# 特殊
var is_super_weapon: bool = false
var super_weapon_name: String = ""

# 武器词条
var affixes: Array[Dictionary] = []
var lifesteal_local: float = 0.0   # 武器级吸血词条累加（D-4）

# 目标追踪
var target: Node2D = null
var target_range: float = 500.0

var projectile_pool: Node = null


func _ready() -> void:
	_initialize()
	z_index = 5  # 武器在敌人之上渲染


func _process(delta: float) -> void:
	if GameState.is_paused or GameState.is_game_over:
		return

	attack_timer += delta
	if attack_timer >= 1.0 / attack_speed:
		attack_timer = 0.0
		_find_target()
		if target and is_instance_valid(target):
			_attack()


func _initialize() -> void:
	# 子类重写以设置初始属性
	pass


func _find_target() -> void:
	# 在武器范围内找最近的敌人
	var enemies = get_tree().get_nodes_in_group("enemy")
	var nearest_dist = target_range * GameState.effective_range_mult()
	target = null
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			target = enemy


func _attack() -> void:
	# 子类重写以定义攻击行为
	pass


func level_up() -> void:
	# 升级武器，子类重写定义每级参数变化
	if level >= max_level:
		return
	level += 1
	_apply_level_stats()
	_upgrade_flash()


func _upgrade_flash() -> void:
	var t = create_tween()
	t.tween_property(self, "modulate:a", 0.3, 0.1)
	t.tween_property(self, "modulate:a", 1.0, 0.15)
	t.tween_property(self, "modulate:a", 0.3, 0.1)
	t.tween_property(self, "modulate:a", 1.0, 0.15)


func _apply_level_stats() -> void:
	# 子类重写以应用等级属性
	pass


func can_synthesize_super() -> bool:
	return level >= 7  # Lv7 = MAX，可与对应被动 MAX 合成超武（→ Lv8），D-3


func get_damage_with_bonus() -> float:
	var dmg = base_damage * GameState.get_damage_multiplier()
	# 词条加成
	for affix in affixes:
		if affix.get("type") == "damage":
			dmg *= 1.0 + affix.get("value", 0.1)
	# 随机浮动 ±10%
	dmg *= randf_range(0.9, 1.1)
	return dmg


func add_affix(affix: Dictionary) -> void:
	affixes.append(affix)
	var t: String = affix.get("type", "")
	var v: float = affix.get("value", 0.0)
	if affix.get("scope", "weapon") == "global":
		# 全局词条：写入 GameState，由 recalc_stats 生效（D-4）
		match t:
			"move_speed": GameState.affix_move_speed += v
			"exp":        GameState.affix_exp_bonus += v
			"armor":      GameState.affix_armor += v
		GameState.recalc_stats()
	else:
		# 武器级词条（仅作用于本武器实例）
		match t:
			"speed":     attack_speed *= 1.0 + v
			"crit":      crit_chance += v
			"lifesteal": lifesteal_local += v
			# "damage" 由 get_damage_with_bonus() 遍历 affixes 处理


func remove_affixes() -> void:
	# 替换武器时回收全局词条；武器级词条随实例销毁
	for affix in affixes:
		if affix.get("scope", "weapon") == "global":
			var t: String = affix.get("type", "")
			var v: float = affix.get("value", 0.0)
			match t:
				"move_speed": GameState.affix_move_speed -= v
				"exp":        GameState.affix_exp_bonus -= v
				"armor":      GameState.affix_armor -= v
	GameState.recalc_stats()
	affixes.clear()
	crit_chance = 0.0
	lifesteal_local = 0.0


# ─── 暴击 / 吸血结算（D-5：全局基础 + 武器级词条）───

func get_total_crit_chance() -> float:
	return minf(0.60, GameState.crit_chance + crit_chance)


func get_total_crit_mult() -> float:
	return GameState.crit_multiplier


func get_total_lifesteal() -> float:
	return GameState.lifesteal + lifesteal_local


# 从对象池获取投射物（无池则回退到直接实例化），P2-15
func _acquire_projectile() -> Node2D:
	var pool = get_tree().get_first_node_in_group("projectile_pool")
	if pool and pool.has_method("acquire"):
		return pool.acquire()
	var ps = load("res://scenes/weapons/magic_bolt_projectile.tscn")
	if not ps:
		return null
	var p = ps.instantiate()
	get_tree().current_scene.add_child(p)
	return p


func _apply_lifesteal(damage_dealt: float) -> void:
	var ls := get_total_lifesteal()
	if ls <= 0.0:
		return
	var ps := get_tree().get_nodes_in_group("player")
	if ps.size() > 0 and ps[0].has_method("heal"):
		ps[0].heal(damage_dealt * ls)
