class_name HitBox extends Area2D

@export var character: Character

var damage: int = 10


func _ready() -> void:
	assert(character, "hit_box.gd - @export character is not set in the editor on: " + self.name)
