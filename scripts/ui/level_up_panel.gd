# LevelUpPanel - 升级选卡面板
# 升级时弹出3选1面板，支持键盘1/2/3和鼠标点击选择
# v2: 权重池+保底机制+武器替换弹窗+稀有词条
extends CanvasLayer

var _overlay: ColorRect
var _title_label: Label
var _card_container: HBoxContainer
var _cards: Array[Dictionary] = []
var _replace_overlay: Control = null
var _hide_tween: Tween = null

# 保底追踪
var _consecutive_non_weapon: int = 0   # 连续未出武器次数
var _consecutive_non_passive: int = 0  # 连续未出被动次数

# 词条追踪
var _affix_offer_count: int = 0        # 已出现的词条次数
var _affix_cooldown: int = 0           # 词条冷却（至少隔N次）

# ─── 被动技能定义 ───
const PASSIVES = {
	"max_hp":     {"name": "生命强化", "icon": "❤️", "desc": "最大HP +25",     "max_lv": 5},
	"speed":      {"name": "疾步",     "icon": "👟", "desc": "移速 +15%",      "max_lv": 5},
	"magnet":     {"name": "磁铁",     "icon": "🧲", "desc": "拾取范围 +30%",   "max_lv": 5},
	"armor":      {"name": "铁壁",     "icon": "🛡️", "desc": "减伤 +2",        "max_lv": 5},
	"exp_bonus":  {"name": "经验加成", "icon": "💎", "desc": "经验获取 +20%",   "max_lv": 5},
	"crit":       {"name": "锐眼",     "icon": "🎯", "desc": "暴击率 +5%",     "max_lv": 5},
	"lifesteal":  {"name": "吸血",     "icon": "🩸", "desc": "吸血 +3%",       "max_lv": 5},
	"luck":       {"name": "幸运",     "icon": "🍀", "desc": "掉率 +10%",      "max_lv": 5},
	"shield_max": {"name": "护盾",     "icon": "🔰", "desc": "最大护盾 +10%",   "max_lv": 5},
}

# ─── 武器名称映射 ───
const WEAPON_INFO = {
	"magic_bolt":      {"name": "魔法弹", "icon": "🔮"},
	"fire_ring":        {"name": "烈焰环", "icon": "🔥"},
	"lightning_chain":  {"name": "闪电链", "icon": "⚡"},
	"ice_storm":        {"name": "冰晶风暴", "icon": "❄️"},
	"holy_spear":       {"name": "圣光之矛", "icon": "🏹"},
	"poison_cloud":     {"name": "毒雾", "icon": "☠️"},
	"sword_orbit":      {"name": "环绕剑刃", "icon": "⚔️"},
	"piercing_arrow":   {"name": "穿透箭", "icon": "🎯"},
	"lava_zone":        {"name": "岩浆", "icon": "🌋"},
}
const ALL_WEAPONS = ["magic_bolt", "fire_ring", "lightning_chain", "ice_storm", "holy_spear", "poison_cloud", "lava_zone"]

# ─── 词条定义 ───
# 普通词条 15%概率
const COMMON_AFFIXES = [
	{"name": "锐利", "type": "damage", "scope": "weapon", "value": 0.10, "desc": "该武器伤害 +10%"},
	{"name": "迅捷", "type": "speed",  "scope": "weapon", "value": 0.10, "desc": "该武器攻速 +10%"},
]
# 稀有词条 5%概率（武器级）
const RARE_AFFIXES = [
	{"name": "吸血之触", "type": "lifesteal", "scope": "weapon", "value": 0.03, "desc": "该武器获得3%吸血"},
	{"name": "致命一击", "type": "crit",      "scope": "weapon", "value": 0.08, "desc": "该武器暴击率 +8%"},
]
# 史诗词条 2%概率（全局，不限武器 —— D-4）
const EPIC_AFFIXES = [
	{"name": "轻盈", "type": "move_speed", "scope": "global", "value": 0.05, "desc": "全局移速 +5%（史诗）"},
	{"name": "贪婪", "type": "exp",        "scope": "global", "value": 0.10, "desc": "全局经验 +10%（史诗）"},
	{"name": "坚毅", "type": "armor",      "scope": "global", "value": 2.0,  "desc": "全局减伤 +2（史诗）"},
]

# 置换词条 3% 概率：「有得有失」高级词条
const INVERSE_AFFIXES = [
	{"name": "孤注一掷", "type": "inverse_all_or_nothing", "scope": "weapon", "value": 0.0,
	 "desc": "该武器伤害 +50% / 攻速 -20%", "pos": {"type": "damage", "value": 0.50},
	 "neg": {"type": "speed", "value": -0.20}},
	{"name": "血色契约", "type": "inverse_blood_pact", "scope": "global", "value": 0.0,
	 "desc": "全局吸血 +5% / 最大生命值 -20%", "pos": {"type": "lifesteal", "value": 0.05},
	 "neg": {"type": "max_hp_pct", "value": -0.20}},
]

# ─── 类别权重 ───
const WEIGHT_WEAPON_UPGRADE = 60
const WEIGHT_NEW_WEAPON = 25
const WEIGHT_PASSIVE = 15


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时仍可选卡（D-2）
	_create_ui()
	visible = false
	EventBus.player_level_up.connect(_on_level_up)
	# 监听升级信号以触发超武合成检查（涵盖本面板选卡与作弊菜单升级）
	EventBus.upgrade_selected.connect(_on_upgrade_selected_synthesis)


func reset_for_new_game() -> void:
	"""新游戏开始时重置追踪状态"""
	_consecutive_non_weapon = 0
	_consecutive_non_passive = 0
	_affix_offer_count = 0
	_affix_cooldown = 0
	_hide_replace_overlay()


# ─── UI 构建 ───

func _create_ui() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(700, 400)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "⭐ 升级！选择一个强化"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)

	_card_container = HBoxContainer.new()
	_card_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_container.add_theme_constant_override("separation", 20)
	vbox.add_child(_card_container)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer2)

	var hint = Label.new()
	hint.text = "按 1/2/3 键或点击选择"
	hint.add_theme_font_size_override("font_size", 14)
	hint.modulate = Color(0.7, 0.7, 0.7)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)


# ─── 入口 ───

func _on_level_up(_level: int) -> void:
	if GameState.player_level >= GameState.max_player_level:
		return  # 50级后停止升级
	_generate_choices()
	_show_panel()


# ─── 权重选择核心 ───

func _get_pool_by_category() -> Dictionary:
	"""返回三种类别的完整候选池"""
	var pools := {
		"weapon_upgrade": [],
		"new_weapon": [],
		"passive": [],
	}

	# 武器升级
	for wid in GameState.active_weapons:
		# Mega 武器靠 Timer 实现效果，无 BaseWeapon 实例，不可常规升级
		if GameState.mega_weapons.has(wid):
			continue
		var lv = GameState.active_weapons[wid]
		var wi = WEAPON_INFO.get(wid, {"name": wid, "icon": "⚔️"})
		var max_lv = 7
		if GameState.super_weapons.has(wid):
			max_lv = 8  # 超武可继续升级到8
		if lv < max_lv:
			pools["weapon_upgrade"].append({
				"type": "weapon_upgrade",
				"id": wid,
				"title": "%s %s Lv.%d → %d" % [wi["icon"], wi["name"], lv, lv + 1],
				"desc": _get_weapon_upgrade_desc(wid, lv + 1),
				"icon": wi["icon"]
			})

	# 新武器（未拥有的，且槽位有空或可替换）
	for wid in ALL_WEAPONS:
		if not GameState.active_weapons.has(wid):
			var wi = WEAPON_INFO.get(wid, {"name": wid, "icon": "⚔️"})
			pools["new_weapon"].append({
				"type": "new_weapon",
				"id": wid,
				"title": "%s 获取%s" % [wi["icon"], wi["name"]],
				"desc": "获得新武器，从Lv.1开始",
				"icon": wi["icon"]
			})

	# 被动
	for pid in PASSIVES:
		var cur_lv = GameState.active_passives.get(pid, 0)
		if cur_lv < PASSIVES[pid]["max_lv"]:
			var p = PASSIVES[pid]
			pools["passive"].append({
				"type": "passive",
				"id": pid,
				"title": "%s %s Lv.%d → %d" % [p["icon"], p["name"], cur_lv, cur_lv + 1],
				"desc": p["desc"],
				"icon": p["icon"]
			})

	return pools


func _pick_category(pools: Dictionary) -> String:
	"""根据权重和保底选择类别"""
	var has_upgrade = pools["weapon_upgrade"].size() > 0
	var has_new = pools["new_weapon"].size() > 0
	var has_passive = pools["passive"].size() > 0

	# 保底：连续3次无武器 → 必出武器
	if _consecutive_non_weapon >= 3 and (has_upgrade or has_new):
		return "weapon_force"  # 标记强制武器（计数器在 _generate_choices 末尾重置）

	# 保底：连续5次无被动 → 必出被动
	if _consecutive_non_passive >= 5 and has_passive:
		_consecutive_non_passive = 0
		return "passive"

	# 计算权重
	var w_upgrade = WEIGHT_WEAPON_UPGRADE if has_upgrade else 0
	var w_new = WEIGHT_NEW_WEAPON if has_new else 0
	# 武器≤2把时新武器权重翻倍
	if GameState.active_weapons.size() <= 2 and has_new:
		w_new *= 2
	var w_passive = WEIGHT_PASSIVE if has_passive else 0

	# 如果只有一种可选，直接返回
	var active_count = (1 if w_upgrade > 0 else 0) + (1 if w_new > 0 else 0) + (1 if w_passive > 0 else 0)
	if active_count == 1:
		if w_upgrade > 0: return "weapon_upgrade"
		if w_new > 0: return "new_weapon"
		return "passive"

	var total = w_upgrade + w_new + w_passive
	if total <= 0:
		return "skip"

	var roll = GameState.rng.randf() * total
	if roll < w_upgrade:
		return "weapon_upgrade"
	elif roll < w_upgrade + w_new:
		return "new_weapon"
	return "passive"


func _pick_from_category(pools: Dictionary, category: String) -> Dictionary:
	"""从指定类别中随机选一个"""
	if category == "weapon_force":
		# 强制武器：武器升级和新武器合并池
		var merged = pools["weapon_upgrade"] + pools["new_weapon"]
		if merged.size() > 0:
			var pick = merged[GameState.rng.randi() % merged.size()]
			return pick
		category = "passive"  # fallback

	var pool = pools.get(category, [])
	if pool.size() == 0:
		# fallback: 尝试 passive
		if pools["passive"].size() > 0:
			return pools["passive"][GameState.rng.randi() % pools["passive"].size()]
		if pools["weapon_upgrade"].size() > 0:
			return pools["weapon_upgrade"][GameState.rng.randi() % pools["weapon_upgrade"].size()]
		if pools["new_weapon"].size() > 0:
			return pools["new_weapon"][GameState.rng.randi() % pools["new_weapon"].size()]
		# 什么都没有——经验
		return {"type": "skip", "id": "skip", "title": "⭐ 经验加成", "desc": "获得额外经验值", "icon": "✨"}

	return pool[GameState.rng.randi() % pool.size()]


func _roll_affix_for_card(card: Dictionary) -> Dictionary:
	"""为卡片roll稀有词条"""
	if card["type"] != "weapon_upgrade":
		return card  # 仅武器升级可带词条

	# 冷却检查：出现词条后至少隔2次
	_affix_cooldown -= 1
	if _affix_cooldown > 0:
		return card

	var roll = GameState.rng.randf()
	var affix: Dictionary = {}

	if roll < 0.02:  # 2% 史诗
		affix = EPIC_AFFIXES[GameState.rng.randi() % EPIC_AFFIXES.size()].duplicate(true)
		card["title"] = card["title"] + " ✦"
	elif roll < 0.05:  # 3% 置换（有得有失）
		affix = INVERSE_AFFIXES[GameState.rng.randi() % INVERSE_AFFIXES.size()].duplicate(true)
		card["title"] = card["title"] + " ⚖️"
	elif roll < 0.10:  # 5% 稀有
		affix = RARE_AFFIXES[GameState.rng.randi() % RARE_AFFIXES.size()].duplicate(true)
		card["title"] = card["title"] + " ★"
	elif roll < 0.22:  # 15% 普通
		affix = COMMON_AFFIXES[GameState.rng.randi() % COMMON_AFFIXES.size()].duplicate(true)
		card["title"] = card["title"] + " ☆"

	if not affix.is_empty():
		card["affix"] = affix
		card["desc"] = card["desc"] + "\n" + affix.get("desc", "")
		_affix_cooldown = 2  # 冷却2次
		_affix_offer_count += 1

	return card


func _generate_choices() -> void:
	_cards.clear()
	var pools = _get_pool_by_category()

	# 生成3张卡，去重（同一武器/被动不重复出现）
	var used_ids: Array[String] = []

	for i in range(3):
		var category = _pick_category(pools)
		var card = _pick_from_category(pools, category)

		# 去重
		var attempts = 0
		while card.get("id") in used_ids and attempts < 10:
			card = _pick_from_category(pools, category)
			attempts += 1
			if attempts > 8:
				# 换类别试试
				var cats = ["weapon_upgrade", "new_weapon", "passive"]
				cats.shuffle()
				for alt_cat in cats:
					if pools[alt_cat].size() > 0:
						card = _pick_from_category(pools, alt_cat)
						if card.get("id") not in used_ids:
							category = alt_cat
							break
				break

		if card.get("type") != "skip":
			used_ids.append(card.get("id", ""))

		# roll词条
		card = _roll_affix_for_card(card)

		_cards.append(card)

	# 更新保底追踪
	var has_weapon_card = false
	var has_passive_card = false
	for c in _cards:
		if c["type"] in ["weapon_upgrade", "new_weapon"]:
			has_weapon_card = true
		if c["type"] == "passive":
			has_passive_card = true

	if has_weapon_card:
		_consecutive_non_weapon = 0
	else:
		_consecutive_non_weapon += 1

	if has_passive_card:
		_consecutive_non_passive = 0
	else:
		_consecutive_non_passive += 1


# ─── 显示卡片 ───

func _show_panel() -> void:
	# 清除旧卡片
	for child in _card_container.get_children():
		child.queue_free()

	# 创建新卡片
	for i in range(_cards.size()):
		var card = _create_card(_cards[i], i + 1)
		card.pivot_offset = card.custom_minimum_size / 2
		card.scale = Vector2.ZERO
		_card_container.add_child(card)
		var t = create_tween()
		t.tween_interval(0.08 * i)
		t.tween_property(card, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	visible = true
	get_tree().paused = true
	GameState.is_paused = true
	GameState.modal_active = true

	# 升级面板弹出音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_levelup()


func _create_card(data: Dictionary, index: int) -> Control:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(200, 280)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var is_rare = data.get("affix", {}).size() > 0

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.18, 0.25, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.7, 0.55, 0.1, 1) if is_rare else Color(0.4, 0.5, 0.7, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# 序号
	var num_label = Label.new()
	num_label.text = "%d" % index
	num_label.add_theme_font_size_override("font_size", 14)
	num_label.modulate = Color(0.6, 0.7, 0.9)
	num_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(num_label)

	# 图标
	var icon_label = Label.new()
	icon_label.text = data.get("icon", "⭐")
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	# 标题
	var title = Label.new()
	title.text = data.get("title", "???")
	title.add_theme_font_size_override("font_size", 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(170, 0)
	if is_rare:
		title.modulate = Color(1.0, 0.84, 0.0)
	vbox.add_child(title)

	# 描述
	var desc = Label.new()
	desc.text = data.get("desc", "")
	desc.add_theme_font_size_override("font_size", 13)
	desc.modulate = Color(0.7, 0.8, 0.9)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(170, 0)
	vbox.add_child(desc)

	# 稀有度标签
	if is_rare:
		var rare_label = Label.new()
		rare_label.text = "★ 稀有"
		rare_label.add_theme_font_size_override("font_size", 11)
		rare_label.modulate = Color(1.0, 0.84, 0.0)
		rare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(rare_label)
	elif data.get("type") == "new_weapon":
		var new_label = Label.new()
		new_label.text = "✦ 新武器"
		new_label.add_theme_font_size_override("font_size", 11)
		new_label.modulate = Color(0.4, 0.8, 1.0)
		new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(new_label)
	elif data.get("type") == "weapon_upgrade":
		var wid: String = data.get("id", "")
		var current_level: int = int(GameState.active_weapons.get(wid, 1))
		if current_level >= 7:
			var max_label = Label.new()
			max_label.text = "⬆ MAX"
			max_label.add_theme_font_size_override("font_size", 11)
			max_label.modulate = Color(0.9, 0.6, 0.2)
			max_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(max_label)

	# hover 效果
	panel.mouse_entered.connect(func():
		style.border_color = Color(0.9, 0.75, 0.2, 1) if is_rare else Color(0.6, 0.8, 1.0, 1)
		style.bg_color = Color(0.2, 0.25, 0.35, 0.98)
		style.shadow_size = 4
		create_tween().tween_property(panel, "scale", Vector2(1.05, 1.05), 0.1)
	)
	panel.mouse_exited.connect(func():
		style.border_color = Color(0.7, 0.55, 0.1, 1) if is_rare else Color(0.4, 0.5, 0.7, 1)
		style.bg_color = Color(0.15, 0.18, 0.25, 0.95)
		style.shadow_size = 0
		create_tween().tween_property(panel, "scale", Vector2.ONE, 0.1)
	)

	panel.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select_card(index - 1)
	)

	return panel


# ─── 输入处理 ───

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# 武器替换弹窗显示中，不处理普通选择
	if _replace_overlay and _replace_overlay.visible:
		return

	if event.is_action_pressed("select_1") and _cards.size() >= 1:
		_select_card(0)
	elif event.is_action_pressed("select_2") and _cards.size() >= 2:
		_select_card(1)
	elif event.is_action_pressed("select_3") and _cards.size() >= 3:
		_select_card(2)


# ─── 选择处理 ───

func _select_card(index: int) -> void:
	if index < 0 or index >= _cards.size():
		return

	# 选卡确认音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_ui_click()

	var card = _cards[index]

	# 新武器 + 满槽 → 弹出替换弹窗
	if card["type"] == "new_weapon" and GameState.active_weapons.size() >= GameState.max_weapon_slots:
		_show_weapon_replace_dialog(card)
		return

	_apply_choice(card)
	_hide_panel()


func _apply_choice(data: Dictionary) -> void:
	match data["type"]:
		"weapon_upgrade":
			var wid = data["id"]
			GameState.active_weapons[wid] += 1
			var player = get_tree().get_nodes_in_group("player")
			if player.size() > 0:
				for child in player[0].get_children():
					if child is BaseWeapon and child.weapon_id == wid:
						child.level_up()
						# 应用词条
						if data.has("affix") and data["affix"] is Dictionary:
							child.add_affix(data["affix"])
			SaveSystem.record_weapon_usage(wid)
		"new_weapon":
			var wid = data["id"]
			GameState.active_weapons[wid] = 1
			var player = get_tree().get_nodes_in_group("player")
			if player.size() > 0:
				_add_weapon_to_player(player[0], wid)
			SaveSystem.record_weapon_usage(wid)
		"passive":
			var pid = data["id"]
			var cur_lv = GameState.active_passives.get(pid, 0)
			GameState.active_passives[pid] = cur_lv + 1
			_apply_passive(pid)
		"skip":
			# 通过 EventBus 走 HUD 经验处理，确保 UI 刷新与升级检测一致
			EventBus.exp_collected.emit(int(GameState.exp_to_next_level * 0.3))

	EventBus.upgrade_selected.emit(data["id"])
	# 超武合成检查由 upgrade_selected 信号统一触发（_on_upgrade_selected_synthesis）


func _on_upgrade_selected_synthesis(_id: String) -> void:
	# 由 upgrade_selected 信号触发，涵盖选卡与作弊菜单升级路径
	_check_super_weapon_synthesis()


# ─── 武器替换弹窗 ───

func _show_weapon_replace_dialog(new_weapon_card: Dictionary) -> void:
	_release_replace_overlay()

	_replace_overlay = ColorRect.new()
	_replace_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_replace_overlay.color = Color(0, 0, 0, 0.85)
	_replace_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_replace_overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_replace_overlay.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "🔁 武器槽已满，替换一把武器？"
	title.add_theme_font_size_override("font_size", 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var new_label = Label.new()
	var wi = WEAPON_INFO.get(new_weapon_card["id"], {"name": new_weapon_card["id"], "icon": "⚔️"})
	new_label.text = "新武器：%s %s" % [wi["icon"], wi["name"]]
	new_label.add_theme_font_size_override("font_size", 18)
	new_label.modulate = Color(0.3, 1.0, 0.3)
	new_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(new_label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var sub_label = Label.new()
	sub_label.text = "选择要替换的武器（🔒 超武不可替换）："
	sub_label.add_theme_font_size_override("font_size", 14)
	sub_label.modulate = Color(0.7, 0.7, 0.7)
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_label)

	# 武器列表
	var weapons_vbox = VBoxContainer.new()
	weapons_vbox.add_theme_constant_override("separation", 8)
	vbox.add_child(weapons_vbox)

	for wid in GameState.active_weapons:
		var lv = GameState.active_weapons[wid]
		var winfo = WEAPON_INFO.get(wid, {"name": wid, "icon": "⚔️"})
		var is_super = GameState.super_weapons.has(wid)

		var row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		weapons_vbox.add_child(row)

		var info_label = Label.new()
		info_label.text = "%s %s Lv.%d" % [winfo["icon"], winfo["name"], lv]
		info_label.add_theme_font_size_override("font_size", 16)
		if is_super:
			info_label.text += " 🔒"
			info_label.modulate = Color(1.0, 0.84, 0.0)
		info_label.custom_minimum_size = Vector2(200, 0)
		row.add_child(info_label)

		var btn = Button.new()
		if is_super:
			btn.text = "已锁定"
			btn.disabled = true
			btn.modulate = Color(0.4, 0.4, 0.4)
		else:
			btn.text = "替换"
			btn.add_theme_font_size_override("font_size", 14)
			btn.custom_minimum_size = Vector2(80, 36)
			var _wid = wid  # 捕获变量
			btn.pressed.connect(func():
				_replace_weapon(_wid, new_weapon_card)
			)
		row.add_child(btn)

	# 取消按钮
	var cancel_spacer = Control.new()
	cancel_spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(cancel_spacer)

	var cancel_btn = Button.new()
	cancel_btn.text = "取消（获得经验补偿）"
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.custom_minimum_size = Vector2(180, 40)
	cancel_btn.pressed.connect(func():
		EventBus.exp_collected.emit(int(GameState.exp_to_next_level * 0.3))
		_replace_cancel()
	)
	vbox.add_child(cancel_btn)

	# 阻止点击穿透
	_replace_overlay.mouse_filter = Control.MOUSE_FILTER_STOP


func _replace_weapon(old_id: String, new_card: Dictionary) -> void:
	"""替换武器：移除旧武器，添加新武器"""
	# 移除旧武器的词条
	var player = get_tree().get_nodes_in_group("player")
	if player.size() > 0:
		for child in player[0].get_children():
			if child is BaseWeapon and child.weapon_id == old_id:
				child.remove_affixes()
				child.queue_free()
				break

	# 从状态中移除
	GameState.active_weapons.erase(old_id)

	# 添加新武器
	GameState.active_weapons[new_card["id"]] = 1
	if player.size() > 0:
		_add_weapon_to_player(player[0], new_card["id"])

	EventBus.weapon_replaced.emit(old_id, new_card["id"])
	EventBus.upgrade_selected.emit(new_card["id"])
	_release_replace_overlay()
	_hide_panel()


func _replace_cancel() -> void:
	_release_replace_overlay()
	_hide_panel()


func _release_replace_overlay() -> void:
	if _replace_overlay and is_instance_valid(_replace_overlay):
		_replace_overlay.queue_free()
	_replace_overlay = null


func _hide_replace_overlay() -> void:
	if _replace_overlay and _replace_overlay.visible:
		_release_replace_overlay()


# ─── 武器/被动工具 ───

func _add_weapon_to_player(p: Node, wid: String) -> void:
	var scene_path = ""
	match wid:
		"magic_bolt": scene_path = "res://scenes/weapons/magic_bolt.tscn"
		"fire_ring": scene_path = "res://scenes/weapons/fire_ring.tscn"
		"lightning_chain": scene_path = "res://scenes/weapons/lightning_chain.tscn"
		"ice_storm": scene_path = "res://scenes/weapons/ice_storm.tscn"
		"holy_spear": scene_path = "res://scenes/weapons/holy_spear.tscn"
		"poison_cloud": scene_path = "res://scenes/weapons/poison_cloud.tscn"
		"sword_orbit": scene_path = "res://scenes/weapons/sword_orbit.tscn"
		"piercing_arrow": scene_path = "res://scenes/weapons/piercing_arrow.tscn"
		"lava_zone": scene_path = "res://scenes/weapons/lava_zone.tscn"
	if scene_path != "" and ResourceLoader.exists(scene_path):
		var ws = load(scene_path)
		var w = ws.instantiate()
		p.add_child(w)


func _apply_passive(pid: String) -> void:
	# 被动等级已写入 active_passives，统一由 GameState 重算（单一数据源 D-1）
	GameState.recalc_stats()
	match pid:
		"magnet":
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0 and players[0].has_method("_update_pickup_range"):
				players[0]._update_pickup_range()
		"shield_max":
			var lv = int(GameState.active_passives.get("shield_max", 0))
			GameState.shield_passive_lv = lv
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				var shield_amount = GameState.max_hp * lv * 0.10
				if players[0].has_method("add_shield"):
					players[0].shield_health = max(players[0].shield_health, shield_amount)


func _check_super_weapon_synthesis() -> void:
	# 魔法弹MAX(Lv7) + 经验加成MAX(Lv5) → 星爆
	if GameState.active_weapons.get("magic_bolt", 0) >= 7 and GameState.active_passives.get("exp_bonus", 0) >= 5:
		if not GameState.super_weapons.has("magic_bolt"):
			_synthesize_super("magic_bolt", "星爆")
	# 烈焰环MAX + 铁壁MAX → 炼狱
	if GameState.active_weapons.get("fire_ring", 0) >= 7 and GameState.active_passives.get("armor", 0) >= 5:
		if not GameState.super_weapons.has("fire_ring"):
			_synthesize_super("fire_ring", "炼狱")
	# 闪电链MAX + 疾步MAX → 雷神之怒
	if GameState.active_weapons.get("lightning_chain", 0) >= 7 and GameState.active_passives.get("speed", 0) >= 5:
		if not GameState.super_weapons.has("lightning_chain"):
			_synthesize_super("lightning_chain", "雷神之怒")
	# 冰晶风暴MAX + 生命强化MAX → 冰河纪元
	if GameState.active_weapons.get("ice_storm", 0) >= 7 and GameState.active_passives.get("max_hp", 0) >= 5:
		if not GameState.super_weapons.has("ice_storm"):
			_synthesize_super("ice_storm", "冰河纪元")
	# 圣光之矛MAX + 铁壁MAX → 圣裁
	if GameState.active_weapons.get("holy_spear", 0) >= 7 and GameState.active_passives.get("armor", 0) >= 5:
		if not GameState.super_weapons.has("holy_spear"):
			_synthesize_super("holy_spear", "圣裁")
	# 毒雾MAX + 幸运MAX → 瘟疫
	if GameState.active_weapons.get("poison_cloud", 0) >= 7 and GameState.active_passives.get("luck", 0) >= 5:
		if not GameState.super_weapons.has("poison_cloud"):
			_synthesize_super("poison_cloud", "瘟疫")
	# 岩浆MAX + 护盾MAX → 熔岩之心
	if GameState.active_weapons.get("lava_zone", 0) >= 7 and GameState.active_passives.get("shield_max", 0) >= 5:
		if not GameState.super_weapons.has("lava_zone"):
			_synthesize_super("lava_zone", "熔岩之心")

	# Mega-Evolution：击杀 BOSS 且可用时检查
	_check_mega_evolution()


# ─── 双重超武合成（Mega-Evolution） ───

const MEGA_RECIPES = {
	"mega_inferno_glacier": {
		"name": "🌀 湮灭冰火环",
		"requires": ["fire_ring", "ice_storm"],
		"desc": "冷热交替触发碎裂，造成 200% 真实伤害",
	},
	# 后续可按此格式扩展更多配方
}

func _check_mega_evolution() -> void:
	if not GameState.mega_evolution_available:
		return
	for rid in MEGA_RECIPES:
		if rid in GameState.mega_weapons:
			continue
		var r = MEGA_RECIPES[rid]
		var has_all := true
		for wid in r["requires"]:
			if not GameState.super_weapons.has(wid):
				has_all = false
				break
		if has_all:
			_synthesize_mega(rid, r)
			GameState.mega_evolution_available = false
			return


func _synthesize_mega(rid: String, recipe: Dictionary) -> void:
	# 移除两个基础超武
	for wid in recipe["requires"]:
		GameState.super_weapons.erase(wid)
		GameState.active_weapons.erase(wid)
		var pl = get_tree().get_nodes_in_group("player")
		if pl.size() > 0:
			for child in pl[0].get_children():
				if child is BaseWeapon and child.weapon_id == wid:
					child.remove_affixes()
					child.queue_free()
					break

	# 注册 Mega 武器
	GameState.mega_weapons.append(rid)
	GameState.active_weapons[rid] = 1

	# 特效
	EventBus.super_weapon_synthesized.emit(recipe["name"])
	EventBus.screen_shake_requested.emit(12.0, 0.8)
	# Mega 超武合成音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_super_weapon()

	# 根据配方应用特殊效果
	match rid:
		"mega_inferno_glacier":
			_apply_mega_inferno_glacier()


func _apply_mega_inferno_glacier() -> void:
	"""湮灭冰火环：5 秒交替周期，火环灼烧 + 冰晶冰冻，交替时触发 200% 真实伤害碎裂"""
	var pl = get_tree().get_nodes_in_group("player")
	if pl.size() == 0:
		return
	var p = pl[0]
	# 添加一个周期 Timer
	var t := Timer.new()
	t.name = "MegaInfernoGlacierTimer"
	t.wait_time = 5.0
	t.one_shot = false
	t.timeout.connect(func(): _mega_alternate_proc(p))
	p.add_child(t)
	t.start()


func _mega_alternate_proc(player: Node2D) -> void:
	"""每 5 秒周期交替触发真实伤害碎裂"""
	# 视觉：爆炸光圈
	var ring := Sprite2D.new()
	ring.texture = _make_mega_ring_tex()
	ring.global_position = player.global_position
	ring.modulate = Color(1.0, 0.5, 0.8, 0.7)
	get_tree().current_scene.add_child(ring)
	var tw := create_tween()
	tw.tween_property(ring, "scale", Vector2(5.0, 5.0), 0.5)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
	tw.tween_callback(ring.queue_free)

	# 对范围内全部敌人造成 200% 真实伤害（取主武器基础伤害均值）
	var base := 15.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if player.global_position.distance_to(enemy.global_position) < 200.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(base * 2.0, true)
			EventBus.damage_number_requested.emit(
				enemy.global_position + Vector2(0, -20),
				base * 2.0, true, 3
			)

	EventBus.screen_shake_requested.emit(6.0, 0.3)


func _make_mega_ring_tex() -> Texture2D:
	var size := 100
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := size / 2
	for x in range(size):
		for y in range(size):
			var d := Vector2(x - c, y - c).length()
			var alpha: float = max(0.0, 1.0 - d / float(c))
			img.set_pixel(x, y, Color(1.0, 0.4 + alpha * 0.4, 0.8, alpha * 0.6))
	return ImageTexture.create_from_image(img)


func _synthesize_super(weapon_id: String, super_name: String) -> void:
	GameState.super_weapons.append(weapon_id)
	EventBus.super_weapon_synthesized.emit(super_name)
	EventBus.screen_shake_requested.emit(8.0, 0.5)
	# 超武合成音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_super_weapon()

	GameState.active_weapons[weapon_id] = 8
	var player = get_tree().get_nodes_in_group("player")
	if player.size() > 0:
		for child in player[0].get_children():
			if child is BaseWeapon and child.weapon_id == weapon_id:
				child.level_up()


func _hide_panel() -> void:
	get_tree().paused = false
	GameState.is_paused = false
	GameState.modal_active = false
	# 面板淡出后隐藏
	if _hide_tween:
		_hide_tween.kill()
	_hide_tween = create_tween()
	_hide_tween.tween_property(_overlay, "modulate:a", 0.0, 0.15)
	_hide_tween.tween_callback(func():
		visible = false
		_overlay.modulate.a = 1.0
	)


func _get_weapon_upgrade_desc(weapon_id: String, next_lv: int) -> String:
	match weapon_id:
		"magic_bolt":
			match next_lv:
				2: return "伤害 +50%（12→18）"
				3: return "攻速 +37%（0.8→1.1次/s）"
				4: return "穿透 +1"
				5: return "伤害 +40%（18→25）"
				6: return "攻速 +36%（1.1→1.5次/s）"
				7: return "穿透 +1（2层）"
				8: return "★ 超武·星爆！全屏贯穿"
				_: return "属性提升"
		"fire_ring":
			match next_lv:
				2: return "伤害 +50%（8→12）"
				3: return "范围 +37%（80→110）"
				4: return "频率 +40%（0.5→0.7）"
				5: return "伤害 +50%（12→18）"
				6: return "频率 +28%（0.7→0.9）"
				7: return "范围+伤害提升（140/25）"
				_: return "属性提升"
		"lightning_chain":
			match next_lv:
				2: return "伤害 +50%（8→12）"
				3: return "连锁 +1（3→4）"
				4: return "弹跳范围 +42%（120→170）"
				5: return "伤害 +50%（12→18）"
				6: return "连锁 +1（4→5）"
				7: return "弹跳范围 +29%（170→220）"
				8: return "★ 超武·雷神之怒：连锁6+天雷"
				_: return "属性提升"
		"ice_storm":
			match next_lv:
				2: return "伤害提升（6→9）"
				3: return "冰晶 +1（2→3）"
				4: return "转速提升"
				5: return "伤害提升（9→14）"
				6: return "冰晶 +1（3→4）"
				7: return "转速提升 + 命中减速"
				8: return "★ 超武·冰河纪元：减速→冰冻"
				_: return "属性提升"
		"holy_spear":
			match next_lv:
				2: return "伤害 +50%（20→30）"
				3: return "宽度提升"
				4: return "穿透 +1"
				5: return "伤害 +50%（30→45）"
				6: return "宽度提升"
				7: return "穿透 +1（3层）"
				8: return "★ 超武·圣裁：暴击+30% 贯穿全屏"
				_: return "属性提升"
		"poison_cloud":
			match next_lv:
				2: return "伤害 +67%（3→5/s）"
				3: return "范围提升（60→90）"
				4: return "持续 +67%（3→5s）"
				5: return "伤害 +60%（5→8/s）"
				6: return "范围提升（90→130）"
				7: return "持续提升（5→7s）"
				8: return "★ 超武·瘟疫：跟随玩家"
				_: return "属性提升"
		"lava_zone":
			match next_lv:
				2: return "伤害 +50%（8→12）"
				3: return "范围提升（100→120）"
				4: return "频率提升（1.0→0.8s）"
				5: return "伤害 +56%（12→20）"
				6: return "范围+频率提升（150/1.5s）"
				7: return "伤害+持续提升（35/5s）"
				8: return "★ 超武·熔岩之心：范围翻倍"
				_: return "属性提升"
		_: return "属性提升"
