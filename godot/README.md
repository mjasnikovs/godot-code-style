# Verification project

Every rule in the skill, written out as working code and checked three ways.

```sh
godot --headless --import
godot --headless --quit-after 180   # must print nothing
gdlint scripts/ tests/
godot --headless tests/verify.tscn --quit-after 400
```

The second command is the real gate. `project.godot` sets all 23 GDScript warnings to
level 2, which makes them errors, so a silent launch means every script in `scripts/`
is fully typed and free of unsafe access. There are no suppressions anywhere.

`tests/verify.gd` runs 3663 checks. Most of them read the scripts back as text and
assert the style holds — declaration shape, member order, typing, tabs, line length,
assert messages, no prohibited construct. The rest exercise the runtime behaviour: the
state machine's blocked states, buffer decay, the clamping setter, the config
boundary, and typed damage through the base class.
