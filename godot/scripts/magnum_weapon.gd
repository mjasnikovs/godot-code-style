class_name MagnumWeapon extends Weapon

const BULLET_SCENE: PackedScene = preload("res://scenes/bullet.tscn")

var shots_fired: int = 0


func fire() -> void:
	if reload_time > 0:
		return
	super()
	shots_fired += 1
	var instance: Bullet = BULLET_SCENE.instantiate()
	instance.direction = 1
	Global.world.call_deferred("add_child", instance)


func _setup() -> void:
	shots_fired = 0
