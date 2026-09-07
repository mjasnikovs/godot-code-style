class_name Weapon extends Node2D

const RELOAD_TIME: float = 0.8

var reload_time: float = 0.0


# The template-method hook: _ready is wiring only, subclasses override this.
# Named _setup, not _on_ready: this style bans every func _on_* name.
func _setup() -> void:
	pass


func _ready() -> void:
	_setup()


func fire() -> void:
	if reload_time > 0: return
	reload_time = RELOAD_TIME


func _process(delta: float) -> void:
	reload_time = max(0, reload_time - delta)
