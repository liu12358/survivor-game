# LavaZone - 岩浆武器
# 小煎蛋专属，在地面生成持续伤害区域
extends "res://scripts/weapons/base_weapon.gd"

const BASE_DAMAGE := 8.0
const BASE_RADIUS := 100.0
const BASE_TICK_INTERVAL := 1.0
const BASE_DURATION := 3.0

var damage: float = BASE_DAMAGE
var radius: float = BASE_RADIUS
var tick_interval: float = BASE_TICK_INTERVAL
var duration: float = BASE_DURATION
var _tick_timer: float = 0.0
var _active_zones: Array[Area2D] = []
var _spawn_timer: float = 0.0
var _spawn_interval: float = 2.0


func _initialize() -> void:
	weapon_id = "lava_zone"
	weapon_name = "岩浆"
	base_damage = BASE_DAMAGE
	max_level = 8


func _requires_target() -> bool:
	return false  # AOE 地面区域，无需目标


func _ready() -> void:
	super._ready()
	add_to_group("weapon")
	_upgrade_stats()


# 岩浆武器使用自定义生成逻辑，不走基类的 attack_timer
func _process(delta: float) -> void:
	if GameState.is_paused or GameState.is_game_over:
		return

	_spawn_timer += delta
	if _spawn_timer >= _spawn_interval / attack_speed:
		_spawn_timer = 0.0
		_spawn_lava_zone()

	var to_remove: Array[Area2D] = []
	for zone in _active_zones:
		if not is_instance_valid(zone):
			to_remove.append(zone)
	for zone in to_remove:
		_active_zones.erase(zone)


func _spawn_lava_zone() -> void:
	var zone = Area2D.new()
	zone.collision_layer = 0
	zone.collision_mask = 2  # enemy 层（敌人 collision_layer=2），原值 4 是 projectile 层导致永远命中不到敌人

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	zone.add_child(shape)

	var visual = Sprite2D.new()
	visual.texture = _make_lava_texture()
	visual.scale = Vector2(radius * 2.0 / 64.0, radius * 2.0 / 64.0)
	zone.add_child(visual)

	var player = get_tree().get_first_node_in_group("player")
	if player:
		var angle = randf() * TAU
		var dist = randf_range(0, radius * 0.5)
		zone.global_position = player.global_position + Vector2(cos(angle), sin(angle)) * dist

	var damage_timer = Timer.new()
	damage_timer.wait_time = tick_interval
	damage_timer.one_shot = false
	zone.add_child(damage_timer)

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

	var t = create_tween()
	t.tween_interval(duration)
	t.tween_callback(func():
		if is_instance_valid(zone):
			zone.queue_free()
		if damage_timer:
			damage_timer.stop()
	)


static var _lava_tex: ImageTexture = null

func _make_lava_texture() -> Texture2D:
	if _lava_tex:
		return _lava_tex
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
	_lava_tex = ImageTexture.create_from_image(img)
	return _lava_tex


func level_up() -> void:
	if level >= max_level:
		return
	level += 1
	_apply_level_stats()
	_upgrade_stats()
	_upgrade_flash()


func _apply_level_stats() -> void:
	# 同步 base_damage 供 get_damage_with_bonus() 使用
	match level:
		1: base_damage = BASE_DAMAGE
		2: base_damage = 12.0
		3: base_damage = 16.0
		4: base_damage = 20.0
		5: base_damage = 25.0
		6: base_damage = 30.0
		7: base_damage = 35.0
		8: base_damage = 45.0; is_super_weapon = true; super_weapon_name = "熔岩之心"


func _upgrade_stats() -> void:
	match level:
		1: damage = BASE_DAMAGE; radius = BASE_RADIUS; duration = BASE_DURATION
		2: damage = 12; radius = 110; duration = 3.5
		3: damage = 16; radius = 120; tick_interval = 0.8; duration = 4.0
		4: damage = 20; radius = 130; _spawn_interval = 1.8
		5: damage = 25; radius = 140; tick_interval = 0.7; duration = 4.5
		6: damage = 30; radius = 150; _spawn_interval = 1.5
		7: damage = 35; radius = 160; tick_interval = 0.6; duration = 5.0
		8: damage = 45; radius = 180; tick_interval = 0.5; _spawn_interval = 1.0
