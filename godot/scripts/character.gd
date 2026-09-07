class_name Character extends CharacterBody2D

# The shared base that makes take_damage a typed call instead of a duck-typed
# one through owner. Parameters take a leading _ because the body is pass.

enum Direction {left = -1, right = 1}

const KNOCKBACK_TIME: float = 0.1

var c_direction: Direction = Direction.right
var knockback_buffer_time: float = 0.0


func take_damage(_damage: int, _direction: Direction) -> void:
	pass


func _physics_process(delta: float) -> void:
	knockback_buffer_time = max(0, knockback_buffer_time - delta)
