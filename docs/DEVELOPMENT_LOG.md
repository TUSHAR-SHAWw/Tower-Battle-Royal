# Development log

Newest entry first. One entry per meaningful milestone: what was built, what was
tested, what is known-broken, and what happens next.

---

## M0 — Foundation & toolchain — 2026-09-23

### Context
The repository contained only a one-line `README.md`. Engine confirmed as **Godot
4.7 stable**; perspective confirmed by the developer as **2D top-down** with a
flat-vector art direction. This milestone builds the foundation only — no gameplay.

### Implemented
* **Project config** (`project.godot`): 4.7 / GL Compatibility, 1280×720 with
  `canvas_items`+`expand` stretch, landscape handheld orientation, 60 Hz physics,
  `import_etc2_astc` for future mobile export, 10 named 2D physics layers, 23 named
  input actions (movement, twin-stick aim, fire, melee, reload, interact, use, map,
  six hotbar slots, two debug toggles), GDScript warnings raised to catch unsafe access.
* **Autoloads (5):** `SignalHub` (26 signals, zero logic), `GameState` (match phase,
  clock, player counts), `AudioManager` (key-based sound via `SoundLibrary`, silent
  until assets exist), `SceneRouter` (route registry + planned-route reporting),
  `DevTools` (debug-build-only overlay/console host).
* **Core building blocks:** `InputIntent`, `InputSource`, `InputDriver` (keyboard +
  mouse + gamepad, twin-stick), `InputActions`, `State`, `StateMachine`,
  `DamageInfo`, `DamageTypes`.
* **Utilities:** `GameLog`, `MathUtils` (pure helpers incl. seeded `weighted_pick`,
  `spread_direction`, `is_in_cone`), `ObjectPool` (with `_on_pool_acquire/_release`
  protocol).
* **Debug tooling:** `DebugOverlay` (F3, 5 Hz refresh, pluggable providers),
  `CheatConsole` (F10, commands registered by the systems that own them), default
  commands `help/clear/routes/scene/overlay/state/quit`.
* **Boot scene** `scenes/main/Main.tscn` + `Main.gd`: self-check that logs engine
  version, autoloads and input-map validity; registers debug lines.
* **Test framework:** `TestCase` (assertions record failures instead of aborting),
  `TestRunner` (suite discovery, markdown report, watchdog, exit codes), `run_tests.ps1`.
* **8 foundation suites:** signal hub (34), game state (31), scene router (8),
  input actions (66), math utils (535), object pool (28), damage info (38),
  state machine (41).
* **Docs:** `ARCHITECTURE.md`, `TOOLING.md`, testing checklist, this log.

### Files added
`project.godot`, `.gitignore`, `.editorconfig`, `scenes/main/Main.tscn`,
`scripts/autoload/{SignalHub,GameState,AudioManager,SceneRouter,DevTools}.gd`,
`scripts/audio/SoundLibrary.gd`, `scripts/core/{DamageInfo,DamageTypes,InputActions,InputDriver,InputIntent,InputSource,State,StateMachine}.gd`,
`scripts/main/Main.gd`, `scripts/ui/{DebugOverlay,CheatConsole}.gd`,
`scripts/utilities/{GameLog,MathUtils,ObjectPool}.gd`, `tests/TestRunner.tscn`,
`tests/framework/{TestCase,TestRunner}.gd`, `tests/run_tests.ps1`,
`tests/foundation/*.gd` (8 suites), `tests/fixtures/PoolStub.gd`,
`docs/{ARCHITECTURE,TOOLING,DEVELOPMENT_LOG}.md`, `docs/testing/manual_test_checklist.md`.

### Tested
* Gate command: `powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1`
* Result: **PASS — 8 suites, 781 assertions, 0 failures, 616 ms, engine exit code 0**
  (`tests/results/last_run.md`).
* Engine-log scan for `Parse Error|Failed to load script|Failed to instantiate|Invalid
  call|leaked`: **clean**. The only errors/warnings present are the deliberate
  negative-path tests listed in the suites.
* Boot smoke test (headless, 8 s, then killed): `[Boot] engine 4.7-stable (official) |
  autoloads: SignalHub, GameState, AudioManager, SceneRouter, DevTools` and
  `[Boot] input map OK (23 actions)` — all autoloads instantiate and the whole input
  map parses from `project.godot`.
* `run_tests.ps1` exit-code contract verified (0 on green).

### Bugs found and fixed during the gate (all were real, none cosmetic)
1. **`PackedStringArray.join()` does not exist** — the API is `String.join(PackedStringArray)`.
   I had it inverted in five files. Fixed; this would have crashed the debug HUD and the
   cheat console at runtime.
2. **`Array[StringName].sort()` is not alphabetical** — `StringName` does not compare as a
   string, so state/command listings came out in arbitrary order. Replaced with an explicit
   `sort_custom` comparator in `StateMachine` and `CheatConsole`.
3. **Mismatched signal handler signature** — connecting a 2-argument lambda to the 0-argument
   `map_opened` signal silently failed at emission time. Test corrected, and a second test
   added to pin payload/argument agreement for a signal with arguments.
4. **`is_in_cone` checks reach before facing** — my test expectation was wrong, not the code;
   the test now documents the intended order.
5. **Fresh-clone failure mode** — without `.godot/global_script_class_cache.cfg`, `class_name`
   types do not resolve and every script fails to parse with `Could not find type`. The gate
   now runs an `--import` pass first; documented in `TOOLING.md`.

### Known issues / notes
* Balance numbers flagged `# PROTOTYPE DEFAULT` are placeholders (match duration, positional
  voice count) — not design decisions.
* `AudioManager` is fully wired but silent: `resources/audio/sound_library.tres` does not
  exist and the repo contains no audio assets. It warns once per run, by design.
* Nothing has been verified *visually* yet — this gate is headless. F3/F10 are covered by
  `docs/testing/manual_test_checklist.md` and await the developer's run.
* Only `SoundLibrary` exists of the planned resource classes; the rest arrive with their
  milestones — deliberately no empty stub files.
* Two 2D-specific design points stay open and are implemented as *configurable* prototype
  answers: normal floor traversal, and the consequence of standing on a floor when it is
  deleted (`ARCHITECTURE.md` §13).
* `DevTools` is a fifth autoload beyond the four planned. Justification: debug overlay and
  cheat console must exist in *every* scene, and they must not ship in release builds.

### Next step
**M1 — Player:** `Player.tscn` composition (`CharacterBody2D` + components + placeholder
`Visual`), `PlayerConfig` resource, movement with acceleration/friction, floor-clamped camera,
FSM states `Idle/Move/Sprint/Dead`, `HealthComponent` + death, debug HUD lines, and
`tests/player/*` integration tests that drive synthetic `InputIntent`s across real physics
frames. Gate: automation green **and** the developer can move, aim, take damage, die.

