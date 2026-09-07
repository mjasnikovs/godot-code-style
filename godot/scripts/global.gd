extends Node

# Autoloads omit class_name: they are reached by their registration name.
# This is the only script allowed to hold raw scene-tree paths.

var world: Node2D = null
var player: Player = null

signal enemy_died(enemy_node: Enemy)


func register_world(node: Node2D) -> void:
	world = node


func register_player(node: Player) -> void:
	player = node


# A cross-scene signal is emitted by a method on the autoload that owns it.
# Emitting it from another script leaves unused_signal firing here.
func report_enemy_died(enemy_node: Enemy) -> void:
	enemy_died.emit(enemy_node)
