# Minimap - 小地图 UI
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
var _enemy_positions: Array[Vector2] = []
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.2


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_left = -MINIMAP_SIZE.x - 10
	offset_top = 10
	offset_right = -10
	offset_bottom = MINIMAP_SIZE.y + 10
	custom_minimum_size = MINIMAP_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	add_child(bg)


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_cache_positions()
	queue_redraw()


func _cache_positions() -> void:
	var players = get_tree().get_nodes_in_group("player")
	_player_node = players[0] if players.size() > 0 else null

	_enemy_positions.clear()
	var enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in enemies:
		if is_instance_valid(enemy):
			_enemy_positions.append(enemy.global_position)


func _draw() -> void:
	var center = MINIMAP_SIZE / 2.0
	var map_scale = MINIMAP_SIZE.x / (MAP_RADIUS * 2.0)

	draw_circle(center, MINIMAP_SIZE.x / 2.0, BG_COLOR)
	draw_arc(center, MINIMAP_SIZE.x / 2.0 - 1, 0, TAU, 64, BORDER_COLOR, 1.5)

	if not _player_node or not is_instance_valid(_player_node):
		return

	# 限制最多绘制100个敌人点，避免性能问题
	var max_draw := mini(_enemy_positions.size(), 100)
	var step := maxi(1, _enemy_positions.size() / max_draw)
	var idx := 0
	for i in range(0, _enemy_positions.size(), step):
		if idx >= max_draw:
			break
		var pos = _enemy_positions[i]
		var minimap_pos = center + pos * map_scale
		if minimap_pos.distance_to(center) > MINIMAP_SIZE.x / 2.0 - 3:
			continue
		draw_circle(minimap_pos, DOT_ENEMY_SIZE, DOT_COLOR_ENEMY)
		idx += 1

	var player_map_pos = center + _player_node.global_position * map_scale
	draw_circle(player_map_pos, DOT_PLAYER_SIZE, DOT_COLOR_PLAYER)
	draw_circle(player_map_pos, DOT_PLAYER_SIZE + 2, Color(DOT_COLOR_PLAYER.r, DOT_COLOR_PLAYER.g, DOT_COLOR_PLAYER.b, 0.3))
