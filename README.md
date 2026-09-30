# Tower Battle Royal

A multiplayer **2D platformer battle royale** set inside a vertical tower, built in
**Godot 4.7** (side-view, flat-vector art direction).

Players spawn on random floors of a tall tower, loot weapons, food and rare resources,
fight with guns and melee, travel between floors, and survive as floors are
progressively deleted. Hunger, Rage, elemental weapons, weapon merging and a central
descending platform drive the risk/reward decisions.

## Status

Pre-alpha, built milestone by milestone — **core gameplay first, tested at every step**.
See `docs/DEVELOPMENT_LOG.md` for exactly what exists today.

| Milestone | Contents | State |
| --- | --- | --- |
| M0 | Foundation, autoloads, test harness, debug tools | done |
| M1 | Player: movement, camera, state machine, health, death | next |
| M2 | One floor → reusable floor system | |
| M3 | One gun | |
| M4 | One melee weapon | |
| M5–M6 | Inventory + hotbar; Hunger, Rage, Super Hunger | |
| M7+ | Tower, floor deletion, floor travel, live map, loot, elements, merging, central platform, skins, menu, economy, multiplayer | |

## Getting started

```powershell
# run the automated gate (import pass + headless tests, writes tests/results/last_run.md)
powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1

# play it
Start-Process 'E:\GAMES\Godot_v4.7-stable_win64.exe' -ArgumentList ('--path "' + (Get-Location).Path + '"') -NoNewWindow
```

In game: **F3** toggles the debug overlay, **F10** toggles the cheat console (`help`
lists commands). Both exist only in debug builds.

> Use Godot **4.7**. The `godot` found on PATH is 4.2 and will report bogus parse errors.
> See `docs/TOOLING.md` for toolchain details and `docs/ARCHITECTURE.md` for the
> architecture, conventions and the locked design rules.

## Assets

All current art and audio are procedural placeholders. No third-party or copyrighted
assets are included; any future asset will be original or verified-licensed, and its
source/licence will be documented under `docs/`.
