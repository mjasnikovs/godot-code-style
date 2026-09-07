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

The first six are the ones that make the style self-enforcing. `untyped_declaration`
and `inferred_declaration` together outlaw both `var x = 1` and `var x := 1`. The four
`unsafe_*` errors are why `@warning_ignore` appears at all — each suppression marks a
place where the type system genuinely cannot follow, and is visible in review.

## `.gdlintrc`

At the project root:

```
max-line-length=120
```

Run it over the scripts directory:

```sh
gdlint scripts/
```

`gdformat` is not part of this style. It reflows code in ways the rules above do not
ask for; format by hand and let `gdlint` catch the line length.

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
      message.
- [ ] Cross-scene references go through the global-state autoload. No
      `get_tree().get_root().get_node(...)` outside it.
- [ ] Countdowns decay with `max(0, v - delta)` each frame and are guarded by
      `if v > 0:`.
- [ ] Characters and projectiles in `_physics_process`; visual, UI and timing in
      `_process`.
- [ ] Signals wired with inline `connect(func(...) -> void: ...)`. No `_on_*` handlers.
- [ ] One-shot timers are a local `Timer.new()` with `autostart` and `one_shot`.
      In-function waits use `await`.
- [ ] Cleanup via `queue_free()`. Post-frame cross-object calls via `call_deferred`.
- [ ] Each `@warning_ignore("<code>")` sits directly above the statement it excuses.
- [ ] Static assets use `preload(...)`. Only runtime-discovered paths use `load(...)`.
- [ ] Randomness via the global `rand*` functions, unless a separate stream is needed.
- [ ] No `match`, inner classes, `static`, `@tool`, `Resource` subclasses, `Vector2i`,
      or `##` doc-comments.
- [ ] No `print(...)`. `printerr` for genuine errors.
- [ ] `gdlint` is clean and a headless launch is silent.

## Reviewing an existing file

In order, because each step makes the next one cheaper:

1. Read line 1. A wrong or missing declaration usually means the whole file predates
   the style.
2. Scan for `var` without `:` and for `:=`. Fix those before anything else — typing a
   declaration often reveals a real bug underneath.
3. Look for `_on_` method names and `match`. Both are mechanical rewrites.
4. Check the member order and move blocks. Do this after the rewrites, not before.
5. Add the missing `_ready` asserts last, once the exports have stopped moving.

## Scope

A style guide applies to a directory, not to a repository. State which one — typically
`scripts/` — and let files outside it be out of scope rather than pretending they
comply. A legacy file that predates the style is out of scope until it is rewritten,
and saying so in one line is better than a partial migration nobody can finish.
