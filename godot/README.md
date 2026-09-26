# Verification project

Every rule in the skill, written out as working code and checked four ways.

```sh
godot --headless --import
godot --headless --quit-after 180   # must print nothing
gdformat --check scripts/ tests/
gdlint scripts/ tests/
godot --headless tests/verify.tscn --quit-after 400   # must print nothing
```

`project.godot` sets all 49 GDScript warnings to level 2, which makes them errors. A
silent launch proves that for every script the main scene reaches, and no more. The
self-test loads every script in `scripts/`, so an unreached one fails there instead.
There are no suppressions anywhere.

`tests/verify.gd` is silent when every check passes and prints each failure when one
does not. Most checks read the scripts back as text and assert the style holds —
declaration shape, typing, tabs, line length, assert messages, no prohibited
construct. Member order and naming are `gdlint`'s job. The rest exercise the runtime behaviour: the
state machine's blocked states, buffer decay, the clamping setter, the config
boundary, and typed damage through the base class.
