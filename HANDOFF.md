# Handoff — Tower Battle Royal

Written by an agent that ran out of context. Read this before changing anything.

## Environment (important gotchas)

- Godot: `E:\GAMES\Godot_v4.7-stable_win64.exe`. Project: `E:\Godot Main Projects\Tower Battle Royal\Tower-Battle-Royal`
- **The Windows Godot binary does not attach stdout to PowerShell pipes.** `godot ... | Out-File` produces empty files. Use this instead, which works reliably:
  ```powershell
  $p = Start-Process -FilePath "E:\GAMES\Godot_v4.7-stable_win64.exe" `
        -ArgumentList "--path",".","res://your_test.tscn" `
        -RedirectStandardOutput "out.txt" -RedirectStandardError "err.txt" -PassThru -NoNewWindow
  if (-not $p.WaitForExit(90000)) { $p.Kill(); Write-Output "TIMED OUT" }
  Get-Content out.txt | Select-String -Pattern "^\[TAG\]"
  ```
  Always use a timeout — several harnesses hung when a scene failed to quit.
- After adding a new `class_name` script, run `godot --headless --editor --quit --path .` once or the global class cache won't know it and you get "Could not resolve class X".
- Run tests: `godot --headless --path . res://tests/framework/TestRunner.tscn` → report at `tests/results/last_run.md`.

## Current test state

**Latest gate: 15 suites, 1,281 assertions, 0 failures** using
`powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1`.

## Pixel-art scale

The logical viewport is 426×240, shown at 3× integer scale in a 1278×720
window. Use 8×8 atlas tiles for new floors: `FloorController` scales those
TileMapLayers to 24 screen pixels per tile and converts ground-surface
coordinates through the layer transform. Camera zoom is 13/60 to preserve the
previous camera framing; gameplay physics/world coordinates are not rescaled.
The HUD and map overlay controls use a 1280×720 design-space wrapper. Verify
Android and other desktop resolutions separately; their exact scaling has not
yet been device-tested.

The previous 9 player-suite failures were caused by tests calling the asynchronous
`_drive()` helper without `await`; assertions ran before their simulated physics
frames completed, and the abandoned coroutines later accessed freed fixtures. All
calls now await the helper. The jump-camera assertion also found the camera's
vertical dead zone too small for the actual configured held jump; the default
zone was increased and documented. The automated gate is green, but a human
keyboard/gamepad and camera playtest is still required.

**Initial release scope confirmed:** Windows + Android, single-player first;
online multiplayer is deferred to a later update. Android export templates are
not installed in the current development environment. See
`docs/SHIPPING_READINESS_PLAN.md` for the remaining gates and scope questions.

## Verified working

- **50 floors, randomly themed, stacked.** Floors 1–50 at `y = -1080 * (floor_id - 1)`, via `TowerController._place_in_tower()`. Stacking must come from node position — `FloorData.bounds` is canonical and `validate()` rejects anything else.
- **5 themes**: volcano, ice, mountain, water, desert. `theme_water.tres` was created by me. Randomised with seed `20261004` (in `build_tower.py`, since deleted — re-create or hand-edit if rerolling). Central platform at floor 25.
- **Per-theme TileMapLayers**: `TowerTileSetBuilder` exposes 5 solid atlas sources (`THEME_SOURCES` + `source_for_theme()`); `FloorController` picks by `floor_data.theme_name`. Decor uses a separate collision-free source (`SOURCE_DECOR`) — important, or scenery becomes invisible platforms that trap the player.
- **Lowest floor is sealed**: `FloorController` passes `shaft_width = 0` for `floor_id <= 1`. Verified — player dropped on the exact map centre lands (`on_floor=true`) instead of falling out.
- **HUD renders**: instanced into `Match.tscn` as `ExtResource("7_hud")`, `layer = 120` (above `DebugOverlay`'s 100). `BackgroundCard` must stay a plain `Control`, **not** a `PanelContainer` — a PanelContainer stretches its child across the whole screen.
- **HUD signals**: health, hunger, rage, XP, wave and floor updates now have
  visible controls. `EnemySpawner` no longer emits an invalid one-argument
  `SignalHub.wave_started`; `FloorController` forwards wave events with the
  floor ID. `tests/ui/hud_test.gd` covers the signal-to-widget updates; visual
  layout still needs desktop/Android playtesting.
- **Combat smoke tests**: gun fire now acquires a pooled Bullet with an
  actor-hurtbox detector and world collision; the player scene's `MeleeHitbox`
  is now an `Area2D` running `MeleeHitbox.gd`. `tests/combat/combat_test.gd`
  verifies enemy AI movement, projectile and melee damage against the production
  `Enemy.tscn`, and exactly one global enemy-death event.
- **Wave/reward integration**: `EnemySpawner` staggers wave spawns, waits for
  pending and living enemies before completing a wave, and reports final-wave
  completion. Tests verify killer attribution and resource-scaled XP/gold.
  Enemy deaths now create physical world pickups independently of the killer's
  inventory; an integration test verifies world placement, player collection
  through body/hurtbox overlap, and inventory update. Drop probability remains
  tunable; balance and repeated loot behavior still need playtesting.
- **Stacked-floor coordinates**: enemy spawn positions preserve world coordinates
  on offset floors; floor portals/bosses use floor-local positions, and match
  camera limits use the tower-shifted floor rectangle. Tests cover these
  transforms and destination-floor placement. Actual portal activation through
  the warning/collapse/deletion transition now has an automated integration test.
  Match completion/restart still needs end-to-end validation.
- **Camera floor framing**: fixed the floor world rectangle to include both its
  canonical local origin and tower offset. Previously limits began at world
  `(0, 0)` instead of `(-3200, -1080)`, clamping the initial camera at the origin
  and leaving the spawned player off-screen. Relaunched and visually verified:
  player and floor now appear together in the initial view.
- Camera clamping now accounts for half the visible world size, preventing
  out-of-bounds void from appearing beyond the floor edges; floor-travel camera
  snaps now land exactly on the clamped target. Corrected the view-size
  calculation for Godot zoom semantics as well: world-space view size is
  viewport size divided by zoom, not multiplied by it.
- **Travel completion**: `TowerController` now completes the floor switch when
  the departing `FloorController` reaches `DELETED`, retaining a 20-second
  fallback for floor implementations without a deletion-state signal. The
  integration test verifies portal activation, delayed deletion, one-time
  deletion notification and destination-floor handoff.
- **Physics-flush-safe portal creation**: portal collision shape attachment is
  deferred until after tree initialization. Deferring monitoring flags alone
  was insufficient when a portal is created inside `area_entered`; the shape
  now exists before monitoring is enabled.
- Camera follows player, clamped to floor bounds with overshoot.

## Open bugs, in priority order

### 1. Match loop needs end-to-end verification
Automated tests cover projectile/melee combat, wave scheduling/completion,
killer attribution and XP/gold reward scaling, enemy death through physical
loot pickup/inventory, plus portal activation through delayed floor deletion
and floor handoff. Still verify loot balance, range/aim behavior, repeated
combat, and victory/defeat/restart in a running match.

### 2. Debug overlay still covers top-left HUD
HP bar and `WAVE 1` are hidden under it. Raising the HUD layer to 120 did **not** fix it, so the overlay is drawing via some path other than its `CanvasLayer.layer` (probably a root-level `Control` with its own `z_index`). `scripts/ui/DebugOverlay.gd` extends `CanvasLayer`, `layer = 100`. Either find the real draw path or gate the overlay behind its F3 toggle.

### 3. Floor art pipeline is still placeholder quality
`FloorTileLayout` now limits background accents to 0.2% of room cells; the
regression gate confirms the full floor remains walkable and has at most 100
accents. A live-game screenshot confirms the room is much less noisy, but the
slab still repeats small atlas tiles and the room has little authored detail.
`PropSpawner.gd` is not instantiated or called by production floor scenes.
Before treating floor art as shippable, establish a theme-aware workflow for
larger asset props and floor surfaces; do not mistake sparse procedural accents
for finished environment art.

## Queued: adopt reference project node combos

Reference: `E:\Godot Projects\First Game` (a working platformer). Findings:

**Level (`game.tscn`)** — floor is a `TileMapLayer` with **baked** `tile_data`, not generated at runtime:
```tscn
[node name="TileMapLayer" type="TileMapLayer" parent="."]
tile_set = SubResource("TileSet_wvtw0")
layer_1/name = "Mid"
layer_1/tile_data = PackedInt32Array(196609, 0, 0, ...)
```
TileSet authored as an in-scene `SubResource`. Props grouped under plain `Node` containers (`Coins/`, `Platforms/`, `Labels/`). A `Killzone` Area2D guards the bottom.

**Player (`player.tscn`)** — only 3 nodes: `CharacterBody2D` + `AnimatedSprite2D` + `CollisionShape2D`.

**Camera** — child of player: `zoom = Vector2(4,4)`, `limit_bottom`, `limit_smoothed = true`, `position_smoothing_enabled = true`.

| | Reference | This project |
|---|---|---|
| Floor | baked `tile_data` | painted procedurally in `FloorController._build_tile_layers()` |
| TileSet | in-scene SubResource | built in code by `TowerTileSetBuilder` |
| Player | 3 nodes | ~25 nodes, one per component |
| Camera | built-in smoothing | custom `CameraComponent` lerp + manual clamps |

The valuable idea is **baked tile data** — it would let floors be hand-painted in the editor and persist, replacing the procedural layout that produces the noisy decor. Note `FloorTileLayout` currently *is* the floor, so this is a bigger change than it looks. Suggested order: combat → HUD wave bug → then decide on the floor migration.

## Traps that already bit me (don't repeat)

- **`sub_resource` blocks must come BEFORE the nodes referencing them.** Cost me three broken scenes.
- **Script-backed sub-resources** need `type="Resource"` plus an explicit `script = ExtResource(...)` line. `[sub_resource type="MyClass"]` fails with "Can't create sub resource of type".
- **A `sub_resource` id must not collide with an `ext_resource` id.**
- **Node `parent` paths are relative to the scene root.** `parent="HUD/BackgroundCard"` is wrong when the root *is* `HUD` — nodes get silently flattened with mangled names like `HUD_BackgroundCard#HealthPanel`, and script `$Path` lookups then fail. Use `parent="BackgroundCard"`.
- **`CollisionShape2D` under a plain `Node2D` does nothing** — needs a `CollisionObject2D` parent.
- **New scripts deleted by another tool pass**: check `git status` for unexpected ` D` entries before assuming a file is intentional. `TestRunner.tscn` had been deleted, so no tests ran at all.
- **Duplicate function definitions** are a parse error; a script that fails to compile is **silently skipped** by `StateMachine.setup()`, which surfaces only as an empty `current_state_name()`.
- `match` is a **reserved GDScript keyword** — don't name a variable that.
- PowerShell `-replace` with `$`-prefixed GDScript paths interpolates and eats them; use Python scripts for multi-line text edits.

## Layout

- `scripts/` — `main/` (Match), `tower/` (TowerController, TileSetBuilder, TravelPortal), `floors/` (FloorController, FloorTileLayout, FloorVisual, PropSpawner, PropVisual), `player/` (Player, components, `states/`), `ui/`, `weapons/`, `melee/`, `map/`, `core/`, `autoload/`
- `scenes/` — mirrors the above; `scenes/main/Match.tscn` is the entry point
- `resources/floors/` — 50 `floor_NN.tres` (FloorData) + 5 `theme_*.tres`
- `resources/tower/` — 50 `floor_NN_data.tres` (TowerData) + `tower_definition.tres` (the 50-floor list)
- `tests/` — `framework/TestRunner.{gd,tscn}` (the `.tscn` had to be recreated), suites incl. `player_test.gd`, `tower_test.gd`