# 地图缩小 + 小地图 + 怪物卡住修复 + 新角色小煎蛋 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 缩小地图并添加边界碰撞、添加小地图显示怪物和玩家位置、修复怪物卡住问题、新增角色"小煎蛋"（武器：岩浆）

**Architecture:** 地图从当前的无限大（MAP_RADIUS=1500 但无碰撞边界）缩小到合理尺寸并添加物理边界。小地图作为 HUD 子节点实时绘制。怪物卡住通过添加边界回弹和密度检测解决。新角色通过 CharacterBody2D + Area2D 岩浆区域实现。

**Tech Stack:** Godot 4.7 + GDScript，现有代码架构

---

## 文件结构

| 操作 | 文件 |
|------|------|
| 修改 | `scripts/managers/main.gd` — 缩小 MAP_RADIUS、添加边界碰撞 |
| 修改 | `scripts/enemies/base_enemy.gd` — 修复卡住逻辑 |
| 修改 | `scripts/enemies/enemy_spawner.gd` — 调整生成范围适配新地图 |
| 修改 | `scripts/managers/game_state.gd` — 添加新角色数据 |
| 修改 | `scripts/ui/main_menu.gd` — 添加新角色选择 |
| 创建 | `scripts/ui/minimap.gd` — 小地图 UI |
| 创建 | `scenes/weapons/lava_zone.tscn` — 岩浆武器场景 |
| 创建 | `scripts/weapons/lava_zone.gd` — 岩浆武器逻辑 |
| 创建 | `scenes/player/little_fried_egg.tscn` — 小煎蛋角色 |
| 创建 | `scripts/player/little_fried_egg.gd` — 小煎蛋专属逻辑 |

---

## Task 1: 缩小地图 + 添加边界碰撞

**Files:**
- Modify: `scripts/managers/main.gd:41,79-131`

- [ ] **Step 1: 修改 MAP_RADIUS 常量**

```gdscript
# main.gd:41
const MAP_RADIUS: float = 800.0  # 从 1500 缩小到 800
```

- [ ] **Step 2: 添加边界 StaticBody2D**

在 `main.gd` 的 `_ready()` 中，`_start_game()` 调用之后添加：

```gdscript
# main.gd _ready() 末尾添加
func _setup_boundary() -> void:
    # 添加圆形边界碰撞体
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

func _ready() -> void:
    _setup_pools()
    _setup_joystick()
    _setup_cheat()
    _setup_glow()
    _setup_boundary()  # 新增
    _start_game()
```

- [ ] **Step 3: 运行验证**

启动游戏，确认玩家和敌人无法走出圆形边界。

---

## Task 2: 修复怪物卡住问题

**Files:**
- Modify: `scripts/enemies/base_enemy.gd:119-138`

- [ ] **Step 1: 在 _handle_movement 中添加边界回弹**

```gdscript
# base_enemy.gd，在 _handle_movement 函数末尾、move_and_slide() 之前添加边界限制
func _handle_movement(delta: float) -> void:
    var p = _get_player()
    if not p:
        return

    var to_player = global_position.direction_to(p.global_position)
    var dist = global_position.distance_to(p.global_position)

    if is_ranged:
        _handle_ranged(delta, p, to_player, dist)
        return

    match move_pattern:
        MovePattern.STRAIGHT:
            _chase_straight(to_player)
        MovePattern.SINE:
            _chase_sine(delta, to_player)
        MovePattern.CHARGE:
            _chase_charge(delta, to_player)

    # 边界回弹：接近边界时修正速度方向
    _clamp_to_boundary()

func _clamp_to_boundary() -> void:
    var boundary_radius: float = 780.0  # 略小于 MAP_RADIUS
    var dist = global_position.length()
    if dist > boundary_radius:
        # 推向中心
        var push_dir = -global_position.normalized()
        velocity += push_dir * move_speed * 2.0
```

- [ ] **Step 2: 在 _physics_process 中移动后添加边界修正**

```gdscript
# base_enemy.gd 的 _physics_process 中，CHASING 分支的 move_and_slide() 之后添加
func _physics_process(delta: float) -> void:
    _process_dot(delta)
    match state:
        EnemyState.SPAWNING:
            pass
        EnemyState.CHASING:
            _handle_movement(delta)
            move_and_slide()
            _check_contact_damage(delta)
            _clamp_to_boundary_after_slide()  # 新增
            if "summon" in extra_affixes:
                _summon_timer += delta
                if _summon_timer >= 10.0:
                    _summon_timer = 0.0
                    _summon_minion()
        # ... 其他状态不变

func _clamp_to_boundary_after_slide() -> void:
    var boundary_radius: float = 780.0
    var dist = global_position.length()
    if dist > boundary_radius:
        global_position = global_position.normalized() * boundary_radius
```

- [ ] **Step 3: 运行验证**

放置大量敌人，确认不再卡在边界或相互堆叠。

---

## Task 3: 调整敌人生成范围适配新地图

**Files:**
- Modify: `scripts/enemies/enemy_spawner.gd:10,226-230`

- [ ] **Step 1: 修改生成范围和生成距离**

```gdscript
# enemy_spawner.gd:10
@export var spawn_bounds: Rect2 = Rect2(-800, -800, 1600, 1600)

# enemy_spawner.gd _get_spawn_position() 函数
func _get_spawn_position() -> Vector2:
    var cam_pos = _get_camera_position()
    var angle = GameState.rng.randf() * TAU
    var dist = 500 + GameState.rng.randf() * 200  # 缩小生成距离
    var pos = cam_pos + Vector2(cos(angle), sin(angle)) * dist
    # 确保生成在地图边界内
    var boundary = 700.0
    if pos.length() > boundary:
        pos = pos.normalized() * boundary
    return pos
```

- [ ] **Step 2: 运行验证**

启动游戏，确认敌人在可见范围内生成且不会在地图外生成。

---

## Task 4: 创建小地图 UI

**Files:**
- Create: `scripts/ui/minimap.gd`

- [ ] **Step 1: 创建小地图脚本**

```gdscript
# scripts/ui/minimap.gd
extends Control

const MINIMAP_SIZE := Vector2(160, 160)
const MAP_RADIUS := 800.0
const DOT_PLAYER_SIZE := 6.0
const DOT_ENEMY_SIZE := 3.0
const DOT_COLOR_PLAYER := Color(0.2, 0.8, 1.0)
const DOT_COLOR_ENEMY := Color(1.0, 0.3, 0.3)
const DOT_COLOR_BOSS := Color(1.0, 0.0, 0.5)
const BG_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const BORDER_COLOR := Color(0.3, 0.5, 0.3, 0.8)

var _player_node: Node2D = null
var _texture_rect: TextureRect


func _ready() -> void:
    # 定位在右上角
    set_anchors_preset(Control.PRESET_TOP_RIGHT)
    offset_left = -MINIMAP_SIZE.x - 10
    offset_top = 10
    offset_right = -10
    offset_bottom = MINIMAP_SIZE.y + 10
    custom_minimum_size = MINIMAP_SIZE
    mouse_filter = Control.MOUSE_FILTER_IGNORE

    # 背景
    var bg = ColorRect.new()
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    bg.color = BG_COLOR
    add_child(bg)

    # 绘制区域
    _texture_rect = TextureRect.new()
    _texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
    _texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
    add_child(_texture_rect)


func _process(_delta: float) -> void:
    queue_redraw()


func _draw() -> void:
    var center = MINIMAP_SIZE / 2.0
    var map_scale = MINIMAP_SIZE.x / (MAP_RADIUS * 2.0)

    # 绘制地图背景圆
    draw_circle(center, MINIMAP_SIZE.x / 2.0, BG_COLOR)
    draw_arc(center, MINIMAP_SIZE.x / 2.0 - 1, 0, TAU, 64, BORDER_COLOR, 1.5)

    # 获取玩家位置
    var players = get_tree().get_nodes_in_group("player")
    if players.size() == 0:
        return
    _player_node = players[0]

    # 绘制敌人
    var enemies = get_tree().get_nodes_in_group("enemy")
    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue
        var world_pos = enemy.global_position
        var minimap_pos = center + world_pos * map_scale
        # 检查是否在小地图范围内
        if minimap_pos.distance_to(center) > MINIMAP_SIZE.x / 2.0 - 3:
            continue
        var color = DOT_COLOR_ENEMY
        if "boss" in enemy.name.to_lower():
            color = DOT_COLOR_BOSS
            draw_circle(minimap_pos, DOT_ENEMY_SIZE + 1, color)
        draw_circle(minimap_pos, DOT_ENEMY_SIZE, color)

    # 绘制玩家（最后绘制，确保在最上层）
    var player_map_pos = center + _player_node.global_position * map_scale
    draw_circle(player_map_pos, DOT_PLAYER_SIZE, DOT_COLOR_PLAYER)
    # 玩家发光效果
    draw_circle(player_map_pos, DOT_PLAYER_SIZE + 2, Color(DOT_COLOR_PLAYER.r, DOT_COLOR_PLAYER.g, DOT_COLOR_PLAYER.b, 0.3))
```

- [ ] **Step 2: 运行验证**

启动游戏，确认右上角显示小地图，玩家和敌人位置实时更新。

---

## Task 5: 将小地图集成到 HUD

**Files:**
- Modify: `scripts/ui/hud.gd`

- [ ] **Step 1: 在 HUD._ready 中添加小地图**

```gdscript
# 在 hud.gd 的 _create_ui() 或 _ready() 末尾添加
func _add_minimap() -> void:
    var minimap_script = load("res://scripts/ui/minimap.gd")
    if minimap_script:
        var minimap = Control.new()
        minimap.set_script(minimap_script)
        add_child(minimap)

# 在 _ready() 或 _create_ui() 中调用
func _ready() -> void:
    _create_ui()
    _add_minimap()  # 新增
```

- [ ] **Step 2: 运行验证**

启动游戏，确认小地图随 HUD 一起显示。

---

## Task 6: 新增角色"小煎蛋"

**Files:**
- Modify: `scripts/managers/game_state.gd:95,224-229`
- Modify: `scripts/managers/main.gd:265-277`
- Modify: `scripts/ui/main_menu.gd:64`

- [ ] **Step 1: 在 GameState 中添加角色数据**

```gdscript
# game_state.gd:95
var unlocked_characters: Array = ["mage", "little_fried_egg"]  # 新增小煎蛋（初始可用）

# game_state.gd apply_character_passive() 末尾添加
func apply_character_passive() -> void:
    char_crit_bonus = 0.0
    if current_character == "selene":
        char_crit_bonus = 0.10
    elif current_character == "little_fried_egg":
        # 小煎蛋：岩浆伤害 +20%，灼烧持续时间翻倍
        pass
    recalc_stats()

# game_state.gd 添加新角色被动方法
func get_burn_duration_mult() -> float:
    if current_character == "little_fried_egg":
        return 2.0
    return 1.0
```

- [ ] **Step 2: 在 Main 中添加初始武器**

```gdscript
# main.gd _grant_starting_weapon() 修改
func _grant_starting_weapon() -> void:
    var wid := "magic_bolt"
    match GameState.current_character:
        "argo": wid = "sword_orbit"
        "selene": wid = "piercing_arrow"
        "little_fried_egg": wid = "lava_zone"  # 新增
        _: wid = "magic_bolt"
    var path := "res://scenes/weapons/%s.tscn" % wid
    if ResourceLoader.exists(path):
        var weapon = load(path).instantiate()
        player.add_child(weapon)
        GameState.active_weapons[wid] = 1
    GameState.apply_character_passive()
```

- [ ] **Step 3: 在主菜单中添加角色选择**

在 `main_menu.gd` 的 `_build_character()` 中添加小煎蛋选项。

- [ ] **Step 4: 运行验证**

启动游戏，选择小煎蛋角色，确认初始武器为岩浆区域。

---

## Task 7: 实现岩浆武器

**Files:**
- Create: `scripts/weapons/lava_zone.gd`
- Create: `scenes/weapons/lava_zone.tscn`

- [ ] **Step 1: 创建岩浆武器脚本**

```gdscript
# scripts/weapons/lava_zone.gd
extends Node2D

const WEAPON_ID := "lava_zone"
const BASE_DAMAGE := 8.0
const BASE_RADIUS := 100.0
const BASE_TICK_INTERVAL := 1.0
const BASE_DURATION := 3.0

var level: int = 1
var damage: float = BASE_DAMAGE
var radius: float = BASE_RADIUS
var tick_interval: float = BASE_TICK_INTERVAL
var duration: float = BASE_DURATION
var _tick_timer: float = 0.0
var _active_zones: Array[Area2D] = []
var _spawn_timer: float = 0.0
var _spawn_interval: float = 2.0


func _ready() -> void:
    add_to_group("weapon")
    _upgrade_stats()


func _process(delta: float) -> void:
    if GameState.is_paused:
        return

    _spawn_timer += delta
    if _spawn_timer >= _spawn_interval:
        _spawn_timer = 0.0
        _spawn_lava_zone()

    # 清理过期区域
    var to_remove: Array[Area2D] = []
    for zone in _active_zones:
        if not is_instance_valid(zone):
            to_remove.append(zone)
    for zone in to_remove:
        _active_zones.erase(zone)


func _spawn_lava_zone() -> void:
    var zone = Area2D.new()
    zone.collision_layer = 0
    zone.collision_mask = 4  # 敌人层

    # 碰撞形状
    var shape = CollisionShape2D.new()
    var circle = CircleShape2D.new()
    circle.radius = radius
    shape.shape = circle
    zone.add_child(shape)

    # 岩浆视觉效果
    var visual = Sprite2D.new()
    visual.texture = _make_lava_texture()
    visual.scale = Vector2(radius * 2.0 / 64.0, radius * 2.0 / 64.0)
    zone.add_child(visual)

    # 位置：玩家附近随机位置
    var player = get_tree().get_first_node_in_group("player")
    if player:
        var angle = randf() * TAU
        var dist = randf_range(0, radius * 0.5)
        zone.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * dist

    # 伤害区域检测
    var damage_timer = Timer.new()
    damage_timer.wait_time = tick_interval
    damage_timer.one_shot = false
    zone.add_child(damage_timer)

    var damaged_enemies: Dictionary = {}

    damage_timer.timeout.connect(func():
        var enemies = zone.get_overlapping_bodies()
        for enemy in enemies:
            if enemy.has_method("take_damage"):
                var burn_mult = GameState.get_burn_duration_mult()
                enemy.take_damage(damage)
                if enemy.has_method("apply_dot"):
                    enemy.apply_dot(damage * 0.5, 2.0 * burn_mult)
    )

    zone.body_entered.connect(func(body):
        if body.has_method("take_damage"):
            body.take_damage(damage * 0.5)
    )

    get_tree().current_scene.add_child(zone)
    _active_zones.append(zone)
    damage_timer.start()

    # 定时销毁
    var t = create_tween()
    t.tween_interval(duration)
    t.tween_callback(func():
        if is_instance_valid(zone):
            zone.queue_free()
        if damage_timer:
            damage_timer.stop()
    )


func _make_lava_texture() -> Texture2D:
    var size := 64
    var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
    var center = size / 2.0
    for x in range(size):
        for y in range(size):
            var d = Vector2(x - center, y - center).length()
            if d < center:
                var t = d / center
                var r = lerpf(1.0, 0.8, t)
                var g = lerpf(0.4, 0.1, t)
                var b = lerpf(0.0, 0.0, t)
                var a = lerpf(0.9, 0.3, t)
                img.set_pixel(x, y, Color(r, g, b, a))
    return ImageTexture.create_from_image(img)


func upgrade() -> void:
    level += 1
    _upgrade_stats()


func _upgrade_stats() -> void:
    match level:
        1: damage = BASE_DAMAGE; radius = BASE_RADIUS; duration = BASE_DURATION
        2: damage = 12; radius = 110; duration = 3.5
        3: damage = 16; radius = 120; tick_interval = 0.8; duration = 4.0
        4: damage = 20; radius = 130; _spawn_interval = 1.8
        5: damage = 25; radius = 140; tick_interval = 0.7; duration = 4.5
        6: damage = 30; radius = 150; _spawn_interval = 1.5
        7: damage = 35; radius = 160; tick_interval = 0.6; duration = 5.0
        8: damage = 45; radius = 180; tick_interval = 0.5; _spawn_interval = 1.0  # 超武形态
```

- [ ] **Step 2: 创建岩浆武器场景**

创建 `scenes/weapons/lava_zone.tscn`，包含 Node2D 根节点和 lava_zone.gd 脚本。

- [ ] **Step 3: 运行验证**

选择小煎蛋角色，确认岩浆区域正确生成并对敌人造成伤害。

---

## Task 8: 创建小煎蛋角色场景

**Files:**
- Create: `scenes/player/little_fried_egg.tscn`

- [ ] **Step 1: 创建角色场景**

基于现有玩家场景，使用橙黄色配色方案。

- [ ] **Step 2: 在角色选择中集成**

确保主菜单和游戏逻辑中正确加载小煎蛋角色。

---

## 验证清单

- [ ] 地图缩小到 800 半径，有物理边界
- [ ] 小地图在右上角显示玩家和敌人位置
- [ ] 怪物不再卡在边界或相互堆叠
- [ ] 新角色"小煎蛋"可选择，初始武器为岩浆
- [ ] 岩浆武器正确造成持续伤害和灼烧效果
- [ ] 所有现有功能不受影响

