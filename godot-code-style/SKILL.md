---
name: godot-code-style
description: >
  Write GDScript in a strict, fully typed, single-style dialect for Godot 4. Use when
  writing or reviewing any .gd script; when deciding where a member goes in a file,
  how to name it, or which of two Godot features to reach for; when a script mixes
  spaces and tabs, untyped vars, inferred types, or editor-generated _on_signal
  handlers; when an unsafe_* or untyped_declaration warning fires, or a
  @warning_ignore is used to silence one. Triggers: GDScript
  style, coding standard, class_name, @export_category, @onready, typed GDScript, strict typing, gdlint, gdformat, naming convention, signal lambda,
  code review of a Godot script.
---

# GDScript code style (Godot 4)

Verified against Godot 4.7.2 and gdtoolkit 4.5.0 by building the project in `godot/`
and running it. Every rule below compiles under 23 warnings-as-errors with no
suppressions, and 3663 assertions check that it stays that way.

One dialect. Every script in the project looks like it was written by the same person
in the same hour. Where Godot offers two ways to do a thing, this style picks one and
the other is a bug.

The style rests on one setting: **every warning that can catch an untyped or unsafe
line is an error.** Turn that on first (`reference/checklist.md`). The rest of this
document is what the codebase looks like once the compiler refuses anything else.

## The file

Line 1 is the declaration. No shebang, no license header, no comment block above it.

```gdscript
class_name Player extends CharacterBody2D
```

`class_name` is PascalCase and matches the filename (`enemy_spawner.gd` →
`EnemySpawner`). **Autoloads omit `class_name`** — they are reached by their
registration name, so a global class name would be a second name for one thing.

```gdscript
extends Node
```

## Member order

Top to bottom, always:

1. `enum`
2. `const` (including `const X: PackedScene = preload(...)`)
3. `@export_category` / `@export` / `@onready`
4. plain `var`
5. `signal`
6. `func`

```gdscript
enum Direction {left = -1, right = 1}
enum State {idle, walk, jump, fall, attack, hit, death}

const blocked_states: Array[State] = [State.attack, State.hit]
const JUMP_VELOCITY: float = -300.0

@export_category("Nodes")
@export var directional: Node2D
@export var animation: AnimationPlayer

var c_state: State = State.idle
var knockback_buffer_time: float = 0.0
```

Functions come after every member. Lifecycle first (`_init`, `_ready`,
`_physics_process` / `_process`), then public API, then private helpers.

## Names

| Element | Case | Example |
|---|---|---|
| `class_name` | PascalCase | `class_name EnemySpawner extends Node2D` |
| `const` | SCREAMING_SNAKE | `const JUMP_VELOCITY: float = -300.0` |
| `var`, `func` | snake_case | `func set_state(state: State) -> void:` |
| `enum` type | PascalCase | `enum State {...}` |
| `enum` member | lowercase | `enum Direction {left = -1, right = 1}` |
| `signal` | snake_case, past tense | `signal enemy_died(enemy_node: Enemy)` |
| private member | `_` prefix | `var _spawning: bool = false` |

Two name shapes carry meaning and are worth learning:

- `c_*` marks a **current-value** state var: `var c_state: State = State.idle`.
- `*_time` marks a **seconds countdown** buffer: `var jump_buffer_time: float = 0.0`.

SCREAMING case implies `const`. A SCREAMING `var` is allowed only when the value is
genuinely per-instance, and then it must be bounded by a `MIN_`/`MAX_` const pair.

```gdscript
const MAX_SPEED: float = 65.0
const MIN_SPEED: float = 35.0
var SPEED: float = randf_range(MIN_SPEED, MAX_SPEED)
```

## Types

Everything is annotated. No `:=`, no bare `var`.

```gdscript
func take_damage(damage: int, direction: Direction) -> void:
	var weapon: Weapon = value.instantiate()
	for i: int in range(5):
		pass
```

Void functions write `-> void`. Loop variables are typed. Lambda parameters are typed:
`func (hitbox: HitBox) -> void:`.

Tabs, never spaces. Lines ≤ 120 characters.

## Layout

- Filenames are snake_case and match the `class_name`: `enemy_spawner.gd` →
  `EnemySpawner`. Folders are snake_case too.
- Two blank lines between functions. One blank line between member blocks. None
  inside a function unless it separates two distinct steps.
- Double quotes for every string. Single quotes do not appear.
- `StringName` for anything Godot compares by name — animation names, input actions,
  node paths, groups. Write the literal as `&"idle"`.
- `#` comments explain **why**, never what. A comment restating the line below it is
  deleted. `##` doc-comments do not appear at all.

## The eight patterns

These are the decisions that repeat. Full form and rationale in
`reference/patterns.md`.

| # | Situation | This style |
|---|---|---|
| 1 | Reacting to a signal | inline `connect(func(...) -> void: ...)` — never an `_on_*` method |
| 2 | A countdown (cooldown, i-frames, buffer) | `float` seconds, `v = max(0, v - delta)` each frame, used while `v > 0` |
| 3 | A one-shot delay inside a function | `await get_tree().create_timer(d).timeout` |
| 4 | A one-shot delay that outlives the call | local `Timer.new()` with `autostart` + `one_shot` |
| 5 | Reaching another system | through the global-state autoload's refs |
| 6 | Reaching a node in the same scene | `@export` node ref, asserted in `_ready` |
| 7 | Config data | `const Dictionary` blob, never a `Resource` subclass |
| 8 | Branching on a state | `if` / `elif` / `else`, never `match` |

Three rules ride along with them. Physics belongs in `_physics_process`; visual, UI
and timing logic belongs in `_process`. Negation is `!`, not `not`. And **no method is
ever called through `owner` or `get_parent()`** — both are typed `Node`, so the call
is unsafe by construction. Take an `@export` reference to the real class instead:

```gdscript
@export var character: Character
```

That is why a family of things that share an interface — everything that can be
damaged, say — shares a base class. The base declares the method with a `pass` body
and `_`-prefixed parameters, and subclasses override it. `owner.name` is fine; `Node`
really does have a name.

```gdscript
func take_damage(_damage: int, _direction: Direction) -> void:
	pass
```

## Assertions

Every `@export` **node or resource** reference is asserted in `_ready`, in one message
shape:

```gdscript
	assert(animation, "player.gd - @export animation is not set in the editor on: " + self.name)
```

Filename, the export's name, then the node it happened on. Class-level invariants go
in `_init` instead.

Value exports — `int`, `float`, `bool`, `String` — are **not** asserted. They carry a
default, and `assert(budget)` is false for a legitimate zero.

## Guards

Guard clauses at the top, one line each.

```gdscript
	if !target: return
```

```gdscript
func set_state(state: State) -> void:
	if blocked_states.has(c_state): return
```

## Autoload signals

A `signal` declared in an autoload and emitted from another script still fires
`unused_signal` — the compiler only counts uses inside the declaring class. Since
there is no suppression, the autoload emits its own signals through a method:

```gdscript
signal enemy_died(enemy_node: Enemy)


func report_enemy_died(enemy_node: Enemy) -> void:
	enemy_died.emit(enemy_node)
```

Callers write `Global.report_enemy_died(self)`. Measured; the direct
`Global.enemy_died.emit(self)` does not compile.

## No suppressions

`@warning_ignore` does not appear in this style, in any form. Neither does
`@warning_ignore_start` / `@warning_ignore_restore`, the Godot 3 `# warning-ignore:`
comment, a `# gdlint:ignore=` comment, nor lowering a warning level in `project.godot`.

A warning is the type system telling you it lost track of a value. Silencing it keeps
the ignorance and hides it. Fix the cause instead:

| The warning | The fix |
|---|---|
| `unsafe_cast` | give the source an explicit type, so no cast is needed |
| `unsafe_property_access` / `unsafe_method_access` | type the reference as the class you are calling into, not `Node` |
| `unsafe_call_argument` | type the local you are passing, at its declaration |
| `unused_signal` | delete the signal, or emit it |
| `return_value_discarded` | assign it to a typed `_`-prefixed throwaway |
| `unused_parameter` | prefix it `_` |

The last two rows are the only escape hatches, and both change the code rather than
muting the compiler. A `_`-prefixed identifier is exempt from the unused warnings, so
a return you genuinely do not want gets a name and a type anyway. Declare one
throwaway per type per scope and reuse it:

```gdscript
	var _error: int = animation.animation_finished.connect(func(_anim: StringName) -> void:
		force_state(State.idle)
	)
	_error = area_entered.connect(func(hitbox: HitBox) -> void:
		take_hit(hitbox)
	)
```

The type is `int`, not `Error`. `connect` is declared as returning `int`, so annotating
the throwaway as `Error` fires `int_as_enum_without_cast` and refuses to compile.
Measured.

```gdscript
	var _collided: bool = move_and_slide()
```

If a warning cannot be fixed by typing something, the design is wrong — usually a
`Node` reference being asked to behave like a class it has not been declared as.

## Prohibited

Not "discouraged". These do not appear.

- `match` statements — use `if` / `elif` / `else`
- inner classes, `static` functions, `@tool` scripts, `@abstract`, `@icon`
- custom `Resource` subclasses — config lives in `const Dictionary`
- `Vector2i` — only `Vector2`
- `##` doc-comments
- `@warning_ignore` and every other way of silencing a warning
- calling a method through `owner`, `get_parent()` or any other `Node`-typed reference
- single-quoted strings
- any function named `_on_*`, including editor-generated `_on_<signal>` handlers
- `print(...)` in committed code — `printerr` is the error channel
- raw `get_tree().get_root().get_node(...)` outside the global-state autoload
- scene-tree `Timer` nodes for short one-shot delays

## Build order

1. Set the strict warnings in `project.godot` and add `.gdlintrc`
   (`reference/checklist.md`).
2. Write line 1: `class_name X extends Y`.
3. Lay out members in the six-block order.
4. Annotate every declaration; add `-> void` before writing the body.
5. Assert every `@export` in `_ready`.
6. Wire signals as lambdas in `_ready`.
7. Run `gdlint` and a headless launch; both must be silent.
8. Walk the checklist before committing.

## Reference

- `reference/naming.md` — the full naming table, enum shapes, custom setters,
  `@export_category` grouping, the per-instance SCREAMING exception.
- `reference/patterns.md` — the eight patterns in full, plus tweens, `await`,
  `call_deferred`, `queue_free`, randomness, `preload` vs `load`, script archetypes.
- `reference/checklist.md` — the `project.godot` warning block, `.gdlintrc`, the
  pre-commit checklist, and how to run the linter headless.
