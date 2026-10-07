# Tower Battle Royal

A **2D tower survival platformer** built in **Godot 4.7** (side-view, pixel-art
presentation). The initial release target is **single-player on Windows and
Android**; online multiplayer is planned for a later update, not a launch feature.

Players spawn on random floors of a tall tower, loot weapons, food and rare resources,
fight with guns and melee, travel between floors, and survive as floors are
progressively deleted. Hunger, Rage, elemental weapons, weapon merging and a central
descending platform drive the risk/reward decisions.

## Shipping status

**Pre-alpha prototype; not ready to ship.** The automated Godot 4.7 import and
headless test gate currently passes (16 suites, 1,404 assertions). That does not
yet prove the full match loop, exported builds, or target-device behavior. See
[`docs/SHIPPING_READINESS_PLAN.md`](docs/SHIPPING_READINESS_PLAN.md) for the
release gates and [`docs/DEVELOPMENT_LOG.md`](docs/DEVELOPMENT_LOG.md) for
implementation history.

| Area | Current status |
| --- | --- |
| Player, tower, combat, items and progression systems | Implemented as prototype systems; end-to-end shipping validation remains |
| Automated test gate | Passing; not a substitute for manual or device QA |
| Startup, menu and results flow | Boot currently opens the match directly; player-facing flow is unfinished |
| Online multiplayer | Prototype code is not integrated or end-to-end tested; deferred until after single-player launch |
| Windows release build | No Windows export template or preset is currently available in the checked environment; package still to be verified |
| Android release build | No Android export template is currently installed; touch controls, export setup and device testing remain |

The 50-floor map and lift now share live tower data; the sprite-based lift
travels up/down the route, while the compact minimap and full map show floor
themes, player/lift floors and exploration status. Automated physics integration
verifies the production player can board the lift, ride to the next floor, and
have the camera track the ride. The nine-slot hotbar has been reduced to leave
more of the play area visible. Themed shaft loot and floor backdrops use
controls and bundled sprite/tile assets rather than drawing callbacks. The map
also indicates whether the player is left or right of the central shaft. This
is a presentation pass with placeholder art, not final environment content;
custom 8×8 floors and visual polish remain planned.

## Pixel-art scale

The game canvas is **426×240**, presented at **3× integer scale** (1278×720)
using canvas-item stretching so text and vector UI render at display resolution.
Gameplay retains the established framing through a matching camera zoom;
physics and gameplay world coordinates are not rescaled.
Author floor atlases with **8×8 source-pixel tiles**; `FloorController` scales
8×8 `TileMapLayer` atlases so each source pixel is 3 screen pixels (24×24 screen
pixels per tile). Keep textures on nearest-neighbor filtering. Larger atlas tile
sizes retain their authored node scale. HUD and map overlays retain their
1280×720 design coordinates within the 3× output.

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

The repository includes procedural placeholder art and bundled third-party asset
packs. Before release, audit the origin, license and attribution requirements of
every asset group and document the results; the current license files do not cover
all included asset folders.
