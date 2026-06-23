# AudioManager - 音频管理器
# 管理 BGM / SFX / UI / 环境音效四层音频
# 当前Phase1：所有音频文件占位，不播放实际声音，避免报错
extends Node

# 音量设置
var master_volume: float = 1.0
var bgm_volume: float = 0.8
var sfx_volume: float = 1.0
var ui_volume: float = 0.8
var ambient_volume: float = 0.6

# 播放器节点
var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var ui_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

# 音效变体计数器（用于轮换播放）
var sfx_variant_counters: Dictionary = {}


func _ready() -> void:
	_create_audio_players()


func _create_audio_players() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	add_child(bgm_player)

	for i in range(4):
		var p = AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)

	ui_player = AudioStreamPlayer.new()
	ui_player.bus = "Master"
	add_child(ui_player)

	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Master"
	add_child(ambient_player)


# ─── BGM ───

func play_bgm(_bgm_name: String) -> void:
	# Phase2: 替换为实际BGM文件
	pass


func stop_bgm() -> void:
	bgm_player.stop()


# ─── SFX ───

func play_sfx(_sfx_name: String) -> void:
	# Phase2: 替换为实际SFX文件
	pass


# ─── UI 音效 ───

func play_ui(_ui_sound: String) -> void:
	# Phase2: 替换为实际UI音效
	pass


# ─── 环境音效 ───

func play_ambient(_ambient_name: String) -> void:
	# Phase2: 替换为实际环境音效
	pass


func stop_ambient() -> void:
	ambient_player.stop()


# ─── 工具方法 ───

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
