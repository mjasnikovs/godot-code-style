class_name HealthBar extends Control

const DRAIN_SPEED: float = 40.0

@export var label: Label

var max_value: int = 100
var displayed: float = 100.0
var value: int = 100:
	set(new_value):
		value = clamp(new_value, 0, max_value)
		return new_value


func _ready() -> void:
	assert(label, "health_bar.gd - @export label is not set in the editor on: " + self.name)


func _process(delta: float) -> void:
	displayed = move_toward(displayed, float(value), DRAIN_SPEED * delta)
	label.text = str(int(displayed))
