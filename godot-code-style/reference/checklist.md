# Enforcement and checklist

The style is not a habit. It is a set of settings that refuse anything else, plus one
list you walk before committing.

## The warning block

Put this in `project.godot` under `[debug]`. Level `2` means **error**: the script
will not run.

```ini
[debug]

gdscript/warnings/unassigned_variable=2
gdscript/warnings/unassigned_variable_op_assign=2
gdscript/warnings/unused_variable=2
gdscript/warnings/unused_local_constant=2
gdscript/warnings/unused_private_class_variable=2
gdscript/warnings/unused_parameter=2
gdscript/warnings/unused_signal=2
gdscript/warnings/shadowed_variable=2
gdscript/warnings/shadowed_variable_base_class=2
gdscript/warnings/shadowed_global_identifier=2
gdscript/warnings/unreachable_code=2
gdscript/warnings/unreachable_pattern=2
gdscript/warnings/standalone_expression=2
gdscript/warnings/standalone_ternary=2
gdscript/warnings/incompatible_ternary=2
gdscript/warnings/untyped_declaration=2
gdscript/warnings/inferred_declaration=2
gdscript/warnings/unsafe_property_access=2
gdscript/warnings/unsafe_method_access=2
gdscript/warnings/unsafe_cast=2
gdscript/warnings/unsafe_call_argument=2
gdscript/warnings/unsafe_void_return=2
gdscript/warnings/return_value_discarded=2
gdscript/warnings/static_called_on_instance=2
gdscript/warnings/missing_tool=2
gdscript/warnings/redundant_static_unload=2
gdscript/warnings/redundant_await=2
gdscript/warnings/missing_await=2
gdscript/warnings/assert_always_true=2
gdscript/warnings/assert_always_false=2
gdscript/warnings/integer_division=2
gdscript/warnings/narrowing_conversion=2
gdscript/warnings/int_as_enum_without_cast=2
gdscript/warnings/int_as_enum_without_match=2
gdscript/warnings/enum_variable_without_default=2
gdscript/warnings/empty_file=2
gdscript/warnings/deprecated_keyword=2
gdscript/warnings/confusable_identifier=2
gdscript/warnings/confusable_local_declaration=2
gdscript/warnings/confusable_local_usage=2
gdscript/warnings/confusable_capture_reassignment=2
gdscript/warnings/confusable_temporary_modification=2
gdscript/warnings/inference_on_variant=2
gdscript/warnings/native_method_override=2
gdscript/warnings/get_node_default_without_onready=2
gdscript/warnings/onready_with_export=2
gdscript/warnings/property_used_as_function=2
gdscript/warnings/constant_used_as_function=2
gdscript/warnings/function_used_as_property=2
```

The section header is part of the key. Anything setting these through an API —
`ProjectSettings.set_setting`, an editor plugin, an agent tool — passes the joined
path, `debug/gdscript/warnings/untyped_declaration`, not the line as it appears under
the header. Godot accepts any name and creates the section for it, so a write that
drops `debug/` lands in a `[gdscript]` section, is stored, and is never read. The
block then looks present while nothing enforces it. `godot/tests/verify.gd` checks
all 49 at the real key, and fails on a headerless twin.

That is every warning Godot 4.7.2 has, in the order the engine lists them. Four
ship as errors already; they are written out so the block states the whole rule. The
editor drops those four lines the next time it saves `project.godot`, because they
equal the default. They still read 2.

Six of them make the typing self-enforcing. `untyped_declaration` and
`inferred_declaration` together outlaw both `var x = 1` and `var x := 1`. The four
`unsafe_*` access and cast errors close the gap left behind: a value that reached you as a `Variant`
cannot be used until you have named its type.

There is no suppression in game code. `@warning_ignore` is not part of this style, and
no warning is lowered below `2` to make a file compile. A gdUnit4 suite gets the
file-wide and one-line ignores the `godot-gdunit4` skill names, and nothing else. A warning that fires is a value whose type
you have not declared yet — declare it.

Three moves are legitimate, because each changes the code instead of muting the compiler:

- Rename an unused parameter to `_name`.
- Rename a loop counter nobody reads to `_i`.
- Assign an unwanted return to a typed `_`-prefixed throwaway, one per type per scope.

```gdscript
	var _error: int = animation.animation_finished.connect(func(_anim: StringName) -> void: force_state(State.idle))
	_error = reload_timer.timeout.connect(func() -> void: reload())
	var _collided: bool = move_and_slide()
```

`return_value_discarded=2` is the warning that makes this necessary. `connect` returns
an `int` and `move_and_slide` returns a `bool`, and you almost never want either.
Annotate the connect throwaway as `int`, not `Error` — `Error` is an enum, so it fires
`int_as_enum_without_cast` instead. Measured against Godot 4.7.2.

## `.gdlintrc`

The compiler checks types. `gdlint` checks names and shape, and **its defaults
disagree with this style in five places.** A config with only a line length in it fails
on a correct file. Verified against gdtoolkit 4.5.0 by linting the examples in this
guide.

| gdlint default | This style |
|---|---|
| `enum-element-name` wants SCREAMING | lowercase only: `enum State { idle, walk, jump }` |
| `load-constant-name` also accepts PascalCase | SCREAMING only: `const GOLD_SCENE: PackedScene = preload(...)` |
| `class-variable-name` wants snake_case | also the per-instance `var SPEED` |
| `function-variable-name` forbids a leading `_` | also the `var _error` / `var _collided` throwaways |
| `class-definitions-order` puts signals before the enums and `@onready` after the plain vars | signals after the plain vars, `@onready` right after the exports |

`constant-name` keeps its default, which is SCREAMING only.

Put this at the project root as `.gdlintrc` (or `gdlintrc` — gdlint reads either):

```yaml
max-line-length: 120

class-definitions-order:
- tools
- classnames
- extends
- docstrings
- enums
- consts
- staticvars
- exports
- onreadypubvars
- onreadyprvvars
- pubvars
- prvvars
- signals
- others

load-constant-name: '_?[A-Z][A-Z0-9]*(_[A-Z0-9]+)*'
class-variable-name: '_?([a-z][a-z0-9]*(_[a-z0-9]+)*|[A-Z][A-Z0-9]*(_[A-Z0-9]+)*)'
function-variable-name: '_?[a-z][a-z0-9]*(_[a-z0-9]+)*'
enum-element-name: '[a-z][a-z0-9]*(_[a-z0-9]+)*'
```

Every rule not listed keeps its default. A partial config **merges**, it does not
replace — `trailing-whitespace`, `unnecessary-pass`, `unused-argument`,
`max-file-lines` and the rest still fire. Verified. So do not dump the full default
config with `gdlint -d`; this short file is the whole thing.

Two of these lines narrow a rule to the one form the style allows. Two widen a
rule to accept a form the style requires, the line length widens 100 to 120, and the
order list moves the signals and the `@onready` vars. None of them turns a check off. The `disable:` list stays empty.

Three defaults decide how big things get, and the style keeps all three:

| Rule | Limit | How the style meets it |
|---|---|---|
| `max-returns` | 6 | a branch that picks a value is a `const Dictionary` lookup; one that builds an object assigns a typed local and returns once (`patterns.md`, 8) |
| `max-public-methods` | 20 | a signal emitter only its own class calls is `_`-prefixed; past that, the class splits by concern |
| `max-file-lines` | 1000 | a self-contained group of helpers moves into its own `RefCounted` class, held in a typed member |

Raising one in `.gdlintrc` is the same move as lowering a warning: it hides the
code from the rule. Measured on a 96-script project that had set `max-returns: 10`:
seven if-ladders over an enum sat behind it.

### Run it from the project root

`gdlint` searches for its config **upward from the current directory**, not from the
file being linted. Run it from anywhere else and it silently uses defaults: measured,
this project's correct `scripts/` then reports 24 errors, 10 of them in `player.gd`.

```sh
cd <project root>
gdlint scripts/
```

**Configuring a rule project-wide is not suppression.** It declares the style once, in
one file, where review can see it. A per-line `# gdlint:ignore=` hides one violation
from that declaration, and stays banned. Same line as `@warning_ignore`.

## `.gdformatrc`

`gdformat` owns the layout. Put this next to `.gdlintrc`:

```yaml
line_length: 120
```

Without it `gdformat` wraps at 100, and a line this style allows gets split.
`gdformat` counts a tab as four columns and `gdlint` counts it as one, so
`gdformat` is the stricter of the two and a formatted file always passes the
lint's length check. A
partial config merges with the defaults, like `.gdlintrc`. Like `gdlint`, it finds
the file by searching upward from the current directory, so run it from the
project root.

```sh
gdformat scripts/            # rewrite
gdformat --check scripts/    # CI: exit 1 if any file would change
```

What it changes, measured on gdtoolkit 4.5.0 against this style's own project:

- A guard's `return` moves to its own line: `if !target:` then `return`.
- Enum braces get inner spaces: `enum Direction { left = -1, right = 1 }`.
- A lambda that fits on one line is joined to one line. One that does not is
  wrapped with `func(...)` on its own line inside the call.
- `class_name X extends Y` stays on one line.

Its output passes `gdlint` with the config above and compiles with all 49 as errors.

### An overridable method's parameters take a `_`

A base-class method with a `pass` body does not use its arguments, so both gdlint's
`unused-argument` and Godot's `unused_parameter` fire. Name them with a leading
underscore in the base; the overrides use real names.

```gdscript
func take_damage(_damage: int, _direction: Direction) -> void:
	pass
```

## Headless check

A silent launch is the first test. Every warning is an error, so a broken script prints.

```sh
godot --headless --import
godot --headless --quit-after 180
```

Anything on stdout beyond the engine banner is a failure. In CI:

```sh
status=0
output=$(godot --headless --quit-after 180 2>&1) || status=$?
output=$(echo "$output" | grep -v '^Godot Engine' || true)
if [ -n "$output" ] || [ "$status" != 0 ]; then echo "$output"; exit 1; fi
```

The exit code is checked as well as the output. Godot exits non-zero on a crash that
prints nothing past the banner, and a `| grep` alone would swallow it.

It only parses the scripts the main scene reaches. Measured on 4.7.2: an untyped
script nothing loads printed nothing, and the step passed. So the project also
loads every script by path and checks `can_instantiate()` — `godot/tests/verify.gd`
does it with the autoload registered.

Do not use `godot --check-only --script <file>` for this in a project with an
autoload. It does not register autoloads, so every script that names one fails with
`Identifier not found`.

## Pre-commit checklist

- [ ] Line 1 is `class_name <PascalCase> extends <Base>`, matching the filename.
      Autoloads omit `class_name`.
- [ ] Members in order: `enum` → `const` → `@export`/`@onready` → `var` → `signal` →
      `func`. Functions: engine callbacks in the SKILL's order,
      then public, then private.
- [ ] `const` SCREAMING_SNAKE; vars and funcs snake_case; classes PascalCase; enum
      members lowercase.
- [ ] A SCREAMING `var` exists only for a genuinely per-instance value, bounded by
      `MIN_`/`MAX_` consts.
- [ ] Every `const`, `var`, parameter, local, `for` variable and lambda parameter is
      explicitly typed. Every function ends in `-> Type`, including `-> void`. The one
      untyped parameter is a setter's: Godot 4.7.2 refuses `set(value: int)`, and
      takes the type from the property.
- [ ] Math through the typed helpers: `maxf`, `mini`, `clampf`, `lerpf`, never `max`.
- [ ] `gdformat --check` is clean with `line_length: 120`. Tabs, not spaces.
- [ ] Every export sits under an `@export_category`, a single one included, and every one asserted in `_ready` with
      the `"<file>.gd - @export <name> is not set in the editor on: " + self.name`
      message. Value exports (`int`, `float`, `bool`, `String`) are not asserted.
- [ ] Every signal is emitted from a typed method on its declaring class, never by a
      bare `emit()` from a caller. `emit` is varargs and checks nothing. A gdUnit4 suite
      may emit an engine signal of the scene under test to stand in for the input.
- [ ] No function named `_on_*`. A base-class ready hook is `_setup()`.
- [ ] No node picked out of the tree by position: no `$Path`, `%UniqueName`,
      `get_node(...)`, `has_node(...)`, `find_child(...)`, `find_children(...)`,
      `get_child(i)`, `NodePath(...)`, or an `@onready` wrapping one. A placed node is
      reached through an `@export` slot. A node the script creates keeps the reference
      `instantiate()` or `.new()` returned. `get_children()` stays allowed.
- [ ] Cross-scene references go through the global-state autoload, and each owner
      registers itself there in its own `_ready`.
- [ ] Countdowns decay with `maxf(0.0, v - delta)` each frame and are guarded by
      `if v > 0:`.
- [ ] Characters, projectiles and a camera following one in `_physics_process`; other
      visual, UI and timing logic in `_process`.
- [ ] Signals wired with inline `connect(func(...) -> void: ...)`. No `_on_*` handlers.
- [ ] One-shot timers are a local `Timer.new()` with `autostart` and `one_shot`.
      In-function waits use `await`.
- [ ] Cleanup via `queue_free()`. Post-frame cross-object calls via `call_deferred`.
- [ ] No `@warning_ignore`, `@warning_ignore_start`, `# warning-ignore:` or
      `# gdlint:ignore=` anywhere, and no warning lowered below `2` in `project.godot`.
      gdUnit4 test suites are the one exception, as the SKILL says.
- [ ] Every `Variant` out of a `Dictionary` is read into a typed local before use.
- [ ] Static assets are `const X: T = preload(...)`. Only runtime-discovered paths use
      `load(...)`. `@onready` never preloads.
- [ ] Randomness via the global `rand*` functions, unless a separate stream is needed.
- [ ] No `match`, inner classes, `static`, `Resource` subclasses, `Vector2i`,
      or `##` doc-comments.
- [ ] No `@tool` unless the user approved it for that script. An approved one guards
      every game-only function with an `if Engine.is_editor_hint():` guard.
- [ ] No `print(...)`, tests included. `printerr` for genuine errors and a harness's
      failures; a harness is silent on a pass.
- [ ] No method called through `owner` or `get_parent()`. Typed `@export` reference to
      a real class instead, with a shared base class where a family needs one.
- [ ] Every `await` followed by a node access has an `is_instance_valid(self)` guard in
      game code. A suite or harness is not freed while it waits, so it has none.
- [ ] Discarded returns assigned to a typed `_`-prefixed throwaway.
- [ ] Filenames snake_case and matching the `class_name`. Double-quoted strings.
      `StringName` (`&"idle"`) for engine name comparisons.
- [ ] Two blank lines between functions. Comments say why, never what. No
      commented-out code.
- [ ] Overridable base methods with a `pass` body take `_`-prefixed parameters.
- [ ] `gdformat --check` and `gdlint`, run **from the project root**, are clean, a
      headless launch is silent, and every script loads.
- [ ] A gdUnit4 suite is held to every line above except the exceptions the SKILL
      names: no `class_name`, the fuzzer `:=`, `runner.find_child(...)`, an engine
      signal emitted on the scene under test, and the ignores. Nothing else.

## Reviewing an existing file

In order, because each step makes the next one cheaper:

1. Read line 1. A wrong or missing declaration usually means the whole file predates
   the style.
2. Scan for `var` without `:` and for `:=`. Fix those before anything else — typing a
   declaration often reveals a real bug underneath.
3. Delete every `@warning_ignore`. Whatever then fails to compile is the file's real
   problem, and step 2 usually fixes most of it.
4. Look for `_on_` method names and `match`. Both are mechanical rewrites.
5. Check the member order and move blocks. Do this after the rewrites, not before.
6. Add the missing `_ready` asserts last, once the exports have stopped moving.

## Scope

A style guide applies to a directory, not to a repository. State which one — typically
`scripts/` — and let files outside it be out of scope rather than pretending they
comply. A legacy file that predates the style is out of scope until it is rewritten,
and saying so in one line is better than a partial migration nobody can finish.
