# verify_modules.gd - 模块自检验证脚本
# 在 Godot 编辑器中运行此脚本验证所有模块是否正确加载
# 用法：在 Godot 编辑器中打开此脚本 → 按 F6 运行
extends Node

var _test_results: Array[Dictionary] = []
var _passed: int = 0
var _failed: int = 0


func _ready() -> void:
	print("=".repeat(50))
	print("  星屑割草 - 模块自检")
	print("=".repeat(50))
	print("")

	# 1. 验证项目配置
	_test_project_config()

	# 2. 验证单例（Autoload）
	_test_autoloads()

	# 3. 验证核心脚本
	_test_core_scripts()

	# 4. 验证场景文件
	_test_scenes()

	# 5. 验证输入映射
	_test_input_map()

	# 6. 验证碰撞层
	_test_collision_layers()

	# 打印结果
	print("")
	print("=".repeat(50))
	print("  结果: %d 通过 / %d 失败" % [_passed, _failed])
	print("=".repeat(50))

	if _failed == 0:
		print("  所有模块验证通过 ✅")
	else:
		for result in _test_results:
			if not result["passed"]:
				print("  ❌ %s: %s" % [result["name"], result["error"]])

	get_tree().quit(0 if _failed == 0 else 1)


func _test_project_config() -> void:
	_test("项目名 '星屑割草'", ProjectSettings.get_setting("application/config/name") == "星屑割草")
	_test("窗口 1280x720", ProjectSettings.get_setting("display/window/size/viewport_width") == 1280)
	_test("主场景存在", ResourceLoader.exists("res://scenes/levels/main.tscn"))
	_test("渲染 Forward+", ProjectSettings.get_setting("rendering/renderer/rendering_method") == "forward_plus")


func _test_autoloads() -> void:
	_test("EventBus 单例", has_node("/root/EventBus"))
	_test("GameState 单例", has_node("/root/GameState"))
	_test("AudioManager 单例", has_node("/root/AudioManager"))


func _test_core_scripts() -> void:
	# Player
	_test("Player.gd 可加载", _script_exists("res://scripts/player/player.gd"))
	_test("Player 类已注册", ClassDB.class_exists("Player"))

	# Weapons
	_test("BaseWeapon.gd 可加载", _script_exists("res://scripts/weapons/base_weapon.gd"))
	_test("BaseWeapon 类已注册", ClassDB.class_exists("BaseWeapon"))
	_test("MagicBolt.gd 可加载", _script_exists("res://scripts/weapons/magic_bolt.gd"))
	_test("MagicBolt 类已注册", ClassDB.class_exists("MagicBolt"))
	_test("Projectile.gd 可加载", _script_exists("res://scripts/weapons/projectile.gd"))
	_test("Projectile 类已注册", ClassDB.class_exists("Projectile"))

	# Enemies
	_test("BaseEnemy.gd 可加载", _script_exists("res://scripts/enemies/base_enemy.gd"))
	_test("BaseEnemy 类已注册", ClassDB.class_exists("BaseEnemy"))
	_test("ExpGem.gd 可加载", _script_exists("res://scripts/enemies/exp_gem.gd"))
	_test("ExpGem 类已注册", ClassDB.class_exists("ExpGem"))
	_test("EnemySpawner.gd 可加载", _script_exists("res://scripts/enemies/enemy_spawner.gd"))
	_test("EnemySpawner 类已注册", ClassDB.class_exists("EnemySpawner"))

	# Managers
	_test("EventBus.gd 可加载", _script_exists("res://scripts/managers/event_bus.gd"))
	_test("GameState.gd 可加载", _script_exists("res://scripts/managers/game_state.gd"))
	_test("AudioManager.gd 可加载", _script_exists("res://scripts/managers/audio_manager.gd"))
	_test("Main.gd 可加载", _script_exists("res://scripts/managers/main.gd"))
	_test("ObjectPool.gd 可加载", _script_exists("res://scripts/managers/object_pool.gd"))
	_test("Main 类已注册", ClassDB.class_exists("Main"))

	# UI
	_test("HUD.gd 可加载", _script_exists("res://scripts/ui/hud.gd"))


func _test_scenes() -> void:
	var scenes_to_check = [
		["Player", "res://scenes/player/player.tscn"],
		["MagicBolt", "res://scenes/weapons/magic_bolt.tscn"],
		["Projectile", "res://scenes/weapons/magic_bolt_projectile.tscn"],
		["SlimeSmall", "res://scenes/enemies/slime_small.tscn"],
		["SlimeBig", "res://scenes/enemies/slime_big.tscn"],
		["Bat", "res://scenes/enemies/bat.tscn"],
		["Skeleton", "res://scenes/enemies/skeleton.tscn"],
		["Ghost", "res://scenes/enemies/ghost.tscn"],
		["ExpGem", "res://scenes/enemies/exp_gem.tscn"],
		["EnemySpawner", "res://scenes/enemies/enemy_spawner.tscn"],
		["Main", "res://scenes/levels/main.tscn"],
	]

	for check in scenes_to_check:
		var name = check[0]
		var path = check[1]
		_test("场景 %s 存在" % name, ResourceLoader.exists(path))
		if ResourceLoader.exists(path):
			var packed = load(path)
			_test("场景 %s 可实例化" % name, packed.can_instantiate())


func _test_input_map() -> void:
	var actions = ["move_up", "move_down", "move_left", "move_right", "pause", "select_1", "select_2", "select_3"]
	for action in actions:
		_test("输入映射 %s" % action, InputMap.has_action(action))


func _test_collision_layers() -> void:
	var layers = {
		1: "player", 2: "enemy", 3: "projectile", 4: "obstacle",
		5: "exp_pickup", 6: "item", 7: "boss_body", 8: "boss_projectile", 9: "boundary"
	}
	for layer in layers:
		var name = layers[layer]
		var actual = ProjectSettings.get_setting("layer_names/2d_physics/layer_%d" % layer)
		_test("碰撞层 %d = %s" % [layer, name], actual == name)


# ─── 工具方法 ───

func _test(name: String, passed: bool, error: String = "") -> void:
	_test_results.append({"name": name, "passed": passed, "error": error})
	if passed:
		_passed += 1
		print("  ✅ %s" % name)
	else:
		_failed += 1
		print("  ❌ %s" % name)
		if error:
			print("      → %s" % error)


func _script_exists(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	var script: Script = load(path)
	return script != null
