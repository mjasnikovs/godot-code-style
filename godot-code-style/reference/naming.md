# Naming, declarations and shapes

Everything here is the canonical form, one per thing. The per-instance SCREAMING
`var` below is the single exception, and it says why.

## Class declaration

One line, first line of the file.

```gdscript
class_name Player extends CharacterBody2D
```

- PascalCase, matching the filename: `player.gd` → `Player`,
  `enemy_spawner.gd` → `EnemySpawner`.
- No shebang, no license header, no top-of-file comment.
- Autoloads omit `class_name` entirely and open with `extends Node`.

An autoload has one name: the registration name in `project.godot`. Every script
refers to it by that name, and the singleton's own type is never written out.

## The naming table

| Element | Case | Example |
|---|---|---|
| `class_name` | PascalCase | `class_name EnemySpawner extends Node2D` |
| `const` | SCREAMING_SNAKE | `const JUMP_VELOCITY: float = -300.0` |
| member `var` | snake_case | `var knockback_buffer_time: float = 0.0` |
| local `var` | snake_case | `var weapon: Weapon = value.instantiate()` |
| `func` (public and private) | snake_case | `func set_state(state: State) -> void:` |
| `enum` type | PascalCase | `enum State {...}` |
| `enum` member | lowercase | `enum Direction { left = -1, right = 1 }` |
| `signal` | snake_case, past tense | `signal enemy_died(enemy_node: Enemy)` |
| private state | `_` prefix | `var _budget: int = 0` |

### The two meaningful prefixes

`c_` is "current value". A state machine's live state is `c_state`; a character's live
facing is `c_direction`. Every current-value var carries it.

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
- `force_state(state)` bypasses it. Two callers only: the animation-finished reset,
  and damage that must land whatever the state.

## Constants

SCREAMING_SNAKE, explicitly typed, every one of them: scalars, collections,
config dictionaries and preloads alike. A preloaded scene ends in `_SCENE`:

```gdscript
const GOLD_SCENE: PackedScene = preload("res://scenes/items/gold.tscn")
```

`.gdlintrc` enforces it: `constant-name` keeps gdlint's SCREAMING default, and
`load-constant-name` is narrowed to SCREAMING only.

Tuning dials for one behaviour sit adjacent in the same file:

```gdscript
const MAX_SPEED: float = 65.0
const MIN_SPEED: float = 35.0
const KNOCKBACK_BUFFER_TIME: float = 0.1
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
enum State { idle, walk, jump, fall, attack, hit, death }
```

**Direction** — explicit ±1, so the value can be multiplied straight into velocity:

```gdscript
enum Direction { left = -1, right = 1 }
```

A family that shares a facing declares it once, on the shared base class
(`Character.Direction`), and every subclass inherits it. Reference another class's
enum by qualified name: `Player.State`, `Character.Direction`.

```gdscript
func emit(target: Enemy, damage: int, direction: Enemy.Direction) -> void:
```

**Categorical config** — lowercase members naming a variant:

```gdscript
enum Background { red, blue }
```

Enum members are lowercase in every enum. `.gdlintrc` accepts nothing else.

Do **not** model a projectile's facing as a `Direction` enum. A projectile carries a
plain signed int, set from outside before use:

```gdscript
var direction: int
```

`Direction` is reserved for characters, the things that move under their own control.

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
@export var ready_health: int = 100
@export var budget_cost: int = 0

@export_category("Nodes")
@export var directional: Node2D
@export var animation: AnimationPlayer
```

Every placed node a script reaches is an `@export`, and every exported node reference
is asserted in `_ready`. A node the script creates is not placed: `instantiate()` and
`.new()` return the reference, and it stays in a typed local or member.

## `@onready`

Use it for one thing: a value derived from other members at ready time — an index
array built from exported values, a `RandomNumberGenerator.new()`.

`@onready` never preloads. A preload is known at compile time, so it is a `const`:

```gdscript
const BULLET_SCENE: PackedScene = preload("res://scenes/items/bullet.tscn")
```

`@onready` never grabs a node. `@onready var spider: Spider = $World/Spider` is a
scene path in a script, and it breaks the moment the node moves. Node references
come in through `@export` only:

```gdscript
@export_category("Nodes")
@export var spider: Spider
```

In the `.tscn` that slot is `spider = NodePath("World/Spider")`, and it resolves on
`instantiate()` only when the node line also carries
`node_paths=PackedStringArray("spider")`. The editor writes that header when you
drag the node into the slot. A hand-written scene that forgets it reads the export
back as `null`, and the `_ready` assert is what says so. Measured on 4.7.2.

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
		value = clampi(value, min_value, max_value)
		update_shells()
		return new_value
```

Replacing an instance in a setter always `queue_free()`s the old one first.

## Type annotations

No exceptions and no inference.

- Every `const`, member `var` and local `var` is annotated.
- Every parameter is typed, every function has a return type, and void functions
  write `-> void`. The one untyped parameter is a setter's: Godot 4.7.2 refuses
  `set(value: int)` as a parse error and takes the type from the property.
- `for` loops type the loop variable: `for i: int in range(5):`.
- Lambda parameters are typed: `func(body: Node2D) -> void:`.

The `project.godot` warning block that enforces this is in `checklist.md`.

## Files and folders

Filenames are snake_case and derive from the `class_name`: `EnemySpawner` lives in
`enemy_spawner.gd`. Inside `scripts/` and `scenes/`, folders are snake_case and named
for what is in them (`character/`, `items/`, `ui/`, `weapons/`), never for a layer
(`managers/`).

A scene and the script that drives it share a stem: `player.tscn` and `player.gd`.

## Strings

Double quotes, everywhere. Single quotes do not appear.

One case needs care. `gdformat` rewrites `"\""` as `'"'`, so a string holding a double
quote cannot stay double-quoted. Compare the character by code point instead, through
a named constant: `line.unicode_at(index) == DOUBLE_QUOTE`. Measured on gdtoolkit
4.5.0.

Use `StringName` for anything the engine compares by name — animation names, input
actions, group names. Node paths are not on the list, because a script never holds
one. The literal form is `&"idle"`. It interns once and compares by pointer, so a
per-frame comparison costs nothing.

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

- `gdformat` at 120 writes the layout: indentation, wrapping, spacing inside enum
  braces, and a guard's `return` on its own line. Never format by hand.
- Tabs, one per nesting level. Never spaces.
- Maximum line length 120, set in `.gdformatrc` and enforced by `.gdlintrc`.
- **Two blank lines between functions.** One blank line between member blocks (the
  `const` block, then the `@export` block, and so on). None inside a function unless
  it separates two genuinely distinct steps.
- No blank line directly after a `func` signature. One blank line after the
  declaration on line 1, then the first member.
- Ternaries use the GDScript form: `var polarity: int = 1 if value >= 0 else -1`.
