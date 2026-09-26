class_name Weapon extends Node2D

const RELOAD_BUFFER_TIME: float = 0.8

var reload_time: float = 0.0


func _ready() -> void:
	_setup()


func _process(delta: float) -> void:
	reload_time = maxf(0.0, reload_time - delta)


func fire() -> void:
	if reload_time > 0:
		return
	reload_time = RELOAD_BUFFER_TIME


# The template-method hook: _ready is wiring only, subclasses override this.
# Named _setup, not _on_ready: this style bans every func _on_* name.
func _setup() -> void:
	pass
