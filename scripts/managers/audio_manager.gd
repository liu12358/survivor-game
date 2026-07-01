# AudioManager - 音频管理器
# 管理 BGM / SFX / UI / 环境音效四层音频
# 动态加载音效文件
extends Node

var master_volume: float = 1.0
var bgm_volume: float = 0.8
var sfx_volume: float = 1.0
var ui_volume: float = 0.8

var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var ui_player: AudioStreamPlayer

var _sfx_cache: Dictionary = {}
var _sfx_loaded: bool = false


func _ready() -> void:
	_setup_players()
	# 延迟加载音效，避免阻塞启动
	call_deferred("_preload_sfx")


func _setup_players() -> void:
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


func _preload_sfx() -> void:
	if _sfx_loaded:
		return
	_sfx_loaded = true

	_sfx_cache["hit"] = _load_audio_group("hit", 4)
	_sfx_cache["kill"] = _load_audio_group("kill", 2)
	_sfx_cache["pickup"] = _load_audio_group("pickup", 1)
	_sfx_cache["levelup"] = _load_audio_group("levelup", 1)
	_sfx_cache["ui_click"] = _load_audio_group("ui_click", 1)
	_sfx_cache["boss_spawn"] = _load_audio_group("boss_spawn", 1)
	_sfx_cache["shoot"] = _load_audio_group("shoot", 3)
	_sfx_cache["victory"] = _load_audio_group("victory", 1)


func _load_audio_group(prefix: String, count: int) -> Array:
	var result: Array = []
	for i in range(1, count + 1):
		var path := "res://assets/audio/sfx/%s_%02d.ogg" % [prefix, i]
		if ResourceLoader.exists(path):
			var res = load(path)
			if res:
				result.append(res)
	return result


# ─── SFX 播放 ───

func play_sfx_hit() -> void:
	_play_random_sfx("hit")

func play_sfx_kill() -> void:
	_play_random_sfx("kill")

func play_sfx_pickup() -> void:
	_play_random_sfx("pickup")

func play_sfx_levelup() -> void:
	_play_random_sfx("levelup")

func play_sfx_ui_click() -> void:
	_play_random_sfx("ui_click")

func play_sfx_boss_spawn() -> void:
	_play_random_sfx("boss_spawn")

func play_sfx_shoot() -> void:
	_play_random_sfx("shoot")

func play_sfx_victory() -> void:
	_play_random_sfx("victory")


func _play_random_sfx(sfx_type: String) -> void:
	if not SaveSystem.get_setting("sfx"):
		return
	var pool: Array = _sfx_cache.get(sfx_type, [])
	if pool.is_empty():
		return
	var stream = pool[randi() % pool.size()]
	_play_sfx_stream(stream)


func _play_sfx_stream(stream: AudioStream) -> void:
	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume)
			player.play()
			return


# ─── BGM ───

func play_bgm(_bgm_name: String) -> void:
	pass

func stop_bgm() -> void:
	bgm_player.stop()


# ─── 音量设置 ───

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)

func set_bgm_volume(v: float) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
