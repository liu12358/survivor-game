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


func _set_collision_disabled(obj: Node, disabled: bool) -> void:
	for child in obj.get_children():
		if child is CollisionShape2D:
			child.set_deferred("disabled", disabled)
		elif child is CollisionPolygon2D:
			child.set_deferred("disabled", disabled)


func _create_instance() -> Node:
	var obj = scene.instantiate()
	add_child(obj)
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	obj.visible = false
	# 预热对象移出功能组，避免被磁吸/武器/合并逻辑误判为活跃对象
	obj.remove_from_group("gem")
	obj.remove_from_group("enemy")
	# 禁用碰撞形状（CollisionObject2D 无 disabled 属性，set_deferred 无效）
	_set_collision_disabled(obj, true)
	if obj is Area2D:
		obj.monitoring = false
		obj.monitorable = false
	return obj


func acquire() -> Node:
	var obj: Node
	if _pool.is_empty():
		# 池空时不偷取仍在场景中运行的活跃对象，而是新建实例（可能临时超过 max_size）
		if _active.size() >= max_size:
			push_warning("ObjectPool: max_size exceeded, creating new instance")
		obj = _create_instance()
	else:
		obj = _pool.pop_back()
	obj.process_mode = Node.PROCESS_MODE_INHERIT
	obj.visible = true
	_set_collision_disabled(obj, false)
	if obj is Area2D:
		obj.monitoring = true
		obj.monitorable = true
	_active.append(obj)
	return obj


func release(obj: Node) -> void:
	# 双重释放守卫：已在池中或不在活跃集合中则直接返回，避免同一对象被多次入池
	if obj in _pool:
		return
	if not _active.has(obj):
		return  # 已释放或从未 acquire
	_active.erase(obj)
	obj.process_mode = Node.PROCESS_MODE_DISABLED
	obj.visible = false
	_set_collision_disabled(obj, true)
	if obj is Area2D:
		obj.monitoring = false
		obj.monitorable = false
	_pool.append(obj)


func get_active_count() -> int:
	return _active.size()


func release_all() -> void:
	for obj in _active.duplicate():
		release(obj)
