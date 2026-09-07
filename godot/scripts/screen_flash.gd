class_name ScreenFlash extends CanvasLayer

@export var rect: ColorRect

var tween: Tween = null


func _ready() -> void:
	assert(rect, "screen_flash.gd - @export rect is not set in the editor on: " + self.name)


func flash() -> void:
	if tween:
		tween.kill()
	tween = get_tree().create_tween().set_parallel(true)
	var _step: PropertyTweener = tween.tween_property(rect, "modulate:a", 0.0, 0.3) \
		.set_ease(Tween.EaseType.EASE_OUT)


# After an await the node may already be freed. Guard before touching the tree.
func flash_twice() -> void:
	flash()
	await get_tree().create_timer(0.1).timeout
	if !is_instance_valid(self): return
	flash()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("button_select"):
		get_tree().quit()
