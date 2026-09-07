class_name Bullet extends Area2D

const SPEED: float = 220.0
const LIFETIME: float = 3.0

# A projectile's facing is a plain signed int, not a Direction enum.
var direction: int = 1
var damage: int = 5


func _ready() -> void:
	assert(direction == -1 or direction == 1, "bullet.gd - direction was not set on: " + self.name)
	var time: Timer = Timer.new()
	time.autostart = true
	time.one_shot = true
	time.wait_time = LIFETIME
	var _error: int = time.timeout.connect(func () -> void:
		queue_free()
	)
	add_child(time)


func _physics_process(delta: float) -> void:
	position.x += SPEED * direction * delta
