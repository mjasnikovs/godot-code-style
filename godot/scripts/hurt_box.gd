class_name HurtBox extends Area2D

@export var character: Character


func _ready() -> void:
	assert(character, "hurt_box.gd - @export character is not set in the editor on: " + self.name)
	var _error: int = self.area_entered.connect(func(area: Area2D) -> void:
		var hitbox: HitBox = area as HitBox
		if !hitbox: return
		if hitbox.character == character: return
		if hitbox.character is Enemy and character is Enemy: return
		character.take_damage(hitbox.damage, hitbox.character.c_direction)
	)
