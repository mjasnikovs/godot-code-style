# Enforcement and checklist

The style is not a habit. It is a set of settings that refuse anything else, plus one
list you walk before committing.

## The warning block

Put this in `project.godot` under `[debug]`. Level `2` means **error**: the script
will not run.

```ini
[debug]

gdscript/warnings/untyped_declaration=2
gdscript/warnings/inferred_declaration=2
gdscript/warnings/unsafe_property_access=2
gdscript/warnings/unsafe_method_access=2
gdscript/warnings/unsafe_cast=2
gdscript/warnings/unsafe_call_argument=2
gdscript/warnings/unsafe_void_return=2
gdscript/warnings/unused_variable=2
gdscript/warnings/unused_parameter=2
gdscript/warnings/unused_signal=2
gdscript/warnings/shadowed_variable=2
gdscript/warnings/standalone_expression=2
gdscript/warnings/return_value_discarded=2
gdscript/warnings/static_called_on_instance=2
gdscript/warnings/redundant_await=2
gdscript/warnings/assert_always_true=2
gdscript/warnings/assert_always_false=2
gdscript/warnings/integer_division=2
gdscript/warnings/narrowing_conversion=2
gdscript/warnings/int_as_enum_without_cast=2
gdscript/warnings/confusable_identifier=2
gdscript/warnings/confusable_local_declaration=2
gdscript/warnings/confusable_local_usage=2
```

The section header is part of the key. Anything setting these through an API —
`ProjectSettings.set_setting`, an editor plugin, an agent tool — passes the joined
path, `debug/gdscript/warnings/untyped_declaration`, not the line as it appears under
the header. Godot accepts any name and creates the section for it, so a write that
drops `debug/` lands in a `[gdscript]` section, is stored, and is never read. The
block then looks present while nothing enforces it. `godot/tests/verify.gd` checks
all 23 at the real key, and fails on a headerless twin.

The first six are the ones that make the style self-enforcing. `untyped_declaration`
and `inferred_declaration` together outlaw both `var x = 1` and `var x := 1`. The four
`unsafe_*` errors close the gap left behind: a value that reached you as a `Variant`
cannot be used until you have named its type.

There is no suppression. `@warning_ignore` is not part of this style, and no warning is
lowered below `2` to make a file compile. A warning that fires is a value whose type
you have not declared yet — declare it.

Two moves are legitimate, because both change the code instead of muting the compiler:

- Rename an unused parameter to `_name`.
- Assign an unwanted return to a typed `_`-prefixed throwaway, one per type per scope.

```gdscript
	var _error: int = animation.animation_finished.connect(on_finished)
	_error = self.area_entered.connect(on_area_entered)
	var _collided: bool = move_and_slide()
```

`return_value_discarded=2` is the warning that makes this necessary. `connect` returns
an `int` and `move_and_slide` returns a `bool`, and you almost never want either.
Annotate the connect throwaway as `int`, not `Error` — `Error` is an enum, so it fires
`int_as_enum_without_cast` instead. Measured against Godot 4.7.2.

## `.gdlintrc`

The compiler checks types. `gdlint` checks names and shape, and **its defaults
disagree with this style in six places.** A config with only a line length in it fails
on a correct file. Verified against gdtoolkit 4.5.0 by linting the examples in this
guide.

| gdlint default | What it rejects here |
|---|---|
| `enum-element-name` wants SCREAMING | `enum State {idle, walk, jump}` — 6 errors from one line |
| `constant-name` wants UPPER_SNAKE | `const blocked_states: Array[State]`, `const magnum_1` |
| `load-constant-name` wants PascalCase or UPPER | `const gold: PackedScene = preload(...)` |
| `class-variable-name` wants snake_case | the per-instance `var SPEED` |
| `function-variable-name` forbids a leading `_` | the `var _error` / `var _collided` throwaways |
| `class-definitions-order` puts signals second | this style puts them after the plain vars |

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

constant-name: '_?([A-Z][A-Z0-9]*(_[A-Z0-9]+)*|[a-z][a-z0-9]*(_[a-z0-9]+)*)'
load-constant-name: '_?(([A-Z][a-z0-9]*)+|[A-Z][A-Z0-9]*(_[A-Z0-9]+)*|[a-z][a-z0-9]*(_[a-z0-9]+)*)'
class-variable-name: '_?([a-z][a-z0-9]*(_[a-z0-9]+)*|[A-Z][A-Z0-9]*(_[A-Z0-9]+)*)'
function-variable-name: '_?[a-z][a-z0-9]*(_[a-z0-9]+)*'
enum-element-name: '([a-z][a-z0-9]*(_[a-z0-9]+)*|[A-Z][A-Z0-9]*(_[A-Z0-9]+)*)'
```

Every rule not listed keeps its default. A partial config **merges**, it does not
replace — `trailing-whitespace`, `unnecessary-pass`, `unused-argument`,
`max-file-lines` and the rest still fire. Verified. So do not dump the full default
config with `gdlint -d`; this short file is the whole thing.

Each of these six lines widens a rule to accept the form the style already requires.
None of them turns a check off. The `disable:` list stays empty.

### Run it from the project root

`gdlint` searches for its config **upward from the current directory**, not from the
file being linted. Run it from anywhere else and it silently uses defaults, and a
correct file reports 18 errors.

```sh
cd <project root>
gdlint scripts/
```

**Configuring a rule project-wide is not suppression.** It declares the style once, in
one file, where review can see it. A per-line `# gdlint:ignore=` hides one violation
from that declaration, and stays banned. Same line as `@warning_ignore`.

`gdformat` is not part of this style. It splits `class_name X extends Y` onto two
lines, among other reflows the rules above do not ask for. Format by hand and let
`gdlint` catch the line length.

### An overridable method's parameters take a `_`

A base-class method with a `pass` body does not use its arguments, so both gdlint's
`unused-argument` and Godot's `unused_parameter` fire. Name them with a leading
underscore in the base; the overrides use real names.

```gdscript
func take_damage(_damage: int, _direction: Direction) -> void:
	pass
```

## Headless check

A silent launch is the test. Every warning is an error, so any script problem prints.

```sh
godot --headless --import
godot --headless --quit-after 120
```

Anything on stdout beyond the engine banner is a failure. In CI:

```sh
output=$(godot --headless --quit-after 120 2>&1 | grep -v '^Godot Engine' || true)
if [ -n "$output" ]; then echo "$output"; exit 1; fi
```

## Pre-commit checklist

- [ ] Line 1 is `class_name <PascalCase> extends <Base>`, matching the filename.
      Autoloads omit `class_name`.
- [ ] Members in order: `enum` → `const` → `@export`/`@onready` → `var` → `signal` →
      `func`.
- [ ] `const` SCREAMING_SNAKE; vars and funcs snake_case; classes PascalCase; enum
      members lowercase.
- [ ] A SCREAMING `var` exists only for a genuinely per-instance value, bounded by
      `MIN_`/`MAX_` consts.
- [ ] Every `const`, `var`, parameter, local, `for` variable and lambda parameter is
      explicitly typed. Every function ends in `-> Type`, including `-> void`.
- [ ] Tabs, not spaces. Lines ≤ 120.
- [ ] Exports grouped with `@export_category` and every one asserted in `_ready` with
      the `"<file>.gd - @export <name> is not set in the editor on: " + self.name`
      message. Value exports (`int`, `float`, `bool`, `String`) are not asserted.
- [ ] Every signal is emitted from a typed method on its declaring class, never by a
      bare `emit()` from a caller. `emit` is varargs and checks nothing.
- [ ] No function named `_on_*`. A base-class ready hook is `_setup()`.
- [ ] No node picked out of the tree by position: no `$Path`, `%UniqueName`,
      `get_node(...)`, `has_node(...)`, `find_child(...)`, `find_children(...)`,
      `get_child(i)`, `NodePath(...)`, or an `@onready` wrapping one. A placed node is
      reached through an `@export` slot. A node the script creates keeps the reference
      `instantiate()` or `.new()` returned. `get_children()` stays allowed.
- [ ] Cross-scene references go through the global-state autoload, and each owner
      registers itself there in its own `_ready`.
- [ ] Countdowns decay with `max(0, v - delta)` each frame and are guarded by
      `if v > 0:`.
- [ ] Characters and projectiles in `_physics_process`; visual, UI and timing in
      `_process`.
- [ ] Signals wired with inline `connect(func(...) -> void: ...)`. No `_on_*` handlers.
- [ ] One-shot timers are a local `Timer.new()` with `autostart` and `one_shot`.
      In-function waits use `await`.
- [ ] Cleanup via `queue_free()`. Post-frame cross-object calls via `call_deferred`.
- [ ] No `@warning_ignore`, `@warning_ignore_start`, `# warning-ignore:` or
      `# gdlint:ignore=` anywhere, and no warning lowered below `2` in `project.godot`.
- [ ] Every `Variant` out of a `Dictionary` is read into a typed local before use.
- [ ] Static assets use `preload(...)`. Only runtime-discovered paths use `load(...)`.
- [ ] Randomness via the global `rand*` functions, unless a separate stream is needed.
- [ ] No `match`, inner classes, `static`, `@tool`, `Resource` subclasses, `Vector2i`,
      or `##` doc-comments.
- [ ] No `print(...)`. `printerr` for genuine errors.
- [ ] No method called through `owner` or `get_parent()`. Typed `@export` reference to
      a real class instead, with a shared base class where a family needs one.
- [ ] Every `await` followed by a node access has an `is_instance_valid(self)` guard.
- [ ] Discarded returns assigned to a typed `_`-prefixed throwaway.
- [ ] Filenames snake_case and matching the `class_name`. Double-quoted strings.
      `StringName` (`&"idle"`) for engine name comparisons.
- [ ] Two blank lines between functions. Comments say why, never what. No
      commented-out code.
- [ ] Overridable base methods with a `pass` body take `_`-prefixed parameters.
- [ ] `gdlint` run **from the project root** is clean, and a headless launch is silent.

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
