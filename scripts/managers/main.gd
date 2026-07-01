# Main - 主关卡控制器
# 管理游戏循环、波次、升级系统、BOSS触发
class_name Main
extends Node2D

const BOSS_SPAWN_TIME: float = 600.0  # 10分钟
const BOSS_COUNTDOWN_START: float = 30.0  # 提前30秒倒计时
const TOTAL_GAME_TIME: float = 900.0  # 15分钟通关（关卡模式）
const INFINITE_BOSS_INTERVAL: float = 300.0  # 无尽模式每5分钟刷BOSS

@onready var player: Node2D = $Player
@onready var enemy_spawner: Node2D = $EnemySpawner
@onready var camera: Camera2D = $Player/Camera2D
@onready var hud: CanvasLayer = $HUD
@onready var level_up_panel: Node = $LevelUpPanel

var _boss_spawned: bool = false
var _boss_countdown_active: bool = false
var _game_ended: bool = false
var _total_game_time: float = 0.0
var _next_boss_time: float = 0.0
var _star_timer: float = 0.0
var _sword_wave_active: bool = false   # 剑气纵横防递归

# 震屏
var _shake_amplitude: float = 0.0
var _shake_duration: float = 0.0
var _shake_priority: float = 0.0
var _camera_original_pos: Vector2

# Camera Breathing — 动态视场收缩
const CAMERA_ZOOM_DEFAULT: float = 1.0
const CAMERA_ZOOM_OUT_MAX: float = 0.85
const CAMERA_ZOOM_EPIC_IN: float = 1.15
const CAMERA_ZOOM_SMOOTH: float = 2.5   # 平滑速度
var _target_zoom: float = CAMERA_ZOOM_DEFAULT
var _epic_zoom_timer: float = 0.0
var _epic_zoom_active: bool = false

const GRID_SIZE: float = 96.0
const MAP_RADIUS: float = 800.0

# 背景装饰种子（固定，每局相同）
var _bg_seed: int = 0
var _bg_texture: ImageTexture = null
var _bg_regeneration_needed: bool = true


func _ready() -> void:
	# Main 保持 PAUSABLE（默认），确保暂停时玩家/敌人/子弹等子节点全部冻结（B-13）。
	# ESC 暂停切换改由 PauseMenu（ALWAYS）处理。
	_setup_pools()
	_setup_joystick()
	_setup_cheat()
	_setup_glow()
	_setup_boundary()
	# P-2：一次性生成背景纹理缓存
	_bg_regeneration_needed = true
	_generate_bg_texture()
	_start_game()
	# 强制重绘
	queue_redraw()


func _setup_boundary() -> void:
	var body = StaticBody2D.new()
	body.name = "MapBoundary"
	body.collision_layer = 0
	body.collision_mask = 1 | 2  # 碰撞玩家(1)和敌人(2)
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = MAP_RADIUS
	shape.shape = circle
	body.add_child(shape)
	add_child(body)


func _setup_glow() -> void:
	# 全局辉光（让亮部 bloom）。仅 forward_plus/mobile（桌面/安卓）生效；
	# Web 的 Compatibility 渲染器会忽略，不报错——Web 靠程序化光晕(VFX)发光。
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.2
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_hdr_threshold = 0.8
	env.glow_layers = 3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	# 屏幕暗角（CanvasLayer 确保在最上层）
	_setup_vignette()


func _setup_vignette() -> void:
	var vignette_layer := CanvasLayer.new()
	vignette_layer.layer = 10
	vignette_layer.name = "Vignette"
	add_child(vignette_layer)

	# 创建暗角纹理
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size / 2.0, size / 2.0)
	for x in range(size):
		for y in range(size):
			var d := Vector2(x - y if false else x, y).distance_to(center) / (size / 2.0)
			var alpha := clampf((d - 0.5) * 1.5, 0.0, 0.7)
			img.set_pixel(x, y, Color(0, 0, 0, alpha))

	var tex := ImageTexture.create_from_image(img)
	var sprite := TextureRect.new()
	sprite.texture = tex
	sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.modulate = Color(0.8, 0.85, 1.0, 0.4)
	vignette_layer.add_child(sprite)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if not GameState.is_paused and not _game_ended:
			_pause_game()


func _draw() -> void:
	# P-2：使用预生成的背景纹理（每帧只需 1 次 draw_texture）
	if _bg_texture:
		draw_texture(_bg_texture, Vector2.ZERO - _bg_texture.get_size() / 2.0)
	else:
		_draw_dungeon_background()  # 兜底

	# 边界光环
	draw_arc(Vector2.ZERO, MAP_RADIUS - 2, 0, TAU, 96, Color(0.6, 0.5, 0.3, 0.9), 4.0)
	draw_arc(Vector2.ZERO, MAP_RADIUS, 0, TAU, 96, Color(0.5, 0.4, 0.25, 0.7), 3.0)


func _draw_dungeon_background() -> void:
	# 简单的地牢背景：用draw_circle和draw_rect直接绘制
	# 1. 底色
	draw_circle(Vector2.ZERO, MAP_RADIUS, Color(0.12, 0.10, 0.14))

	# 2. 石砖网格线
	var grid_color = Color(0.18, 0.16, 0.22, 0.5)
	var tile_size = 48.0
	for i in range(-int(MAP_RADIUS / tile_size), int(MAP_RADIUS / tile_size) + 1):
		var x = i * tile_size
		var half_h = sqrt(max(0.0, MAP_RADIUS * MAP_RADIUS - x * x))
		if half_h > 0:
			draw_line(Vector2(x, -half_h), Vector2(x, half_h), grid_color, 1.0)
		var y = i * tile_size
		var half_w = sqrt(max(0.0, MAP_RADIUS * MAP_RADIUS - y * y))
		if half_w > 0:
			draw_line(Vector2(-half_w, y), Vector2(half_w, y), grid_color, 1.0)

	# 3. 砖块装饰（随机分布的小方块）
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	for k in range(40):
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(50, MAP_RADIUS * 0.8)
		var pos = Vector2(cos(angle), sin(angle)) * dist
		var brick_size = rng.randf_range(20, 40)
		var rect = Rect2(pos.x - brick_size/2, pos.y - brick_size/2, brick_size, brick_size)
		var shade = rng.randf_range(0.14, 0.20)
		draw_rect(rect, Color(shade, shade * 0.9, shade * 1.1))

	# 4. 火把光点
	for j in range(15):
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(100, MAP_RADIUS * 0.7)
		var pos = Vector2(cos(angle), sin(angle)) * dist
		draw_circle(pos, 12, Color(0.5, 0.3, 0.1, 0.15))
		draw_circle(pos, 4, Color(0.9, 0.6, 0.2, 0.6))

	# 5. 中心出生点
	draw_circle(Vector2.ZERO, 50, Color(0.18, 0.16, 0.22, 0.3))


# P-2：一次性生成背景纹理并缓存，避免每帧 ~106 次 draw_call
func _generate_bg_texture() -> void:
	var size := int(MAP_RADIUS * 2.0 + 4.0)
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size / 2.0, size / 2.0)

	# 1. 底色圆形
	_fill_circle_on_img(img, center, MAP_RADIUS, Color(0.12, 0.10, 0.14))

	# 2. 石砖网格线
	var grid_color = Color(0.18, 0.16, 0.22, 0.5)
	var tile_size = 48.0
	var half_tiles := int(MAP_RADIUS / tile_size)
	for i in range(-half_tiles, half_tiles + 1):
		var offset = float(i) * tile_size
		var x = center.x + offset
		var half_h = sqrt(max(0.0, MAP_RADIUS * MAP_RADIUS - offset * offset))
		if half_h > 0:
			_draw_line_to_img(img, Vector2(x, center.y - half_h), Vector2(x, center.y + half_h), grid_color)
		var y = center.y + offset
		var half_w = sqrt(max(0.0, MAP_RADIUS * MAP_RADIUS - offset * offset))
		if half_w > 0:
			_draw_line_to_img(img, Vector2(center.x - half_w, y), Vector2(center.x + half_w, y), grid_color)

	# 3. 砖块装饰
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	for k in range(40):
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(50, MAP_RADIUS * 0.8)
		var pos = center + Vector2(cos(angle), sin(angle)) * dist
		var brick_size = rng.randf_range(20, 40)
		var shade = rng.randf_range(0.14, 0.20)
		_fill_rect_on_img(img, Rect2(pos.x - brick_size / 2, pos.y - brick_size / 2, brick_size, brick_size),
			Color(shade, shade * 0.9, shade * 1.1))

	# 4. 火把光点
	for j in range(15):
		var angle = rng.randf() * TAU
		var dist = rng.randf_range(100, MAP_RADIUS * 0.7)
		var pos = center + Vector2(cos(angle), sin(angle)) * dist
		_fill_circle_on_img(img, pos, 12, Color(0.5, 0.3, 0.1, 0.15))
		_fill_circle_on_img(img, pos, 4, Color(0.9, 0.6, 0.2, 0.6))

	# 5. 中心出生点
	_fill_circle_on_img(img, center, 50, Color(0.18, 0.16, 0.22, 0.3))

	_bg_texture = ImageTexture.create_from_image(img)


# 优化的矩形填充：逐像素（仅用于小矩形，性能可接受）
func _fill_rect_on_img(img: Image, rect: Rect2, color: Color) -> void:
	var x0 := int(rect.position.x)
	var y0 := int(rect.position.y)
	var x1 := int(rect.end.x)
	var y1 := int(rect.end.y)
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(0, y0), mini(h, y1)):
		for x in range(maxi(0, x0), mini(w, x1)):
			img.set_pixel(x, y, color)


# 优化的圆形填充：用水平扫描线替代全图遍历，复杂度 O(r²) 而非 O(W*H)
func _fill_circle_on_img(img: Image, center: Vector2, radius: float, color: Color) -> void:
	var cx := int(center.x)
	var cy := int(center.y)
	var r := int(radius)
	var w := img.get_width()
	var h := img.get_height()
	var r2 := r * r
	for dy in range(-r, r + 1):
		var py = cy + dy
		if py < 0 or py >= h:
			continue
		var half_w := int(sqrt(max(0.0, float(r2 - dy * dy))))
		var x_start := maxi(0, cx - half_w)
		var x_end := mini(w, cx + half_w + 1)
		for x in range(x_start, x_end):
			img.set_pixel(x, py, color)


func _draw_line_to_img(img: Image, from: Vector2, to: Vector2, color: Color) -> void:
	var steps = int(max(abs(to.x - from.x), abs(to.y - from.y)))
	if steps == 0:
		return
	var w = img.get_width()
	var h = img.get_height()
	for i in range(steps + 1):
		var t = float(i) / steps
		var px = int(lerpf(from.x, to.x, t))
		var py = int(lerpf(from.y, to.y, t))
		if px >= 0 and px < w and py >= 0 and py < h:
			img.set_pixel(px, py, color)


func _process(delta: float) -> void:
	if _game_ended:
		return

	if GameState.is_paused:
		return

	# P-1：每帧失效组缓存，确保后续 get_cached_group 获取最新数据
	GameState.invalidate_group_cache()

	_total_game_time += delta

	# 连杀计时器
	GameState.update_kill_streak(delta)

	# 限时 Buff 计时
	_update_buffs(delta)

	# 环境星屑
	_spawn_ambient_stars(delta)

	# 震屏衰减
	_update_screen_shake(delta)

	# 动态视场呼吸
	_update_camera_zoom(delta)

	# BOSS倒计时 & 生成
	if GameState.current_mode == "infinite":
		# 无尽模式：每 INFINITE_BOSS_INTERVAL 秒刷BOSS
		if not _boss_spawned and _total_game_time >= BOSS_SPAWN_TIME:
			_spawn_boss()
		elif _boss_spawned and _total_game_time >= _next_boss_time:
			_boss_spawned = false  # 允许下一个BOSS
			_next_boss_time = _total_game_time + INFINITE_BOSS_INTERVAL
	else:
		# 关卡模式：固定10分钟刷BOSS
		if not _boss_spawned and _total_game_time > BOSS_SPAWN_TIME - BOSS_COUNTDOWN_START:
			if not _boss_countdown_active:
				_boss_countdown_active = true
				EventBus.boss_countdown_started.emit(int(BOSS_SPAWN_TIME - _total_game_time))
			var remaining = int(BOSS_SPAWN_TIME - _total_game_time)
			if remaining > 0 and remaining % 5 == 0:
				EventBus.boss_countdown_tick.emit(remaining)
		if not _boss_spawned and _total_game_time >= BOSS_SPAWN_TIME:
			_spawn_boss()

		# 15分钟通关
		if _total_game_time >= TOTAL_GAME_TIME and not _game_ended:
			_game_victory()


func _start_game() -> void:
	GameState.reset_game_data()
	GameState.init_rng(GameState.game_seed)
	GameState.apply_meta_bonuses()
	_boss_spawned = false
	_boss_countdown_active = false
	_game_ended = false
	_total_game_time = 0.0
	_next_boss_time = BOSS_SPAWN_TIME + INFINITE_BOSS_INTERVAL

	# 强制重置全局状态（防止残留）
	Engine.time_scale = 1.0
	GameState.game_speed_mult = 1.0
	get_tree().paused = false
	GameState.is_paused = false
	GameState.is_game_over = false

	# 确保玩家和摄像机在地图中心
	if is_instance_valid(player):
		player.global_position = Vector2.ZERO
		player.velocity = Vector2.ZERO
	if is_instance_valid(camera):
		camera.global_position = Vector2.ZERO
		camera.reset_smoothing()

	# 重置升级面板状态
	if level_up_panel and level_up_panel.has_method("reset_for_new_game"):
		level_up_panel.reset_for_new_game()

	# 连接玩家死亡信号
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)
	# 连接震屏
	if not EventBus.screen_shake_requested.is_connected(_on_screen_shake):
		EventBus.screen_shake_requested.connect(_on_screen_shake)
	# 击杀 BOSS → 关卡模式立即胜利（D-7）
	if not EventBus.boss_killed.is_connected(_on_boss_killed):
		EventBus.boss_killed.connect(_on_boss_killed)
	# BOSS 阶段切换台词
	if not EventBus.boss_phase_changed.is_connected(_on_boss_phase):
		EventBus.boss_phase_changed.connect(_on_boss_phase)
	# 拾取增益道具
	if not EventBus.item_picked_up.is_connected(_on_item_picked_up):
		EventBus.item_picked_up.connect(_on_item_picked_up)
	# 成就判定
	if not EventBus.player_level_up.is_connected(_ach_on_level):
		EventBus.player_level_up.connect(_ach_on_level)
	if not EventBus.enemy_killed.is_connected(_ach_on_kill):
		EventBus.enemy_killed.connect(_ach_on_kill)
	if not EventBus.game_time_updated.is_connected(_ach_on_time):
		EventBus.game_time_updated.connect(_ach_on_time)
	if not EventBus.super_weapon_synthesized.is_connected(_ach_on_super):
		EventBus.super_weapon_synthesized.connect(_ach_on_super)
	# 剑圣·剑气纵横（击杀触发）
	if not EventBus.enemy_killed.is_connected(_on_kill_sword):
		EventBus.enemy_killed.connect(_on_kill_sword)

	# 镜头史诗缩放
	if not EventBus.super_weapon_synthesized.is_connected(_on_epic_moment):
		EventBus.super_weapon_synthesized.connect(_on_epic_moment)
	if not EventBus.boss_killed.is_connected(_on_boss_killed_epic):
		EventBus.boss_killed.connect(_on_boss_killed_epic)

	# 给初始武器
	_grant_starting_weapon()

	EventBus.game_started.emit()


func _setup_pools() -> void:
	# 投射物对象池（pool 挂 Main 下 → PAUSABLE，暂停时一并冻结）
	if get_tree().get_first_node_in_group("projectile_pool"):
		return
	var pp := ObjectPool.new()
	pp.scene = load("res://scenes/weapons/magic_bolt_projectile.tscn")
	pp.initial_size = 64
	pp.max_size = 500
	pp.add_to_group("projectile_pool")
	add_child(pp)


func _setup_joystick() -> void:
	if get_tree().get_first_node_in_group("joystick"):
		return
	var vj = load("res://scripts/ui/virtual_joystick.gd").new()
	add_child(vj)


func _setup_cheat() -> void:
	if get_tree().get_first_node_in_group("cheat"):
		return
	var cm = load("res://scripts/ui/cheat_menu.gd").new()
	add_child(cm)


func _grant_starting_weapon() -> void:
	# 按角色给初始武器
	var wid := "magic_bolt"
	match GameState.current_character:
		"argo": wid = "sword_orbit"
		"selene": wid = "piercing_arrow"
		"little_fried_egg": wid = "lava_zone"
		_: wid = "magic_bolt"
	var path := "res://scenes/weapons/%s.tscn" % wid
	if ResourceLoader.exists(path):
		var weapon = load(path).instantiate()
		player.add_child(weapon)
		GameState.active_weapons[wid] = 1
	GameState.apply_character_passive()


func _spawn_boss() -> void:
	_boss_spawned = true
	EventBus.boss_spawned.emit()
	EventBus.screen_shake_requested.emit(12.0, 0.5)

	# BOSS降临音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_boss_spawn()

	# BOSS降临大字提示
	_show_boss_title()

	var boss_scene = load("res://scenes/enemies/boss_shadow_lord.tscn")
	if boss_scene:
		var boss = boss_scene.instantiate()
		boss.global_position = player.global_position + Vector2(200, 0)
		add_child(boss)
	EventBus.boss_countdown_tick.emit(0)


func _show_boss_title() -> void:
	var title = Label.new()
	title.text = "👑 暗影领主降临！"
	title.add_theme_font_size_override("font_size", 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 60
	title.modulate = Color(1, 1, 1, 0)
	title.z_index = 100
	add_child(title)

	var t = create_tween()
	t.tween_property(title, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.0)
	t.tween_property(title, "modulate:a", 0.0, 0.5)
	t.tween_callback(title.queue_free)


func _on_boss_phase(phase: int) -> void:
	match phase:
		2: _show_phase_title("💀 深渊觉醒！")
		3: _show_phase_title("🔥 末日审判！")


func _show_phase_title(text: String) -> void:
	var title = Label.new()
	title.text = text
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.modulate = Color(1, 0.3, 0.3, 0)
	title.z_index = 100
	add_child(title)
	var t = create_tween()
	t.tween_property(title, "modulate:a", 1.0, 0.3)
	t.tween_interval(1.5)
	t.tween_property(title, "modulate:a", 0.0, 0.5)
	t.tween_callback(title.queue_free)


# ─── 限时增益 Buff ───

func _update_buffs(delta: float) -> void:
	if GameState.active_buffs.is_empty():
		return
	for id in GameState.active_buffs.keys():
		GameState.active_buffs[id] -= delta
		if GameState.active_buffs[id] <= 0.0:
			GameState.active_buffs.erase(id)
			_clear_buff(id)


func _clear_buff(id: String) -> void:
	match id:
		"buff_damage": GameState.damage_buff_mult = 1.0
		"buff_speed": GameState.speed_buff_mult = 1.0
		"buff_exp": GameState.exp_buff_mult = 1.0
		"invincible": GameState.invincible_buff = false


func _on_item_picked_up(item_type: String, _data: Dictionary) -> void:
	match item_type:
		"buff_damage":
			GameState.damage_buff_mult = 1.5
			GameState.active_buffs["buff_damage"] = 8.0
		"buff_speed":
			GameState.speed_buff_mult = 1.4
			GameState.active_buffs["buff_speed"] = 8.0
		"buff_exp":
			GameState.exp_buff_mult = 2.0
			GameState.active_buffs["buff_exp"] = 10.0
		"invincible":
			GameState.invincible_buff = true
			GameState.active_buffs["invincible"] = 5.0
		"magnet":
			_magnet_all_gems()
		"clear_bomb":
			_clear_all_enemies()


func _magnet_all_gems() -> void:
	for gem in get_tree().get_nodes_in_group("gem"):
		if is_instance_valid(gem) and gem.has_method("enable_magnet"):
			gem.enable_magnet(player)


func _clear_all_enemies() -> void:
	EventBus.screen_shake_requested.emit(6.0, 0.2)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(500.0)


# ─── 成就判定 ───

func _ach(id: String) -> void:
	if SaveSystem.unlock_achievement(id):
		EventBus.achievement_unlocked.emit(id)


func _ach_on_level(_lv: int) -> void:
	_ach("first_level")


func _ach_on_kill(_t, _p, _e, _g) -> void:
	if GameState.kills >= 1000:
		_ach("kill_1000")
	elif GameState.kills >= 500:
		_ach("kill_500")
	elif GameState.kills >= 100:
		_ach("kill_100")


func _ach_on_time(s: float) -> void:
	if s >= 900.0:
		_ach("survive_15min")
	elif s >= 300.0:
		_ach("survive_5min")


func _ach_on_super(_n) -> void:
	_ach("first_super")


# ─── 剑圣·剑气纵横：近战击杀 10% 概率释放 360° 剑气 ───

func _on_kill_sword(_t, _pos, _e, _g) -> void:
	if _sword_wave_active or GameState.current_character != "argo":
		return
	if GameState.rng.randf() >= 0.10:
		return
	_sword_wave_active = true
	_sword_wave()
	_sword_wave_active = false


func _sword_wave() -> void:
	if not is_instance_valid(player):
		return
	EventBus.screen_shake_requested.emit(3.0, 0.1)
	var center: Vector2 = player.global_position
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(enemy) and center.distance_to(enemy.global_position) < 160.0:
			if enemy.has_method("take_damage"):
				enemy.take_damage(30.0)
	var ring := Sprite2D.new()
	ring.texture = _make_wave_tex()
	ring.global_position = center
	ring.modulate = Color(0.8, 0.95, 1.0, 0.85)
	get_tree().current_scene.add_child(ring)
	var t := create_tween()
	t.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.3)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	t.tween_callback(ring.queue_free)


static var _wave_tex: ImageTexture = null

func _make_wave_tex() -> Texture2D:
	if _wave_tex:
		return _wave_tex
	var size := 100
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := size / 2
	for x in range(size):
		for y in range(size):
			var d := Vector2(x - c, y - c).length()
			if d <= c - 1 and d >= c - 6:
				img.set_pixel(x, y, Color(0.85, 0.95, 1.0, 0.9))
	_wave_tex = ImageTexture.create_from_image(img)
	return _wave_tex


func _on_boss_killed() -> void:
	SaveSystem.unlock_character("argo")  # 击杀 BOSS 解锁剑圣
	_ach("kill_boss")

	# Mega-Evolution：25% 概率掉落融合宝箱（无尽模式也适用）
	if GameState.super_weapons.size() >= 2 and GameState.rng.randf() < 0.25:
		_drop_mega_chest()

	# 关卡模式：击杀 BOSS 即胜利（无尽模式继续生存）
	if _game_ended:
		return
	if GameState.current_mode == "level":
		_game_victory()


func _drop_mega_chest() -> void:
	"""掉落融合宝箱，拾取后开放 Mega-Evolution"""
	var chest := Sprite2D.new()
	var tex := _make_chest_tex()
	chest.texture = tex
	chest.global_position = player.global_position + Vector2(randf_range(-60, 60), randf_range(-60, 60))
	chest.z_index = 10
	get_tree().current_scene.add_child(chest)

	# 拾取范围
	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	shape.shape = circle
	area.add_child(shape)
	chest.add_child(area)

	# 闪烁提示
	var flash := create_tween().set_loops()
	flash.tween_property(chest, "modulate:a", 0.5, 0.4)
	flash.tween_property(chest, "modulate:a", 1.0, 0.4)

	# 检测玩家靠近拾取
	var check := create_tween().set_loops()
	check.tween_interval(0.2)
	check.tween_callback(func():
		if not is_instance_valid(chest):
			return
		if chest.global_position.distance_to(player.global_position) < 40.0:
			flash.kill()
			chest.queue_free()
			GameState.mega_evolution_available = true
			# 大字提示
			_show_mega_hint()
	)

	# 30 秒后消失
	var die := create_tween()
	die.tween_interval(30.0)
	die.tween_callback(chest.queue_free)


func _show_mega_hint() -> void:
	var label := Label.new()
	label.text = "🌀 融合之力！下一轮升级触发双重超武！"
	label.add_theme_font_size_override("font_size", 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = 120
	label.modulate = Color(0.8, 0.5, 1.0, 0)
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	var t := create_tween()
	t.tween_property(label, "modulate:a", 1.0, 0.3)
	t.tween_interval(3.0)
	t.tween_property(label, "modulate:a", 0.0, 0.5)
	t.tween_callback(label.queue_free)


static var _chest_tex: ImageTexture = null

func _make_chest_tex() -> Texture2D:
	if _chest_tex:
		return _chest_tex
	var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 画一个简单宝箱: 金色方块 + 紫色光芒
	for x in range(4, 20):
		for y in range(6, 20):
			img.set_pixel(x, y, Color(1.0, 0.85, 0.2, 1.0))
	for x in range(8, 16):
		for y in range(3, 7):
			img.set_pixel(x, y, Color(0.8, 0.5, 1.0, 1.0))
	_chest_tex = ImageTexture.create_from_image(img)
	return _chest_tex


func _game_victory() -> void:
	_game_ended = true
	GameState.is_game_over = true
	# 胜利音效
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_sfx_victory()
	var stats = {
		"kills": GameState.kills,
		"survival_time": _total_game_time,
		"gold": GameState.gold_earned,
		"level": GameState.player_level,
		"reason": "victory"
	}
	SaveSystem.add_game_result(GameState.gold_earned, GameState.kills, _total_game_time)
	EventBus.game_over.emit("victory", stats)


func _game_defeat() -> void:
	_game_ended = true
	GameState.is_game_over = true
	var stats = {
		"kills": GameState.kills,
		"survival_time": _total_game_time,
		"gold": GameState.gold_earned,
		"level": GameState.player_level,
		"reason": "death"
	}
	SaveSystem.add_game_result(GameState.gold_earned, GameState.kills, _total_game_time)
	EventBus.game_over.emit("death", stats)


func _on_player_died() -> void:
	if GameState.revive_count < GameState.max_revive_count:
		_show_revive_prompt()
	else:
		_game_defeat()


func _show_revive_prompt() -> void:
	GameState.revive_count += 1
	# 先恢复血量/状态，再广播，确保 HUD 刷到正确值
	player.current_health = player.max_health * 0.5
	player.is_dead = false
	player.state = Player.PlayerState.NORMAL
	if player.collision_shape:
		player.collision_shape.set_deferred("disabled", false)
	Engine.time_scale = 1.0   # 取消死亡慢动作残留
	EventBus.player_revived.emit()


func request_exit_game() -> void:
	#
	var penalty = _calculate_exit_penalty()
	EventBus.player_exited_early.emit(_total_game_time, penalty)
	_game_ended = true
	GameState.is_game_over = true


func _calculate_exit_penalty() -> Dictionary:
	var t = _total_game_time
	var penalty = {"exp_pct": 1.0, "gold_pct": 1.0, "score_pct": 1.0}

	if t < 60:
		penalty = {"exp_pct": 0.0, "gold_pct": 0.0, "score_pct": 0.0}
	elif t < 180:
		penalty = {"exp_pct": 0.5, "gold_pct": 0.3, "score_pct": 0.3}
	elif t < 300:
		penalty = {"exp_pct": 0.7, "gold_pct": 0.5, "score_pct": 0.5}
	elif t < 600:
		penalty = {"exp_pct": 0.85, "gold_pct": 0.7, "score_pct": 0.7}

	return penalty


func _on_game_paused() -> void:
	GameState.is_paused = true


func _on_game_resumed() -> void:
	GameState.is_paused = false


# ─── 工具 ───

func _get_screen_center() -> Vector2:
	return camera.global_position


func _get_viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


# ─── 震屏 ───

func _on_screen_shake(amplitude: float, duration: float) -> void:
	if not SaveSystem.get_setting("screen_shake"):
		return
	# 比较当前实际振幅（考虑衰减），而非原始振幅
	var current_amplitude: float = _shake_amplitude * (_shake_duration / max(_shake_duration + 0.01, 0.01)) if _shake_duration > 0 else 0.0
	if amplitude <= current_amplitude:
		return  # 不强于当前实际震动则忽略
	_shake_amplitude = amplitude
	_shake_duration = duration
	_shake_priority = amplitude
	_camera_original_pos = camera.position


func _spawn_ambient_stars(delta: float) -> void:
	if not SaveSystem.get_setting("particles"):
		return
	_star_timer += delta
	if _star_timer < 1.2:
		return
	_star_timer = 0.0
	var cam_pos = camera.global_position if camera else Vector2.ZERO
	var vs = get_viewport().get_visible_rect().size
	for i in range(3):
		var pos = cam_pos + Vector2(
			randf_range(-vs.x * 0.7, vs.x * 0.7),
			randf_range(-vs.y * 0.5, -vs.y * 0.3)
		)
		var star = ColorRect.new()
		star.color = Color(0.6, 0.8, 1.0, randf_range(0.3, 0.7))
		star.size = Vector2(2, 2)
		star.pivot_offset = Vector2(1, 1)
		get_tree().current_scene.add_child(star)
		star.global_position = pos
		var t = create_tween()
		var d = randf_range(3.0, 6.0)
		t.tween_property(star, "global_position:y", pos.y + randf_range(200, 400), d)
		t.parallel().tween_property(star, "color:a", 0.0, d)
		t.tween_callback(star.queue_free)


func _update_screen_shake(delta: float) -> void:
	if _shake_duration <= 0:
		camera.position = _camera_original_pos
		return
	_shake_duration -= delta
	var decay = _shake_duration / max(_shake_duration + 0.01, 0.01)
	camera.position = _camera_original_pos + Vector2(
		randf_range(-_shake_amplitude, _shake_amplitude) * decay,
		randf_range(-_shake_amplitude, _shake_amplitude) * decay
	)
	if _shake_duration <= 0:
		camera.position = _camera_original_pos
		_shake_amplitude = 0.0


# ─── 动态视场收缩 ───

func _update_camera_zoom(delta: float) -> void:
	if not camera:
		return

	# Epic zoom-in 优先
	if _epic_zoom_active:
		_epic_zoom_timer -= delta
		var t = clamp(1.0 - (_epic_zoom_timer / 0.7), 0.0, 1.0)  # 0→1 over 0.7s
		if _epic_zoom_timer <= 0:
			# 拉近阶段结束 → 开始平滑恢复
			_epic_zoom_active = false
			_target_zoom = CAMERA_ZOOM_DEFAULT
		else:
			# 0.7s 内快速拉近到 1.15x
			_target_zoom = lerpf(CAMERA_ZOOM_DEFAULT, CAMERA_ZOOM_EPIC_IN, t)
	else:
		# 根据敌人数量和玩家速度计算呼吸缩放
		var enemy_count = enemy_spawner.get_enemy_count()
		var move_factor = 0.0
		if is_instance_valid(player) and player is CharacterBody2D:
			var spd = player.velocity.length()
			var max_speed = GameState.get_effective_move_speed() * 1.5
			move_factor = clamp(spd / max(max_speed, 0.01), 0.0, 1.0)

		# 同屏怪 > 50 开始拉远，最高拉远到 0.85x
		var crowd_factor = clamp((enemy_count - 50) / 350.0, 0.0, 1.0)
		var zoom_factor = move_factor * 0.4 + crowd_factor * 0.6  # crowd 权重更大
		_target_zoom = lerpf(CAMERA_ZOOM_DEFAULT, CAMERA_ZOOM_OUT_MAX, zoom_factor)

	# 平滑插值
	var current = camera.zoom.x  # assume uniform zoom
	var new_zoom = lerpf(current, _target_zoom, delta * CAMERA_ZOOM_SMOOTH)
	camera.zoom = Vector2(new_zoom, new_zoom)


func _on_epic_moment(_name: String = "") -> void:
	"""超武合成 / BOSS击杀 → 史诗拉近"""
	_epic_zoom_active = true
	_epic_zoom_timer = 0.7
	_target_zoom = CAMERA_ZOOM_EPIC_IN
	EventBus.screen_shake_requested.emit(10.0, 0.3)


func _on_boss_killed_epic() -> void:
	"""BOSS 击杀时不触发震屏（_on_boss_killed 已发），仅镜头拉近"""
	_epic_zoom_active = true
	_epic_zoom_timer = 0.7
	_target_zoom = CAMERA_ZOOM_EPIC_IN


# ─── 信号连接 ───

# 注：ESC 暂停切换已移至 PauseMenu._input（ALWAYS 节点），Main 不再处理，
# 以保持 Main 为 PAUSABLE → 暂停时子节点（玩家/敌人/子弹）真正冻结。


func _pause_game() -> void:
	_on_game_paused()
	get_tree().paused = true
	EventBus.game_paused.emit()


func _resume_game() -> void:
	_on_game_resumed()
	get_tree().paused = false
	EventBus.game_resumed.emit()
