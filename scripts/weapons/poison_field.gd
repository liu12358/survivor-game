# PoisonField - 毒雾区域（由毒雾武器生成的独立实体）
# 持续 duration 秒，每秒对范围内敌人造成 DOT（紫色、不暴击）
extends Node2D

var damage_per_sec: float = 3.0
var radius: float = 60.0
var duration: float = 3.0
var follow_player: bool = false
var target_group: String = "enemy"   # 目标组（武器毒雾=enemy；敌人死亡毒雾=player）

var _life: float = 0.0
var _tick: float = 0.0
var _visual: Sprite2D


func _ready() -> void:
	z_index = 1
	_visual = Sprite2D.new()
	_visual.texture = _make_cloud_tex()
	var s := radius / 60.0
	_visual.scale = Vector2(s, s)
	add_child(_visual)


func _process(delta: float) -> void:
	if GameState.is_paused or GameState.is_game_over:
		return
	_life += delta
	if _life >= duration:
		queue_free()
		return
	if follow_player:
		var ps := get_tree().get_nodes_in_group("player")
		if ps.size() > 0:
			global_position = ps[0].global_position
	_tick += delta
	if _tick >= 1.0:
		_tick -= 1.0
		_damage()


func _damage() -> void:
	var targets := get_tree().get_nodes_in_group(target_group)
	for e in targets:
		if not is_instance_valid(e):
			continue
		if global_position.distance_to(e.global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(damage_per_sec)
			EventBus.damage_number_requested.emit(e.global_position + Vector2(0, -12), damage_per_sec, false, 2)


func _make_cloud_tex() -> Texture2D:
	var size := 120
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := size / 2
	for x in range(size):
		for y in range(size):
			var d := Vector2(x - c, y - c).length()
			if d <= c - 1:
				var a := (1.0 - d / float(c)) * 0.35
				img.set_pixel(x, y, Color(0.4, 0.8, 0.2, a))
	return ImageTexture.create_from_image(img)
