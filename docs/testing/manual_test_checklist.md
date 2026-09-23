# Manual test checklist

Automated tests cover logic and physics; they cannot see the screen. Run the relevant
section before marking a milestone done, and fix anything that fails before building on
top of it (the brief's "test every major system" rule).

## How to run

```powershell
powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1     # gate: must be green first
$exe = 'E:\GAMES\Godot_v4.7-stable_win64.exe'
Start-Process $exe -ArgumentList ('--path "E:\Godot Main Projects\Tower Battle Royal\Tower-Battle-Royal"') -NoNewWindow
```

---

## M0 — Foundation  →  status: ready for review

| # | Check | Expected |
| --- | --- | --- |
| 1 | Open the project in the Godot 4.7 editor | No parse errors in the Output panel; the file system lists `scripts/`, `scenes/`, `tests/` |
| 2 | Press F5 (run project) | A dark window shows "TOWER BATTLE ROYAL / foundation online — milestone M0" |
| 3 | Look at the Output panel | `[Boot] engine 4.7-stable …`, `[Boot] input map OK (23 actions)`, no `ERROR:` lines |
| 4 | Press **F3** | Overlay appears top-left with engine, FPS, node count, `match`, `route`, `state` lines; F3 hides it again |
| 5 | Press **F10** | Console opens at the bottom with a focused text field; F10 closes it |
| 6 | In the console type `help` | A sorted list of commands with usage text |
| 7 | Type `state` | `phase=IDLE elapsed=0.0/0.0 alive=0/0 floors=0` |
| 8 | Type `routes` | Registered route `boot` plus a "planned routes" list |
| 9 | Type `scene boot` | The scene reloads (no crash, no error) |
| 10 | Type `nonsense` | `unknown command 'nonsense' — try 'help'` |
| 11 | Type `overlay off` then `overlay on` | Overlay hides/shows |
| 12 | While the console is open, type `wasd` | The letters appear in the field (input is captured, not driving the game) |
| 13 | Resize the window to roughly phone-shaped | Text stays centred and readable (stretch mode) |
| 14 | Alt-tab away and back | No crash, overlay still responsive |

Failure of #1/#3 usually means the project needs an import pass — see `docs/TOOLING.md`.

---

## Template for future milestones

```
## M<n> — <name>  →  status: pending review

| # | Check | Expected |
| --- | --- | --- |
| 1 |                     |          |
```

Gameplay milestones additionally always check:
* the new cheat commands work (spawn/give/force-state),
* the debug overlay reports the new values,
* the previous milestone's checklist still passes (no regressions),
* `tests/results/last_run.md` is green *and* a suite exists for the new system.
