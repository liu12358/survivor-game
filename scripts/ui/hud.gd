# HUD - 游戏内界面
# 显示血量、经验条、时间、击杀数
# 通过代码构建UI，避免.tscn中节点缺失问题
extends CanvasLayer

const WEAPON_ICONS := {"magic_bolt": "🔮", "fire_ring": "🔥", "lightning_chain": "⚡", "ice_storm": "❄️", "holy_spear": "🏹", "poison_cloud": "☠️", "sword_orbit": "⚔️", "piercing_arrow": "🎯", "lava_zone": "🌋"}
const PASSIVE_ICONS := {"max_hp": "❤️", "speed": "👟", "magnet": "🧲", "armor": "🛡️", "exp_bonus": "💎", "crit": "🎯", "lifesteal": "🩸", "luck": "🍀", "shield_max": "🔰"}

var equip_box: VBoxContainer
var hp_bar: ProgressBar
var hp_label: Label
var exp_bar: ProgressBar
var level_label: Label
var timer_label: Label
var kill_label: Label
var gold_label: Label
var enemy_label: Label
var mode_label: Label
var boss_hp_bar: ProgressBar
var boss_name_label: Label
var low_hp_overlay: ColorRect

var _low_hp_tween: Tween
var _exp_pulse_tween: Tween
var _streak_tween: Tween = null
var _hp_tween: Tween = null
var _exp_tween: Tween = null
var _boss_bar_tween: Tween = null
var _enemy_count_timer: float = 0.0
var _streak_label: Label
var _weapon_labels: Dictionary = {}  # {weapon_id: Label}
var _passive_labels: Dictionary = {}  # {passive_id: Label}
var _dps_label: Label
var _dps_timer: float = 0.0
var _dps_damage: float = 0.0
var _current_dps: float = 0.0


func _ready() -> void:
	_create_ui()
	_connect_signals()
	_update_all()


func _process(_delta: float) -> void:
	if GameState.is_paused:
		return
	if GameState.is_game_over:
		return

	# 怪物数量每0.5秒更新
	_enemy_count_timer += _delta
	if _enemy_count_timer >= 0.5:
		_enemy_count_timer = 0.0
		var count = get_tree().get_nodes_in_group("enemy").size()
		enemy_label.text = "怪物: %d" % count

	# DPS 每秒计算一次
	_dps_timer += _delta
	if _dps_timer >= 1.0:
		_dps_timer = 0.0
		_current_dps = _dps_damage
		_dps_damage = 0.0
		_dps_label.text = "DPS: %.0f" % _current_dps


func _create_ui() -> void:
	# ─── 底层：低血量红色覆盖 ───
	low_hp_overlay = ColorRect.new()
	low_hp_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	low_hp_overlay.color = Color(1, 0, 0, 0.0)
	low_hp_overlay.visible = false
	low_hp_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(low_hp_overlay)

	# ─── 主容器 ───
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(hbox)

	# ─── 左面板 ───
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(left_panel)

	# 等级标签
	level_label = Label.new()
	level_label.text = "Lv.1"
	level_label.add_theme_font_size_override("font_size", 18)
	left_panel.add_child(level_label)

	# HP条
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(300, 24)
	hp_bar.show_percentage = false
	hp_bar.min_value = 0
	hp_bar.max_value = GameState.max_hp
	hp_bar.value = GameState.current_hp

	var hp_bg = StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	hp_bg.corner_radius_top_left = 4
	hp_bg.corner_radius_top_right = 4
	hp_bg.corner_radius_bottom_left = 4
	hp_bg.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("background", hp_bg)

	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.2, 0.75, 0.3)
	hp_fill.corner_radius_top_left = 4
	hp_fill.corner_radius_top_right = 4
	hp_fill.corner_radius_bottom_left = 4
	hp_fill.corner_radius_bottom_right = 4
	hp_bar.add_theme_stylebox_override("fill", hp_fill)

	left_panel.add_child(hp_bar)

	hp_label = Label.new()
	hp_label.text = "100 / 100"
	hp_label.add_theme_font_size_override("font_size", 12)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.add_child(hp_label)

	# EXP条
	exp_bar = ProgressBar.new()
	exp_bar.custom_minimum_size = Vector2(300, 10)
	exp_bar.show_percentage = false
	exp_bar.min_value = 0
	exp_bar.max_value = 100
	exp_bar.value = 0

	var exp_bg = StyleBoxFlat.new()
	exp_bg.bg_color = Color(0.1, 0.1, 0.15, 0.7)
	exp_bg.corner_radius_top_left = 3
	exp_bg.corner_radius_top_right = 3
	exp_bg.corner_radius_bottom_left = 3
	exp_bg.corner_radius_bottom_right = 3
	exp_bar.add_theme_stylebox_override("background", exp_bg)

	var exp_fill = StyleBoxFlat.new()
	exp_fill.bg_color = Color(0.3, 0.5, 1.0)
	exp_fill.corner_radius_top_left = 3
	exp_fill.corner_radius_top_right = 3
	exp_fill.corner_radius_bottom_left = 3
	exp_fill.corner_radius_bottom_right = 3
	exp_bar.add_theme_stylebox_override("fill", exp_fill)

	left_panel.add_child(exp_bar)

	# ─── 中间弹性间距 ───
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(spacer)

	# ─── 右面板 ───
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	right_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right_panel)

	mode_label = Label.new()
	mode_label.text = "🏰 关卡" if GameState.current_mode == "level" else "♾️ 无尽"
	mode_label.add_theme_font_size_override("font_size", 14)
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mode_label.modulate = Color(0.6, 0.8, 1.0)
	right_panel.add_child(mode_label)

	# 角色名
	var char_label = Label.new()
	var char_names = {"mage": "🧙 法师", "argo": "⚔️ 剑圣", "selene": "🏹 弓手", "little_fried_egg": "🍳 小煎蛋"}
	char_label.text = char_names.get(GameState.current_character, "🧙 法师")
	char_label.add_theme_font_size_override("font_size", 12)
	char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	char_label.modulate = Color(0.7, 0.8, 0.9)
	right_panel.add_child(char_label)

	timer_label = Label.new()
	timer_label.text = "00:00"
	timer_label.add_theme_font_size_override("font_size", 20)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_panel.add_child(timer_label)

	kill_label = Label.new()
	kill_label.text = "击杀: 0"
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_panel.add_child(kill_label)

	gold_label = Label.new()
	gold_label.text = "Gold: 0"
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right_panel.add_child(gold_label)

	enemy_label = Label.new()
	enemy_label.text = "怪物: 0"
	enemy_label.add_theme_font_size_override("font_size", 14)
	enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	enemy_label.modulate = Color(0.8, 0.6, 0.6)
	right_panel.add_child(enemy_label)

	# DPS 显示
	_dps_label = Label.new()
	_dps_label.text = "DPS: 0"
	_dps_label.add_theme_font_size_override("font_size", 13)
	_dps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_dps_label.modulate = Color(1.0, 0.85, 0.4)
	right_panel.add_child(_dps_label)

	# ESC 暂停提示
	var esc_hint = Label.new()
	esc_hint.text = "ESC 暂停"
	esc_hint.add_theme_font_size_override("font_size", 10)
	esc_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	esc_hint.modulate = Color(0.4, 0.45, 0.55)
	right_panel.add_child(esc_hint)

	# ─── 连杀提示（居中顶部，默认隐藏）───
	_streak_label = Label.new()
	_streak_label.text = ""
	_streak_label.add_theme_font_size_override("font_size", 28)
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_streak_label.offset_top = 80
	_streak_label.z_index = 90
	_streak_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_streak_label.visible = false
	add_child(_streak_label)

	# ─── BOSS 血条（居中顶部，默认隐藏）───
	var boss_box = VBoxContainer.new()
	boss_box.name = "BossBox"
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.offset_top = 44
	boss_box.offset_left = -210
	boss_box.offset_right = 210
	boss_box.alignment = BoxContainer.ALIGNMENT_CENTER
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.visible = false
	add_child(boss_box)

	boss_name_label = Label.new()
	boss_name_label.text = "👑 暗影领主"
	boss_name_label.add_theme_font_size_override("font_size", 18)
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name_label.modulate = Color(1.0, 0.3, 0.3)
	boss_box.add_child(boss_name_label)

	boss_hp_bar = ProgressBar.new()
	boss_hp_bar.custom_minimum_size = Vector2(420, 20)
	boss_hp_bar.show_percentage = false
	boss_hp_bar.min_value = 0
	boss_hp_bar.max_value = 800

	var boss_hp_bg = StyleBoxFlat.new()
	boss_hp_bg.bg_color = Color(0.15, 0.08, 0.08, 0.9)
	boss_hp_bg.corner_radius_top_left = 4
	boss_hp_bg.corner_radius_top_right = 4
	boss_hp_bg.corner_radius_bottom_left = 4
	boss_hp_bg.corner_radius_bottom_right = 4
	boss_hp_bg.border_width_left = 1
	boss_hp_bg.border_width_right = 1
	boss_hp_bg.border_width_top = 1
	boss_hp_bg.border_width_bottom = 1
	boss_hp_bg.border_color = Color(0.6, 0.2, 0.2, 0.8)
	boss_hp_bar.add_theme_stylebox_override("background", boss_hp_bg)

	var boss_hp_fill = StyleBoxFlat.new()
	boss_hp_fill.bg_color = Color(0.85, 0.15, 0.15)
	boss_hp_fill.corner_radius_top_left = 4
	boss_hp_fill.corner_radius_top_right = 4
	boss_hp_fill.corner_radius_bottom_left = 4
	boss_hp_fill.corner_radius_bottom_right = 4
	boss_hp_bar.add_theme_stylebox_override("fill", boss_hp_fill)

	boss_box.add_child(boss_hp_bar)

	# 装备栏（左下角，显示武器/被动）
	equip_box = VBoxContainer.new()
	equip_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	equip_box.offset_left = 12
	equip_box.offset_top = -78
	equip_box.offset_bottom = -10
	equip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(equip_box)

	# 小地图（右上角）
	_add_minimap()


func _connect_signals() -> void:
	EventBus.player_damaged.connect(_on_player_damaged)
	EventBus.player_healed.connect(_on_player_healed)
	EventBus.exp_collected.connect(_on_exp_collected)
	EventBus.game_time_updated.connect(_on_time_updated)
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.gold_collected.connect(_on_gold_collected)
	EventBus.player_level_up.connect(_on_level_up)
	EventBus.low_hp_warning_triggered.connect(_show_low_hp_warning)
	EventBus.low_hp_warning_cleared.connect(_hide_low_hp_warning)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_hp_changed.connect(_on_boss_hp_changed)
	EventBus.boss_killed.connect(_on_boss_killed)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.achievement_unlocked.connect(_on_achievement)
	EventBus.game_started.connect(_update_all)     # 开局/重开后刷新全部显示
	EventBus.player_revived.connect(_update_all)    # 复活后刷新血量/等级
	EventBus.upgrade_selected.connect(_on_upgrade_selected)  # 升级后刷新装备栏
	EventBus.streak_reached.connect(_on_streak_reached)
	EventBus.enemy_damaged.connect(_on_enemy_damaged_for_dps)


# ─── 信号处理 ───

func _on_player_damaged(_amount: float, current_hp: float, _max_hp: float) -> void:
	_update_hp_display(current_hp)


func _on_player_healed(_amount: float, current_hp: float) -> void:
	_update_hp_display(current_hp)


func _update_hp_display(cur: float = -1.0) -> void:
	if cur < 0:
		cur = GameState.current_hp
	hp_bar.max_value = GameState.max_hp
	_tween_hp_bar(max(0, cur))
	hp_label.text = "%d / %d" % [int(max(0, cur)), int(GameState.max_hp)]

	# HP条颜色：绿→黄→红
	var pct = cur / max(GameState.max_hp, 1.0)
	var fill_style = hp_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		if pct > 0.6:
			fill_style.bg_color = Color(0.2, 0.75, 0.3)
		elif pct > 0.3:
			fill_style.bg_color = Color(0.85, 0.7, 0.15)
		else:
			fill_style.bg_color = Color(0.85, 0.2, 0.2)

	if cur < GameState.max_hp * 0.3:
		EventBus.low_hp_warning_triggered.emit(cur / GameState.max_hp)
	else:
		EventBus.low_hp_warning_cleared.emit()


# 血条平滑过渡
func _tween_hp_bar(target: float) -> void:
	if _hp_tween:
		_hp_tween.kill()
	_hp_tween = create_tween()
	_hp_tween.tween_property(hp_bar, "value", target, 0.2)


func _on_exp_collected(amount: int) -> void:
	if GameState.player_level >= GameState.max_player_level:
		return  # 50 级后停止累计经验（D-9）
	var exp_rate: float = GameState.get_effective_exp_rate()
	var gained: int = int(float(amount) * exp_rate)
	GameState.current_exp += gained
	exp_bar.max_value = GameState.exp_to_next_level
	# 经验条平滑过渡
	if _exp_tween:
		_exp_tween.kill()
	_exp_tween = create_tween()
	_exp_tween.tween_property(exp_bar, "value", GameState.current_exp, 0.15)

	# 连升多级时循环处理（避免 _process 双路径冲突）
	while GameState.current_exp >= GameState.exp_to_next_level and GameState.player_level < GameState.max_player_level:
		_level_up()
		# 升级后若 EXP 仍 >80%，立即重启脉冲
		var pct = GameState.current_exp / max(GameState.exp_to_next_level, 1.0)
		if pct > 0.8 and not _exp_pulse_tween:
			_start_exp_pulse()

	# 经验条呼吸灯（>80%时脉冲）
	var final_pct = GameState.current_exp / max(GameState.exp_to_next_level, 1.0)
	if final_pct > 0.8 and not _exp_pulse_tween:
		_start_exp_pulse()
	elif final_pct <= 0.8 and _exp_pulse_tween:
		_stop_exp_pulse()


func _start_exp_pulse() -> void:
	_exp_pulse_tween = create_tween().set_loops()
	_exp_pulse_tween.tween_property(exp_bar, "modulate:a", 0.5, 0.5)
	_exp_pulse_tween.tween_property(exp_bar, "modulate:a", 1.0, 0.5)


func _stop_exp_pulse() -> void:
	if _exp_pulse_tween:
		_exp_pulse_tween.kill()
		_exp_pulse_tween = null
	exp_bar.modulate.a = 1.0


func _level_up() -> void:
	_stop_exp_pulse()
	GameState.current_exp -= GameState.exp_to_next_level
	GameState.player_level += 1
	GameState.exp_to_next_level = GameState._calculate_exp_for_level(GameState.player_level)
	exp_bar.max_value = GameState.exp_to_next_level
	exp_bar.value = GameState.current_exp
	level_label.text = "Lv.%d" % GameState.player_level
	# 升级音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_levelup()
	EventBus.player_level_up.emit(GameState.player_level)


func _on_level_up(level: int) -> void:
	level_label.text = "Lv.%d" % level


func _on_time_updated(seconds: float) -> void:
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	timer_label.text = "%02d:%02d" % [mins, secs]


func _on_enemy_killed(_type: String, _pos: Vector2, _exp: int, _gold: int) -> void:
	GameState.kills += 1
	kill_label.text = "击杀: %d" % GameState.kills


func _on_gold_collected(amount: int) -> void:
	GameState.gold_earned += amount
	gold_label.text = "Gold: %d" % GameState.gold_earned


func _show_low_hp_warning(_pct: float) -> void:
	low_hp_overlay.visible = true
	if _low_hp_tween:
		_low_hp_tween.kill()
	_low_hp_tween = create_tween().set_loops()
	_low_hp_tween.tween_property(low_hp_overlay, "color:a", 0.25, 0.5)
	_low_hp_tween.tween_property(low_hp_overlay, "color:a", 0.1, 0.5)


func _hide_low_hp_warning() -> void:
	if _low_hp_tween:
		_low_hp_tween.kill()
		_low_hp_tween = null
	if low_hp_overlay.visible:
		# 淡出后再隐藏，避免突然消失
		var t = create_tween()
		t.tween_property(low_hp_overlay, "color:a", 0.0, 0.3)
		t.tween_callback(func(): low_hp_overlay.visible = false)


func _on_boss_spawned() -> void:
	var bb = get_node_or_null("BossBox")
	if bb:
		if _boss_bar_tween:
			_boss_bar_tween.kill()
		# 初始状态：透明 + 上方偏移
		bb.modulate.a = 0.0
		bb.offset_top = 24
		bb.visible = true
		# 淡入 + 滑入
		_boss_bar_tween = create_tween().set_parallel(true)
		_boss_bar_tween.tween_property(bb, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_BACK)
		_boss_bar_tween.tween_property(bb, "offset_top", 44, 0.3).set_trans(Tween.TRANS_BACK)


func _on_boss_hp_changed(cur: float, mx: float) -> void:
	if boss_hp_bar:
		boss_hp_bar.max_value = mx
		boss_hp_bar.value = cur


func _on_boss_killed() -> void:
	var bb = get_node_or_null("BossBox")
	if bb:
		if _boss_bar_tween:
			_boss_bar_tween.kill()
		# 淡出后隐藏
		_boss_bar_tween = create_tween()
		_boss_bar_tween.tween_property(bb, "modulate:a", 0.0, 0.2)
		_boss_bar_tween.tween_callback(func(): bb.visible = false)


func _on_boss_phase_changed(phase: int) -> void:
	if not boss_name_label:
		return
	var names = {1: "👑 暗影领主", 2: "👑 暗影领主 · 深渊觉醒", 3: "👑 暗影领主 · 末日审判"}
	boss_name_label.text = names.get(phase, "👑 暗影领主")


func _on_enemy_damaged_for_dps(_enemy: Node2D, amount: float, _is_crit: bool) -> void:
	_dps_damage += amount


func _on_achievement(id: String) -> void:
	var info = SaveSystem.ACHIEVEMENTS.get(id, {"name": id, "gold": 0})
	var label = Label.new()
	label.text = "🏆 成就：%s (+%d💰)" % [info.get("name", id), int(info.get("gold", 0))]
	label.add_theme_font_size_override("font_size", 18)
	label.modulate = Color(1, 0.9, 0.3, 0)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = 110
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	var t = create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.5)
	t.tween_property(label, "modulate:a", 0.0, 0.5)
	t.tween_callback(label.queue_free)


func _update_all() -> void:
	_update_hp_display(GameState.current_hp)
	exp_bar.max_value = GameState.exp_to_next_level
	exp_bar.value = GameState.current_exp
	level_label.text = "Lv.%d" % GameState.player_level
	kill_label.text = "击杀: %d" % GameState.kills
	gold_label.text = "Gold: %d" % GameState.gold_earned
	_refresh_equip()


func _on_upgrade_selected(_id: String) -> void:
	_refresh_equip()


func _refresh_equip() -> void:
	if not equip_box:
		return

	# ─── 武器行（复用 Label，避免每次升级销毁重建）───
	var wrow: HBoxContainer = equip_box.get_node_or_null("WeaponRow") as HBoxContainer
	if not wrow:
		wrow = HBoxContainer.new()
		wrow.name = "WeaponRow"
		wrow.add_theme_constant_override("separation", 6)
		wrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		equip_box.add_child(wrow)

	var seen_weapons: Array[String] = []
	for wid in GameState.active_weapons:
		seen_weapons.append(wid)
		var lbl: Label = _weapon_labels.get(wid)
		if not lbl or not is_instance_valid(lbl):
			lbl = Label.new()
			lbl.add_theme_font_size_override("font_size", 16)
			_weapon_labels[wid] = lbl
			wrow.add_child(lbl)
		var is_super = GameState.super_weapons.has(wid)
		lbl.text = "%s%d%s" % [WEAPON_ICONS.get(wid, "⚔️"), int(GameState.active_weapons[wid]), ("★" if is_super else "")]
		lbl.modulate = Color(1.0, 0.85, 0.3) if is_super else Color.WHITE
		lbl.visible = true

	# 移除已不在 active_weapons 中的标签
	for wid in _weapon_labels.keys():
		if not seen_weapons.has(wid):
			var lbl = _weapon_labels[wid]
			if is_instance_valid(lbl):
				lbl.queue_free()
			_weapon_labels.erase(wid)

	# ─── 被动行（同理）───
	var prow: HBoxContainer = equip_box.get_node_or_null("PassiveRow") as HBoxContainer
	if not prow:
		prow = HBoxContainer.new()
		prow.name = "PassiveRow"
		prow.add_theme_constant_override("separation", 6)
		prow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		equip_box.add_child(prow)

	var seen_passives: Array[String] = []
	for pid in GameState.active_passives:
		seen_passives.append(pid)
		var lbl: Label = _passive_labels.get(pid)
		if not lbl or not is_instance_valid(lbl):
			lbl = Label.new()
			lbl.add_theme_font_size_override("font_size", 13)
			lbl.modulate = Color(0.8, 0.9, 1.0)
			_passive_labels[pid] = lbl
			prow.add_child(lbl)
		lbl.text = "%s%d" % [PASSIVE_ICONS.get(pid, "·"), int(GameState.active_passives[pid])]
		lbl.visible = true

	for pid in _passive_labels.keys():
		if not seen_passives.has(pid):
			var lbl = _passive_labels[pid]
			if is_instance_valid(lbl):
				lbl.queue_free()
			_passive_labels.erase(pid)


func _add_minimap() -> void:
	var minimap_script = load("res://scripts/ui/minimap.gd")
	if minimap_script:
		var minimap = Control.new()
		minimap.set_script(minimap_script)
		add_child(minimap)


func _on_streak_reached(count: int) -> void:
	var streak_text = ""
	var streak_color = Color.WHITE
	match count:
		10:
			streak_text = "🔥 10连杀！经验+20%"
			streak_color = Color(1.0, 0.6, 0.2)
		25:
			streak_text = "🔥🔥 25连杀！经验+40%"
			streak_color = Color(1.0, 0.4, 0.1)
		50:
			streak_text = "💥 50连杀！经验+60%"
			streak_color = Color(1.0, 0.8, 0.0)
		100:
			streak_text = "💀 100连杀！经验+80%"
			streak_color = Color(0.9, 0.2, 0.2)
		200:
			streak_text = "⭐ 200连杀！经验+100%"
			streak_color = Color(1.0, 0.9, 0.3)

	if streak_text.is_empty():
		return

	_streak_label.text = streak_text
	_streak_label.modulate = streak_color
	_streak_label.visible = true
	_streak_label.scale = Vector2(1.3, 1.3)

	if _streak_tween:
		_streak_tween.kill()
	_streak_tween = create_tween()
	_streak_tween.tween_property(_streak_label, "scale", Vector2.ONE, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_streak_tween.tween_interval(1.5)
	_streak_tween.tween_property(_streak_label, "modulate:a", 0.0, 0.3)
	_streak_tween.tween_callback(func():
		_streak_label.visible = false
		_streak_label.modulate.a = 1.0
	)
