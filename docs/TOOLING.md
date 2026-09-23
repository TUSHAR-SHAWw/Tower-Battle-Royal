# Tooling

## Engine

Use **Godot 4.7**:

```
E:\GAMES\Godot_v4.7-stable_win64.exe
```

* Do **not** use bare `godot` from the PATH: it resolves to **4.2 stable** and will
  report confusing parse errors for 4.7 project settings.
* The 4.7 Windows build is a **GUI-subsystem executable** with no `_console.exe`
  sibling installed. Consequences:
  * launching it with `&` returns before the process exits (the shell does not wait);
  * launched plainly, `print()` output never reaches a terminal.
  * Fix for both: `Start-Process -FilePath <godot> -ArgumentList <args> -NoNewWindow -Wait -PassThru`
    which attaches stdout to the current console *and* waits for the exit code.
* Export templates for `4.7.stable` and `4.2.stable` are installed; **no Android
  templates** for 4.7 yet.

## Common commands

Run the whole test gate (import + tests, prints the report):

```powershell
powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1
powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1 -SkipImport -ShowLog
```

Equivalent manual steps:

```powershell
$exe = 'E:\GAMES\Godot_v4.7-stable_win64.exe'
$p   = 'E:\Godot Main Projects\Tower Battle Royal\Tower-Battle-Royal'

# 1. Import/scan: registers global class names, reports parse errors in every script
Start-Process $exe -ArgumentList ('--headless --quiet --path "' + $p + '" --import') -NoNewWindow -Wait

# 2. Headless tests (writes tests/results/last_run.md, exit code 0 = green)
Start-Process $exe -ArgumentList ('--headless --path "' + $p + '" res://tests/TestRunner.tscn') -NoNewWindow -Wait

# 3. Play the game
Start-Process $exe -ArgumentList ('--path "' + $p + '"') -NoNewWindow

# 4. Open the editor
Start-Process $exe -ArgumentList ('--path "' + $p + '" -e')
```

### The import step matters

`.godot/global_script_class_cache.cfg` is what makes `class_name` types resolvable.
A **fresh clone** (or any new `class_name` script) needs an `--import` pass before a
headless run, otherwise the engine reports `Could not find type "X" in the current
scope` for every script that uses it. `run_tests.ps1` therefore imports first — and
that pass doubles as a project-wide parse check.

## Logs

| What | Where |
| --- | --- |
| Engine log of the last run | `%APPDATA%\Godot\app_userdata\Tower Battle Royal\logs\godot.log` |
| Test report (markdown) | `tests/results/last_run.md` (git-ignored) |
| Tagged gameplay logs | in the engine log, prefixed `[Boot]`, `[StateMachine]`, `[Tests]`… |

Expected noise in the log: the foundation suites deliberately exercise failure paths
(unknown scene route, unknown state, releasing a foreign pooled node), so a handful of
`ERROR:`/`WARNING:` lines with test backtraces are normal. The report is the verdict.

## Test / script exit codes

| Code | Meaning |
| --- | --- |
| 0 | all assertions passed |
| 1 | at least one assertion failed |
| 2 | watchdog timeout (a suite hung) |
| 3 | runner setup problem (Godot not found / no report written) |

## Project settings that are load-bearing

| Setting | Value | Why |
| --- | --- | --- |
| `rendering/renderer/rendering_method` | `gl_compatibility` | 2D performance + mobile/Web reach. Do not use forward-only features |
| `physics/common/physics_ticks_per_second` | 60 | Determinism for tests and future authoritative multiplayer |
| `display/window/stretch/*` | `canvas_items` + `expand` | One UI layout for desktop and phone |
| `input` | 23 named actions | Mirrored by `InputActions`; a suite fails if they drift |
| `layer_names/2d_physics/*` | 10 named layers | See ARCHITECTURE.md §9 |
