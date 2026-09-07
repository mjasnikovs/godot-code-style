class_name Player extends Character

enum State {idle, walk, jump, fall, attack, hit}

const blocked_states: Array[State] = [State.attack, State.hit]
const SPEED: float = 100.0
const JUMP_VELOCITY: float = -300.0
const JUMP_BUFFER_TIME: float = 0.1
const gold: PackedScene = preload("res://scenes/gold.tscn")

@export_category("Nodes")
@export var directional: Node2D
@export var animation: AnimationPlayer

var c_state: State = State.idle
var jump_buffer_time: float = 0.0
var on_floor: bool = false

signal player_died(who: Player)


func _ready() -> void:
	assert(directional, "player.gd - @export directional is not set in the editor on: " + self.name)
	assert(animation, "player.gd - @export animation is not set in the editor on: " + self.name)
	Global.register_player(self)
	var _error: int = animation.animation_finished.connect(func(_anim_name: StringName) -> void:
		force_state(State.idle)
	)


func force_state(state: State) -> void:
	c_state = state
	set_animation()


func set_state(state: State) -> void:
	if blocked_states.has(c_state): return
	c_state = state
	set_animation()


func set_animation() -> void:
	var new_anim: StringName = State.keys()[c_state]
	assert(animation.has_animation(new_anim),
		"player.gd - animation player has no animation named '" + new_anim + "'")
	animation.play(new_anim)


func take_damage(damage: int, direction: Direction) -> void:
	if damage <= 0: return
	knockback_buffer_time = KNOCKBACK_TIME
	velocity.x = 60.0 * direction
	force_state(State.hit)


func face(direction: Direction) -> void:
	c_direction = direction
	directional.scale.y = -1 if direction == Direction.left else 1
	directional.rotation_degrees = 180 if direction == Direction.left else 0


func drop_gold() -> void:
	var instance: Node2D = gold.instantiate()
	instance.global_position = global_position
	Global.world.call_deferred("add_child", instance)


func die() -> void:
	player_died.emit(self)
	queue_free()


func _physics_process(delta: float) -> void:
	super(delta)
	jump_buffer_time = max(0, jump_buffer_time - delta)
	on_floor = is_on_floor()

	if Input.is_action_just_pressed("button_a"):
		jump_buffer_time = JUMP_BUFFER_TIME

	if jump_buffer_time > 0 and on_floor:
		jump_buffer_time = 0.0
		velocity.y = JUMP_VELOCITY

	if knockback_buffer_time > 0:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
	elif on_floor and !is_zero_approx(velocity.x):
		set_state(State.walk)
	elif on_floor:
		set_state(State.idle)
	elif velocity.y < 0.0:
		set_state(State.jump)
	else:
		set_state(State.fall)

	var _collided: bool = move_and_slide()
