# Codex - 图鉴：超级武器合成配方
extends Control

const SUPER_RECIPES = [
	{"w": "🔮 魔法弹", "s": "星爆", "cond": "魔法弹 Lv7(满) + 被动「经验加成」Lv5(满)", "fx": "慢速大光球贯穿全屏，每 3 秒全屏星屑爆炸"},
	{"w": "🔥 烈焰环", "s": "炼狱", "cond": "烈焰环 Lv7 + 被动「铁壁」Lv5", "fx": "三层火环 + 灼烧翻倍 + 范围内减速"},
	{"w": "⚡ 闪电链", "s": "雷神之怒", "cond": "闪电链 Lv7 + 被动「疾步」Lv5", "fx": "连锁 6 + 每次弹跳召唤天雷"},
	{"w": "❄️ 冰晶风暴", "s": "冰河纪元", "cond": "冰晶风暴 Lv7 + 被动「生命强化」Lv5", "fx": "命中冰冻，冰冻碎裂造成范围伤害"},
	{"w": "🏹 圣光之矛", "s": "圣裁", "cond": "圣光之矛 Lv7 + 被动「铁壁」Lv5", "fx": "暴击 +30% + 暴伤 2.0× + 贯穿全屏"},
	{"w": "☠️ 毒雾", "s": "瘟疫", "cond": "毒雾 Lv7 + 被动「幸运」Lv5", "fx": "毒雾跟随玩家 + 中毒层数无上限"},
]

const BESTIARY = [
	{"id": "slime_small", "name": "小史莱姆", "icon": "🔴", "hp": "15", "desc": "最常见的魔物，成群结队涌来"},
	{"id": "slime_big", "name": "大史莱姆", "icon": "🟥", "hp": "45", "desc": "死亡时分裂为两只小史莱姆"},
	{"id": "bat", "name": "蝙蝠", "icon": "🦇", "hp": "12", "desc": "正弦飘忽飞行，偶尔随机冲刺"},
	{"id": "skeleton", "name": "骷髅兵", "icon": "💀", "hp": "30", "desc": "蓄力后 3 倍速冲刺，3 分钟后出现"},
	{"id": "ghost", "name": "法师幽魂", "icon": "👻", "hp": "20", "desc": "保持距离发射暗影弹，6 分钟后出现"},
	{"id": "boss_shadow_lord", "name": "暗影领主", "icon": "👑", "hp": "800", "desc": "裂隙之主，三阶段 BOSS，10 分钟降临"},
]


func _ready() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.08, 0.12)
	add_child(bg)

	var title = Label.new()
	title.text = "📖 图鉴 · 超级武器合成"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(PRESET_TOP_WIDE)
	title.offset_top = 28
	add_child(title)

	var hint = Label.new()
	hint.text = "武器升到满级 Lv7 + 对应被动升到满级 Lv5 → 升级时自动合成超武"
	hint.add_theme_font_size_override("font_size", 15)
	hint.modulate = Color(0.7, 0.8, 0.95)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(PRESET_TOP_WIDE)
	hint.offset_top = 72
	add_child(hint)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.offset_top = 108
	scroll.offset_bottom = -72
	scroll.offset_left = 24
	scroll.offset_right = -24
	add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	for r in SUPER_RECIPES:
		vbox.add_child(_make_card(r))

	# ── 怪物图鉴 ──
	var sep = Label.new()
	sep.text = "—— 👹 怪物图鉴 ——"
	sep.add_theme_font_size_override("font_size", 18)
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.modulate = Color(0.95, 0.6, 0.6)
	vbox.add_child(sep)
	var bestiary = SaveSystem.data.get("bestiary", {})
	for b in BESTIARY:
		vbox.add_child(_make_enemy_card(b, int(bestiary.get(b["id"], 0))))

	var back = Button.new()
	back.text = "← 返回主菜单"
	back.custom_minimum_size = Vector2(200, 44)
	back.add_theme_font_size_override("font_size", 16)
	back.anchor_left = 0.5
	back.anchor_right = 0.5
	back.anchor_top = 1.0
	back.anchor_bottom = 1.0
	back.offset_left = -100
	back.offset_right = 100
	back.offset_top = -58
	back.offset_bottom = -14
	add_child(back)
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))


func _make_card(r: Dictionary) -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)

	var head = Label.new()
	head.text = "%s   ★合成→   %s" % [r["w"], r["s"]]
	head.add_theme_font_size_override("font_size", 18)
	head.modulate = Color(1.0, 0.85, 0.3)
	vb.add_child(head)

	var cond = Label.new()
	cond.text = "📋 条件：" + r["cond"]
	cond.add_theme_font_size_override("font_size", 14)
	cond.modulate = Color(0.8, 0.9, 0.7)
	vb.add_child(cond)

	var fx = Label.new()
	fx.text = "✨ 效果：" + r["fx"]
	fx.add_theme_font_size_override("font_size", 13)
	fx.modulate = Color(0.75, 0.8, 0.9)
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(fx)

	return panel


func _make_enemy_card(b: Dictionary, kills: int) -> Control:
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = SIZE_EXPAND_FILL
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	margin.add_child(vb)

	var head = Label.new()
	head.add_theme_font_size_override("font_size", 16)
	if kills > 0:
		head.text = "%s %s   （HP %s · 已击杀 %d）" % [b["icon"], b["name"], b["hp"], kills]
		head.modulate = Color(0.9, 0.95, 0.8)
		vb.add_child(head)
		var d = Label.new()
		d.text = b["desc"]
		d.add_theme_font_size_override("font_size", 13)
		d.modulate = Color(0.75, 0.8, 0.9)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(d)
	else:
		head.text = "❓ ???   （击败后解锁）"
		head.modulate = Color(0.5, 0.5, 0.5)
		vb.add_child(head)

	return panel
