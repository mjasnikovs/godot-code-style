class_name EnemySpawner extends Node2D

const enemy: PackedScene = preload("res://scenes/enemy.tscn")
const SPAWN_TIME: float = 2.0

@export_category("Settings")
@export var budget: int = 10
@export_category("Nodes")
@export var spawn_points: Array[Node2D] = []

var _spawning: bool = false
var _spawn_time: float = 0.0


func _ready() -> void:
	assert(!spawn_points.is_empty(), "enemy_spawner.gd - @export spawn_points is not set in the editor on: " + self.name)
	_spawning = true


func spawn() -> void:
	if budget <= 0:
		printerr("EnemySpawner: " + self.name + " asked to spawn with no budget left.")
		return
	var point: Node2D = spawn_points[randi() % spawn_points.size()]
	var instance: Enemy = enemy.instantiate()
	instance.global_position = point.global_position
	budget -= 1
	Global.world.call_deferred("add_child", instance)


func _process(delta: float) -> void:
	if !_spawning: return
	_spawn_time = max(0, _spawn_time - delta)
	if _spawn_time > 0: return
	_spawn_time = SPAWN_TIME
	spawn()
