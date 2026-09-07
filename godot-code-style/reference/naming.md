# Naming, declarations and shapes

Everything here is the canonical form. Where a second form is allowed, it says so.

## Class declaration

One line, first line of the file.

```gdscript
class_name Player extends CharacterBody2D
```

- PascalCase, matching the filename: `player.gd` → `Player`,
  `enemy_spawner.gd` → `EnemySpawner`.
- No shebang, no license header, no top-of-file comment.
- Autoloads omit `class_name` entirely and open with `extends Node`.

A `class_name` may differ in casing from the autoload registration name in
`project.godot` (`SFXPlayer2D` registered as `SfxPlayer2d`). When that happens, always
refer to the singleton by its **registration** name; the class name is only for typing.

## The naming table

| Element | Case | Example |
|---|---|---|
| `class_name` | PascalCase | `class_name EnemySpawner extends Node2D` |
| `const` | SCREAMING_SNAKE | `const JUMP_VELOCITY: float = -300.0` |
| member `var` | snake_case | `var knockback_buffer_time: float = 0.0` |
| local `var` | snake_case | `var weapon: Weapon = value.instantiate()` |
| `func` (public and private) | snake_case | `func set_state(state: State) -> void:` |
| `enum` type | PascalCase | `enum State {...}` |
| `enum` member | lowercase | `enum Direction {left = -1, right = 1}` |
| `signal` | snake_case, past tense | `signal enemy_died(enemy_node: Enemy)` |
| private state | `_` prefix | `var _budget: int = 0` |

### The two meaningful prefixes

`c_` is "current value". A state machine's live state is `c_state`; a character's live
facing is `c_direction`. Dropping the prefix on a current-value var is the one allowed
second form — pick one per class and stay with it.

`*_time` is a seconds countdown, always a `float`, always decayed per frame (pattern 2
in `patterns.md`).

```gdscript
var knockback_buffer_time: float = 0.0
var jump_buffer_time: float = 0.0
```

## Function naming

Verbs. `take_damage`, `apply_knockback`, `update_shells`.

State mutation takes a `set_` prefix. When a mutator needs a variant that skips the
guard, name it `force_*`:

- `set_state(state)` respects the block check.
- `force_state(state)` bypasses it, and has exactly one caller.

## Constants

SCREAMING_SNAKE, explicitly typed. Scene and resource preloads are typed `const`s:

```gdscript
const gold: PackedScene = preload("res://scenes/items/gold.tscn")
```

Tuning dials for one behaviour sit adjacent in the same file:

```gdscript
const MAX_SPEED: float = 65.0
const MIN_SPEED: float = 35.0
const KNOCKBACK_TIME: float = 0.1
```

### The per-instance SCREAMING exception

SCREAMING case implies `const`. The single exception: a value that is genuinely
per-instance may be a SCREAMING `var`, and then it **must** be bounded by a
`MIN_`/`MAX_` const pair.

```gdscript
const MAX_SPEED: float = 65.0
const MIN_SPEED: float = 35.0
var SPEED: float = randf_range(MIN_SPEED, MAX_SPEED)
```

Everything else stays a plain constant: `const SPEED: float = 100.0`.

## Enums

Three shapes, all declared in-file at the top of the class.

**State machine** — lowercase, auto-increment, the keys doubling as animation names:

```gdscript
enum State {idle, walk, jump, fall, attack, hit, death}
```

**Direction** — explicit ±1, so the value can be multiplied straight into velocity:

```gdscript
enum Direction {left = -1, right = 1}
```

Each class that needs a facing declares its own. Reference another class's enum by
qualified name: `Player.Direction`, `Enemy.State`.

```gdscript
func emit(target: Enemy, damage: int, direction: Enemy.Direction) -> void:
```

**Categorical config** — lowercase members naming a variant:

```gdscript
enum Background {red, blue}
```

SCREAMING members are the allowed second form for purely categorical phase enums
(`DAY`/`NIGHT`, `IDLE`/`RELOADING`/`ENDING`). Lowercase stays the default everywhere
else.

Do **not** model a projectile's facing as a `Direction` enum. A projectile carries a
plain signed int, set from outside before use:

```gdscript
var direction: int
```

`Direction` is reserved for things that have a state machine attached.

## `@export` and `@export_category`

Editor-facing per-instance configuration is `@export`, explicitly typed, with a
sensible default where one exists.

```gdscript
@export var ready_health: int = 100
```

Group exports into titled editor sections by concern — `"Settings"`, `"Nodes"`,
`"Raycasts"`, `"SFX"`:

```gdscript
@export_category("Settings")
@export var ready_health: int
@export var budget_cost: int

@export_category("Nodes")
@export var directional: Node2D
@export var animation: AnimationPlayer
```

Every node reference in a script is an `@export`, and every exported node reference
is asserted in `_ready`.

## `@onready`

Use it for two things:

1. A value derived from other members at ready time — an index array built from
   exported values, a `RandomNumberGenerator.new()`.
2. A one-time load used at ready time. `@onready` + `preload()` is the sanctioned
   ready-time load form:

```gdscript
@onready var bullet: PackedScene = preload("res://scenes/items/bullet.tscn")
```

`@onready` never grabs a node. `@onready var spider: Spider = $World/Spider` is a
scene path in a script, and it breaks the moment the node moves. Node references
come in through `@export` only:

```gdscript
@export_category("Nodes")
@export var spider: Spider
```

## Custom setters

One shape: `var X: T:` then a `set(value)` body. The parameter is `value` or `new_*`.
End the body by returning the value.

```gdscript
@export var gun_weapon_scene: PackedScene:
	set(value):
		if gun_weapon:
			gun_weapon.queue_free()
		var weapon: Weapon = value.instantiate()
		self.add_child(weapon)
		gun_weapon = weapon
		return value
```

A clamping setter follows the same shape:

```gdscript
var min_value: int = 0:
	set(new_value):
		min_value = new_value
		value = clamp(value, min_value, max_value)
		update_shells()
		return new_value
```

Replacing an instance in a setter always `queue_free()`s the old one first.

## Type annotations

No exceptions and no inference.

- Every `const`, member `var` and local `var` is annotated.
- Every parameter is typed, every function has a return type, and void functions
  write `-> void`.
- `for` loops type the loop variable: `for i: int in range(5):`.
- Lambda parameters are typed: `func (body: Node2D) -> void:`.

The `project.godot` warning block that enforces this is in `checklist.md`.

## Files and folders

Filenames are snake_case and derive from the `class_name`: `EnemySpawner` lives in
`enemy_spawner.gd`. Folders are snake_case, named for what is in them (`character/`,
`items/`, `ui/`, `weapons/`), never for a layer (`scripts/managers/`).

A scene and the script that drives it share a stem: `player.tscn` and `player.gd`.

## Strings

Double quotes, everywhere. Single quotes do not appear.

Use `StringName` for anything the engine compares by name — animation names, input
actions, group names. Node paths are not on the list, because a script never holds one. The literal form is `&"idle"`. It interns once and
compares by pointer, so a per-frame comparison costs nothing.

```gdscript
	var new_anim: StringName = State.keys()[c_state]
```

Plain `String` is for text that a human reads or that you build at runtime.

## Comments

`#` comments explain **why** a line is the way it is. A comment that restates the code
below it is deleted, not reworded.

```gdscript
	# Camera2D.offset is applied after the round, so it escapes the pixel grid.
	offset = Vector2.ZERO
```

`##` doc-comments do not appear. A function that needs a docstring needs a better name
or fewer responsibilities.

Commented-out code does not get committed. Git remembers it.

## Layout

- Tabs, one per nesting level. Never spaces.
- Maximum line length 120, enforced by `.gdlintrc`.
- **Two blank lines between functions.** One blank line between member blocks (the
  `const` block, then the `@export` block, and so on). None inside a function unless
  it separates two genuinely distinct steps.
- No blank line directly after a `func` signature or before the first member.
- Ternaries use the GDScript form: `var sign: int = 1 if value >= 0 else -1`.
