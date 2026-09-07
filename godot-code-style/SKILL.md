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

Two rules ride along with them. Physics belongs in `_physics_process`; visual, UI and
timing logic belongs in `_process`. Negation is `!`, not `not`.

## Assertions

Every `@export` dependency is asserted in `_ready`, in one message shape:

```gdscript
	assert(animation, "player.gd - @export animation is not set in the editor on: " + self.name)
```

Filename, the export's name, then the node it happened on. Class-level invariants go
in `_init` instead.

## Guards

Guard clauses at the top, one line each.

```gdscript
	if !target: return
```

```gdscript
func set_state(state: State) -> void:
	if blocked_states.has(c_state): return
```

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
| `return_value_discarded` | assign the result, or use the call that has none |
| `unused_parameter` | prefix it `_`, which is a rename, not a suppression |

The last row is the only escape hatch, and it changes the code rather than muting the
compiler. If a warning cannot be fixed by typing something, the design is wrong —
usually an untyped `Dictionary` being asked to behave like a class.

## Prohibited

Not "discouraged". These do not appear.

- `match` statements — use `if` / `elif` / `else`
- inner classes, `static` functions, `@tool` scripts, `@abstract`, `@icon`
- custom `Resource` subclasses — config lives in `const Dictionary`
- `Vector2i` — only `Vector2`
- `##` doc-comments
- `@warning_ignore` and every other way of silencing a warning
- editor-generated `_on_<signal>` handlers
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
