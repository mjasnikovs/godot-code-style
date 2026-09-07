# The patterns

The recurring decisions, in full. Each one exists because Godot offers two or more
ways to do the thing and mixing them makes a codebase unreadable.

## 1. Signals

Declare with typed arguments. Guard a declaration nothing emits yet so it does not
warn.

```gdscript
@warning_ignore("unused_signal")
signal enemy_died(enemy_node: Enemy)
```

Connect with an **inline lambda**, in `_ready`. Editor-generated `_on_<signal>`
handler methods do not appear in this style — they scatter the reaction away from the
wiring and the editor silently owns the connection.

```gdscript
	self.area_entered.connect(func(hitbox: HitBox) -> void:
		if hitbox == null or parent_hit_box == hitbox: return
		...
	)
```

Emit with `signal_name.emit(...)`. For one-shot self-cleanup, connect the method
directly rather than wrapping it:

```gdscript
	audio_player.finished.connect(audio_player.queue_free)
```

## 2. The buffer / decay pattern

Cooldowns, i-frames, recoil, knockback, input buffers. All of them are a `float` of
seconds, decayed every frame, treated as active while positive.

```gdscript
	jump_block_time = max(0, jump_block_time - delta)
```

```gdscript
	if knockback_buffer_time > 0:
		...
```

To trigger one, set it to its `*_BUFFER_TIME` const. Prefer this over a `Timer` node
for anything that is checked per frame: the value is inspectable, serialisable, and
costs no node.

## 3. `await` for a delay inside a function

Two forms, no third.

```gdscript
	await animation_player.animation_finished
	await Global.camera.slow_down_time().finished
```

```gdscript
	await get_tree().create_timer(0.1).timeout
```

Never build a `Timer` just to wait inside a function that is already running.

## 4. The ad-hoc `Timer`

For a delay that must outlive the call — a fuse, a spawn delay, a projectile
lifetime — create a local `Timer`, one per delay.

```gdscript
	var time: Timer = Timer.new()
	time.autostart = true
	time.one_shot = true
	time.wait_time = 3
	time.timeout.connect(func () -> void:
		...
	)
```

Do not put these in the scene tree as editor `Timer` nodes. A timer that exists for
three seconds should not be visible in the scene forever.

## 5. Reaching another system

Three approved ways to get a reference, in priority order.

**Through the global-state autoload.** One autoload holds the shared world and UI
node references, grabbed in its own `_ready`. Everything else asks it.

```gdscript
	Global.world.call_deferred("add_child", gold_instance)
```

**`get_tree().get_root().get_node(...)`** is permitted **only** inside that autoload's
own initialisation. Anywhere else it is a bug — it hard-codes a scene path into a
script that has no business knowing one.

```gdscript
@onready var player: Player = get_tree().get_root().get_node("World/Player")
```

**In-scene references** via `@export` node refs, and `self.owner` for a child script
reaching the character it belongs to.

## 6. Assertions

Every `@export` dependency is asserted in `_ready`, one message shape:

```gdscript
	assert(animation, "grenade.gd - @export animation is not set in the editor on: " + self.name)
```

Filename, then `@export <name> is not set in the editor on: `, then `self.name` (or
`self.owner.name` for a child-node script). Class-level invariants are asserted in
`_init` instead, with `@warning_ignore("unsafe_property_access")` above the access.

## 7. Config data

Look-up and config data lives in plain `Dictionary` members and `const Dictionary`
blobs. Custom `Resource` subclasses are not used.

```gdscript
const magnum_1: Dictionary = {
	"background": Background.blue,
	"icon": Icon.bow,
	"title_label": "Magnum",
	"packed_scene": preload("res://scenes/weapons/magnum_weapon.tscn")
}
```

A `const Dictionary` is untyped, so reading a field back needs a cast and a suppression
directly above it:

```gdscript
	@warning_ignore("unsafe_cast")
	set_background(card.background as Background)
```

Runtime look-up tables are the same idea built at load: a sound name → `AudioStream`
dictionary, or a `State` → `Array[String]` map picked from at random.

```gdscript
	sfx[c_state][randi() % sfx[c_state].size()]
```

## 8. Branching

`if` / `elif` / `else`. `match` does not appear. Guard clauses go at the top, one line
each, and negation is `!`.

```gdscript
	if !target: return
```

```gdscript
func set_state(state: State) -> void:
	if blocked_states.has(c_state): return
```

An idempotency clause is the allowed second form of that guard:

```gdscript
	if blocked_states.has(c_state) or state == c_state: return
```

## `_physics_process` vs `_process`

| Kind of logic | Callback |
|---|---|
| character and projectile movement, collisions | `_physics_process(delta: float)` |
| camera, UI, timers, visual effects, day/night | `_process(delta: float)` |

Both take a typed `delta` and decay their buffers with it.

## Input

Read actions by name. Keep the action set small and named after the physical control,
so the binding can change without touching code.

```gdscript
	if Input.is_action_just_pressed("button_a"):
```

In-scene, per-frame input is read inside the process loop. Global and menu-level input
goes through overrides instead: `_unhandled_input` for application-wide controls,
`_input` on a screen script for that screen's navigation.

```gdscript
	if event.is_action_pressed("button_select"):
		get_tree().quit()
```

## `call_deferred`

For a cross-object call that must land after the current frame — re-parenting a
freshly instantiated node, refreshing a UI element after the value behind it changed.

```gdscript
	Global.world.call_deferred("add_child", gold_instance)
```

```gdscript
	Global.bullet_bar.call_deferred("update_bullets")
```

## `queue_free` and cleanup

Self-removal is `queue_free()`. One-shot resources clean themselves up by connecting
their own `finished` signal.

```gdscript
func remove() -> void: queue_free()
```

```gdscript
	audio_player.finished.connect(audio_player.queue_free)
```

## Tweens

Build with `create_tween()` on the node, or `get_tree().create_tween()`. Chain with
`tween_property(...)` plus `.set_ease(...)`, `.set_trans(...)`, `.set_delay(...)`.
Parallel tracks use `.set_parallel(true)`.

```gdscript
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel()
	tween.tween_property(number, "position:y", number.position.y - 20, 0.3).set_ease(Tween.EaseType.EASE_OUT)
```

Store a long-running tween in a member and `kill()` the previous one before starting
its replacement. To wait for a tween, `await` its `.finished`.

## `preload` vs `load`

- `preload(...)` for anything known at compile time: `const PackedScene`, `FontFile`,
  and `@onready` one-time loads.
- `load(...)` only for a path discovered at runtime — scanning a directory into a
  dictionary at startup, for instance.

## Randomness

Global `randf_range` / `randi` / `randi_range` for one-off randomness: pitch jitter,
spread, damage variance, spawn intervals.

```gdscript
	audio_player.pitch_scale = pitch_scale if pitch_scale != 0 else 1.0 + randf_range(-0.4, 0.4)
```

Instantiate a `RandomNumberGenerator` only when a **separate stream** is genuinely
needed, such as camera shake noise that must not perturb gameplay rolls.

```gdscript
@onready var rand: RandomNumberGenerator = RandomNumberGenerator.new()
```

## Math

Use the built-ins. Do not write math helpers.

- `lerp` for interpolation.
- `clamp` for bounds.
- `max(0, v - delta)` for buffer decay.
- `Vector2` for positions and sizes — never `Vector2i`.

## Error output

`printerr` for genuine runtime errors: invariant violations, a missing required
method, unreachable state.

```gdscript
			printerr("HurtBox: " + self.owner.name + " has undefined take_damage method.")
```

`print(...)` is a temporary field-debugging tool and does not survive into a commit.

## Scene composition

**Directional node.** A character with a flip-able sprite gets an
`@export var directional: Node2D` holding the sprite. Flip by negating Y scale and
rotating 180°, so children keep their upright orientation.

```gdscript
		directional.scale.y = -1
		directional.rotation_degrees = 180
```

**HitBox / HurtBox pair.** Combat is two `Area2D`s. The attacker's `HitBox` deals
damage on `area_entered`; the victim's `HurtBox` receives it and forwards to
`self.owner.take_damage(...)`. The pair must ignore itself and same-side actors.

```gdscript
		if hitbox.owner is Enemy and self.owner is Enemy: return
```

**Weapon slot.** An equipping character holds a `Weapon` instantiated from an
`@export var weapon_scene: PackedScene` custom setter, then re-parented under the
`directional` node.

**`_on_ready()` template hook.** When a base class's `_ready` exists only to give
subclasses a wiring point, route it through an overridable `_on_ready()` with a `pass`
body. Use this only where a hierarchy actually needs it.

```gdscript
func _on_ready() -> void:
	pass

func _ready() -> void:
	_on_ready()
```

## Script archetypes

| Kind | Shape |
|---|---|
| **Autoload** | no `class_name`; `extends Node`; the only holder of cross-scene node refs and cross-scene signals |
| **UI** | `Control` subclass; typed `for` over `get_children()`; `@export` refs asserted; values decay with `max(0, ...)` |
| **Projectile** | `Area2D`; plain `var direction: int`, `damage`, `spread`, `lifetime` set externally and asserted in `_ready`; lifetime from a local one-shot `Timer` |
| **Spawner** | `_`-prefixed private state; `@onready` index arrays derived from per-level `@export` arrays |
| **Throwable** | `RigidBody2D`; throw plus a one-shot `Timer` fuse; `explode()` and `remove() -> void: queue_free()` |
