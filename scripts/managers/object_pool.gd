# ObjectPool - 通用对象池
# 用于子弹/宝石/敌人复用的泛型对象池
class_name ObjectPool
extends Node

@export var scene: PackedScene
@export var initial_size: int = 50
@export var max_size: int = 500

var _pool: Array[Node] = []
var _active: Array[Node] = []


func _ready() -> void:
	prewarm(initial_size)


func prewarm(count: int) -> void:
	for _i in range(count):
		var obj = _create_instance()
		_pool.append(obj)


func _create_instance() -> Node:
	var obj = scene.instantiate()
	add_child(obj)
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	obj.visible = false
	if obj is CollisionObject2D:
		(obj as CollisionObject2D).set_deferred("disabled", true)
	return obj


func acquire() -> Node:
	if _pool.is_empty():
		if _active.size() >= max_size:
			# 回收最老的
			var oldest = _active[0]
			release(oldest)
		else:
			_pool.append(_create_instance())

	var obj = _pool.pop_back()
	obj.process_mode = Node.PROCESS_MODE_INHERIT
	obj.visible = true
	if obj is CollisionObject2D:
		(obj as CollisionObject2D).set_deferred("disabled", false)
	_active.append(obj)
	return obj


func release(obj: Node) -> void:
	if obj in _active:
		_active.erase(obj)
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	obj.visible = false
	if obj is CollisionObject2D:
		(obj as CollisionObject2D).set_deferred("disabled", true)
	_pool.append(obj)


func get_active_count() -> int:
	return _active.size()


func release_all() -> void:
	for obj in _active.duplicate():
		release(obj)
