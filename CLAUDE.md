# Office Roguelike

Godot 4.7, GDScript. Design: `docs/superpowers/specs/`, plan: `docs/superpowers/plans/`.

Run all tests (headless, fails on any Godot error): `./tools/test.sh`

## GodotPrompter

Before implementing any Godot system, check for a matching `godot-prompter:*` skill and use it
(for example `player-controller`, `state-machine`, `godot-ui`, `godot-testing`). Say which
pattern you picked and which alternative you rejected before you build. This applies to
subagents writing Godot code too.
