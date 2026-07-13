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
# BGM 淡入淡出 tween 跟踪
var _bgm_fade_tween: Tween = null
# SFX 去重：记录每种音效最后一次播放的帧号
var _sfx_last_play: Dictionary = {}
# 需要去重的高频音效（同帧/相邻帧同类型不重复播放）
const _SFX_DEDUP_TYPES := ["hit", "kill", "pickup", "shoot"]


func _ready() -> void:
	_setup_players()
	# 从存档恢复并应用音量到总线
	apply_saved_volumes()
	# 延迟加载音效，避免阻塞启动
	call_deferred("_preload_sfx")


func _setup_players() -> void:
	# 创建独立的 BGM / SFX / UI 总线（若不存在），便于分别调节音量
	_ensure_bus("BGM")
	_ensure_bus("SFX")
	_ensure_bus("UI")

	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "BGM"
	add_child(bgm_player)

	for i in range(8):
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		sfx_players.append(p)

	ui_player = AudioStreamPlayer.new()
	ui_player.bus = "UI"
	add_child(ui_player)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


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
	# victory 实际位于 bgm 目录，单独加载（修正路径）
	_sfx_cache["victory"] = []
	var victory_path := "res://assets/audio/bgm/victory.ogg"
	if ResourceLoader.exists(victory_path):
		var v = load(victory_path)
		if v:
			_sfx_cache["victory"] = [v]


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
	# UI 点击音效走专用 ui_player，避免占用 sfx 池
	if not SaveSystem.get_setting("sfx"):
		return
	var pool: Array = _sfx_cache.get("ui_click", [])
	if pool.is_empty():
		return
	var stream = pool[GameState.rng.randi() % pool.size()]
	play_ui_sound(stream)

func play_sfx_boss_spawn() -> void:
	_play_random_sfx("boss_spawn")

func play_sfx_shoot() -> void:
	_play_random_sfx("shoot")

func play_sfx_victory() -> void:
	_play_random_sfx("victory")

# 暂复用已有音效池，未来可替换为独立音效
func play_sfx_boss_die() -> void:
	_play_random_sfx("kill")

func play_sfx_player_hurt() -> void:
	_play_random_sfx("hit")


func play_sfx_shield_gate() -> void:
	_play_random_sfx("hit")  # 暂复用 hit 音效，未来可替换为独立音效

func play_sfx_player_die() -> void:
	_play_random_sfx("kill")

func play_sfx_super_weapon() -> void:
	_play_random_sfx("levelup")


func _play_random_sfx(sfx_type: String) -> void:
	if not SaveSystem.get_setting("sfx"):
		return
	# 高频音效去重：同帧或相邻帧同类型不重复播放
	if _SFX_DEDUP_TYPES.has(sfx_type):
		var frame := Engine.get_process_frames()
		if frame - int(_sfx_last_play.get(sfx_type, -999)) < 2:
			return
		_sfx_last_play[sfx_type] = frame
	var pool: Array = _sfx_cache.get(sfx_type, [])
	if pool.is_empty():
		return
	# 使用 GameState.rng 保证种子可复现，不破坏全局随机序列
	var stream = pool[GameState.rng.randi() % pool.size()]
	_play_sfx_stream(stream)


func _play_sfx_stream(stream: AudioStream) -> void:
	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume)
			# 音调随机微变，增加听感变化
			player.pitch_scale = GameState.rng.randf_range(0.95, 1.05)
			player.play()
			return


# ─── UI 音效（专用 ui_player）───

func play_ui_sound(stream: AudioStream = null) -> void:
	if not SaveSystem.get_setting("sfx"):
		return
	if not stream or not ui_player:
		return
	ui_player.stream = stream
	ui_player.volume_db = linear_to_db(ui_volume)
	ui_player.play()


# ─── BGM ───

func play_bgm(stream: AudioStream) -> void:
	if bgm_player and stream:
		# 新播放前杀掉旧 tween，避免淡变冲突
		if _bgm_fade_tween:
			_bgm_fade_tween.kill()
		bgm_player.stream = stream
		bgm_player.volume_db = -40  # 静音起步
		bgm_player.play()
		# 线性淡入到目标音量
		_bgm_fade_tween = create_tween()
		_bgm_fade_tween.tween_property(bgm_player, "volume_db", linear_to_db(bgm_volume), 0.5)

func stop_bgm() -> void:
	if _bgm_fade_tween:
		_bgm_fade_tween.kill()
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(bgm_player, "volume_db", -40, 0.5)
	_bgm_fade_tween.tween_callback(bgm_player.stop)


# ─── 音量设置 ───

# 从存档读取音量并应用到对应总线，供启动与设置面板调用
func apply_saved_volumes() -> void:
	var master_v = SaveSystem.get_setting("master_volume")
	var bgm_v = SaveSystem.get_setting("bgm_volume")
	var sfx_v = SaveSystem.get_setting("sfx_volume")
	var ui_v = SaveSystem.get_setting("ui_volume")
	set_master_volume(float(master_v) if master_v != null else 0.8)
	set_bgm_volume(float(bgm_v) if bgm_v != null else 0.8)
	set_sfx_volume(float(sfx_v) if sfx_v != null else 1.0)
	set_ui_volume(float(ui_v) if ui_v != null else 0.8)

func set_master_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index("Master")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(master_volume))

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index("SFX")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(sfx_volume))

func set_bgm_volume(v: float) -> void:
	bgm_volume = clampf(v, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index("BGM")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(bgm_volume))

func set_ui_volume(v: float) -> void:
	ui_volume = clampf(v, 0.0, 1.0)
	var idx: int = AudioServer.get_bus_index("UI")
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, linear_to_db(ui_volume))
