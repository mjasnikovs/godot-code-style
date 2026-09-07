class_name Enemy extends Character

const MAX_SPEED: float = 65.0
const MIN_SPEED: float = 35.0

# Genuinely per-instance, so a SCREAMING var bounded by the MIN_/MAX_ pair.
var SPEED: float = randf_range(MIN_SPEED, MAX_SPEED)
var health: int = 30


func take_damage(damage: int, direction: Direction) -> void:
	health -= damage
	knockback_buffer_time = KNOCKBACK_TIME
	velocity.x = 40.0 * direction
	if health <= 0:
		Global.report_enemy_died(self)
		queue_free()


func _physics_process(delta: float) -> void:
	super(delta)
	if knockback_buffer_time > 0: return
	velocity.x = SPEED * c_direction
