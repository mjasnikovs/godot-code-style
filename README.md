# Godot Code Style

One opinionated dialect of GDScript for Godot 4. Every script in a project looks like
it was written by the same person in the same hour.

Where Godot offers two ways to do a thing, this style picks one and treats the other
as a bug. That is the whole value: reading a file tells you nothing new about the
author, so it can tell you something about the code.

Every rule was measured against the working project in `godot/`, not copied from a
tutorial. Four of them changed when the compiler disagreed.

## The one setting

The style is not enforced by discipline. It is enforced by `project.godot`.

```ini
[debug]

gdscript/warnings/untyped_declaration=2
gdscript/warnings/inferred_declaration=2
gdscript/warnings/unsafe_property_access=2
gdscript/warnings/unsafe_method_access=2
gdscript/warnings/unsafe_cast=2
gdscript/warnings/unsafe_call_argument=2
```

The header is part of the key: through an API the name is
`debug/gdscript/warnings/untyped_declaration`. Level `2` is error. `var x = 1` and `var x := 1` both refuse to run. Everything else
in the guide is what a codebase looks like once that is true.

## What it looks like

```gdscript
class_name Player extends CharacterBody2D

enum State {idle, walk, jump, fall, attack, hit}

const blocked_states: Array[State] = [State.attack, State.hit]
const JUMP_VELOCITY: float = -300.0

@export_category("Nodes")
@export var directional: Node2D
@export var animation: AnimationPlayer

var c_state: State = State.idle
var jump_buffer_time: float = 0.0


func _ready() -> void:
	assert(animation, "player.gd - @export animation is not set in the editor on: " + self.name)
	var _error: int = animation.animation_finished.connect(func(_anim_name: StringName) -> void:
		force_state(State.idle)
	)
```

Members in one fixed order. Everything typed. Exports asserted. Signals wired as
lambdas.

## The eight decisions

| # | Situation | This style |
|---|---|---|
| 1 | Reacting to a signal | inline `connect(func(...) -> void: ...)` — never an `_on_*` method |
| 1b | Emitting a signal | a typed method that calls `emit` — `emit` itself is unchecked varargs |
| 2 | A countdown | `float` seconds, `v = max(0, v - delta)` each frame |
| 3 | A delay inside a function | `await get_tree().create_timer(d).timeout` |
| 4 | A delay that outlives the call | local `Timer.new()`, `autostart` + `one_shot` |
| 5 | Reaching another system | through the global-state autoload |
| 6 | Reaching a node in the same scene | `@export` node ref, asserted in `_ready` |
| 7 | Config data | `const Dictionary`, never a `Resource` subclass |
| 8 | Branching on a state | `if` / `elif` / `else`, never `match` |

## What it forbids

`match`, inner classes, `static` functions, `@tool`, custom `Resource` subclasses,
`Vector2i`, `##` doc-comments, editor-generated `_on_<signal>` handlers, `print(...)`
in committed code, and raw `get_tree().get_root().get_node(...)` outside the one
autoload allowed to hold scene paths.

And `@warning_ignore`. There is no suppression of any kind — a warning is a value
whose type you have not declared yet, so declare it.

## Run it

Needs Godot 4.7.2 or newer, and gdtoolkit 4 for the linter.

```sh
cd godot
godot --headless --import
godot --headless --quit-after 180            # must print nothing
gdlint scripts/ tests/
godot --headless tests/verify.tscn --quit-after 400   # 3808 checks, exit 0 = pass
```

All 23 GDScript warnings are set to **error**, including `untyped_declaration`,
`inferred_declaration` and all five `unsafe_*` checks. The project refuses to run if
one fires, and there is not a single suppression in it.

## What measuring changed

| Was | Is now |
|---|---|
| `var _error: Error = ...connect(...)` | `var _error: int` — `connect` returns `int`, so `Error` fires `int_as_enum_without_cast` |
| every `@export` asserted in `_ready` | only node and resource exports; `assert(budget)` rejects a legitimate zero |
| a base-class hook named `_on_ready()` | `_setup()` — the style bans every `func _on_*` name, including its own hook |
| `Global.enemy_died.emit(self)` from a caller | `Global.report_enemy_died(self)` — `unused_signal` only counts uses inside the declaring class, and `emit` type-checks nothing |

## Read it

- **[godot-code-style/SKILL.md](godot-code-style/SKILL.md)** — the whole style in 200
  lines. Start here.
- [godot-code-style/reference/naming.md](godot-code-style/reference/naming.md) — the
  full naming table, enum shapes, custom setters, export grouping.
- [godot-code-style/reference/patterns.md](godot-code-style/reference/patterns.md) —
  the eight decisions in full, plus tweens, `await`, `call_deferred`, randomness,
  `preload` vs `load`, script archetypes.
- [godot-code-style/reference/checklist.md](godot-code-style/reference/checklist.md) —
  the `project.godot` warning block, `.gdlintrc`, the headless check, the pre-commit
  checklist, and how to review an existing file.

## Use it as an Agent Skill

`godot-code-style/` follows the [Agent Skills](https://agentskills.io/specification)
standard. Link it into whichever agent you use:

```sh
ln -s "$PWD/godot-code-style" ~/.claude/skills/godot-code-style   # Claude Code
ln -s "$PWD/godot-code-style" ~/.pi/agent/skills/godot-code-style # pi
ln -s "$PWD/godot-code-style" ~/.agents/skills/godot-code-style   # shared
```

It then fires on its own whenever a `.gd` script is written or reviewed. Only
`SKILL.md` sits in context; the reference files load on demand.

It is also just markdown. Read it directly if you would rather not install anything.

## License

MIT. See [LICENSE](LICENSE).
