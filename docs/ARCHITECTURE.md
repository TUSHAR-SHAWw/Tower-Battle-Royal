# Tower Battle Royal — Architecture

> Living document. Every milestone updates it (see `DEVELOPMENT_LOG.md`).
> Keep it honest: if the code and this document disagree, one of them is a bug.

## 1. What the game is

A multiplayer **vertical tower survival battle royale**. Players spawn on random
floors of a tall tower, loot weapons/food/resources, fight with guns and melee,
travel between floors, and survive as floors are progressively deleted. Hunger,
Rage, elemental weapons, weapon merging and a central descending platform provide
the risk/reward decisions.

## 2. Locked decisions

| Decision | Value | Why |
| --- | --- | --- |
| Engine | **Godot 4.7 stable** | Installed and already used for this developer's other project |
| Perspective | **2D top-down** | Confirmed by the developer; flat-vector art direction |
| Renderer | `gl_compatibility` | Best fit for flat 2D, mobile and future Web export. All materials avoid forward-only features, so switching to `mobile`/`forward_plus` stays a one-line project setting |
| Tick rate | 60 Hz physics | Determinism for replays, tests and the future authoritative server |
| Units | Pixels (Godot's 2D default) | Player radius ≈ 14 px, floor ≈ 2560×1440 px |
| Combat model | Twin-stick aim (`move_dir` + `aim_dir`) | Works for mouse, gamepad, touch and bots through one interface |
| Tower model | Floors are **separate scenes loaded on demand**, not physically stacked | 12+ floors cost no memory; the map and tower logic never need a floor scene loaded |
| Main scene (now) | `scenes/main/Main.tscn` (boot self-check) | Replaced by the menu (M17) / match (M2) |
| Networking | Designed for, **not built** | Architecture keeps state server-migratable; implementation is M20 |

## 3. Folder map

```
res://
├── project.godot            autoloads, input map, physics layers, renderer
├── .gitignore               ignores .godot/, tests/results/
├── .editorconfig            tabs, LF, UTF-8
├── scenes/                  one folder per gameplay area (main, player, weapons, ...)
├── scripts/
│   ├── autoload/            the five global singletons (see §4)
│   ├── audio/               SoundLibrary resource class
│   ├── core/                engine-agnostic building blocks (input, states, damage)
│   ├── main/                boot scene script
│   ├── player/              player + components (M1)
│   ├── weapons/ melee/ ...  one folder per system, added by its milestone
│   ├── ui/                  HUD / debug UI (code-built, no gameplay logic)
│   └── utilities/           GameLog, MathUtils, ObjectPool
├── resources/               .tres data: player config, weapons, floors, audio, ...
├── assets/                  art/audio; created when real assets arrive
├── tests/                   framework/, foundation/ (suites), fixtures/, results/
└── docs/                    this file, TOOLING, DEVELOPMENT_LOG, testing/
```

Rules of thumb:
* **Logic** lives in `scripts/`, **data** in `resources/`, **presentation** in
  `scenes/`/`ui/`.
* A folder is created when its milestone starts — never in advance.

## 4. Autoloads (and why only these)

| Autoload | Responsibility | Must NOT |
| --- | --- | --- |
| `SignalHub` | Declares every cross-system signal | Hold state or logic, or reference gameplay classes |
| `GameState` | Match phase, clock, player counts, floor count | Touch gameplay nodes; run gameplay logic |
| `AudioManager` | Music/SFX by logical key via `SoundLibrary` | Know what a gun is |
| `SceneRouter` | Boot/menu/match/results route switching | Know what a match is |
| `DevTools` | Debug overlay + cheat console, **debug builds only** | Exist in release builds (it no-ops) |

*Autoload scripts must not declare `class_name`* — the engine already registers the
autoload name as a global; a class with the same name shadows it and breaks startup.

Everything else (`TowerController`, `FloorController`, weapons, HUD…) lives inside
the match scene. A new autoload needs a reason that survives review.

## 5. Scene & component conventions

* Gameplay roots are **plain logic nodes** (`CharacterBody2D`, `Node2D`, `Node`).
* Presentation lives in a child `Visual` node. Gameplay never touches `Visual`;
  `Visual` only receives `set_facing()`, `play_state()`, `flash()`. Placeholder art
  is code-drawn (`_draw()` / `Polygon2D`); swapping in sprites later must not touch
  gameplay code.
* One responsibility per component, one file per component, `##` docs on each.
  Components are `Node`s typed by `class_name`, exposed to the editor with
  `@export`, and must be usable in a headless test without a scene.
* Components talk to their host via `@export` node references (set in the scene) or
  signals — never `get_parent().get_parent()` chains.
* Procedural placeholder art only. No downloaded or copyrighted assets. When real
  assets arrive (developer-provided or verified CC0), record the source and licence
  in `docs/`.

## 6. Core building blocks (`scripts/core`)

| Class | Contract |
| --- | --- |
| `InputIntent` | One frame of *intent*: `move_dir`, `aim_dir`, `aim_position`, action flags, `requested_slot`. Reused per source, never stored beyond the frame |
| `InputSource` | `poll(host) -> InputIntent`. Implementations: `InputDriver` (now), `BotInputDriver` (M7 bots), `NetworkInputDriver` (M20) |
| `InputActions` | Action-name constants + `missing_actions()` self-check against the InputMap |
| `State` / `StateMachine` | Reusable FSM. States are child nodes named by `state_name`; `enter/exit/update/physics_update`; refuses unknown, duplicate, pre-`start()` and nested transitions |
| `DamageInfo` | One damage event: amount, type, element, source, instigator, hit position, knockback, crit. Built with `DamageInfo.create(...)` + fluent `with_*()` |
| `DamageTypes` | Canonical damage-type ids (`bullet`, `melee`, `fall`, `starvation`, …) and `bypasses_defense()` |

**Why intent instead of reading input:** a keyboard player, a bot, a replay and a
remote client must all drive the same components. Components therefore never call
`Input` — that single rule is what makes bot testing (§41) and multiplayer (§40)
possible without rewriting gameplay.

## 7. Damage pipeline

```
weapon / projectile     DamageInfo.create(amount, type, instigator, source)
        │                     .with_knockback(dir, force).with_critical(true)
        ▼
target's HealthComponent.apply_damage(info) -> float   # real damage dealt (M1)
        │   • asks DefenseComponent for incoming multipliers
        │     (melee gun-damage reduction in M4, armor later)
        │   • emits health_changed / died
        ▼
SignalHub.player_damaged  →  HUD, audio, VFX, kill credit, (later) the server
```

Rules: only `HealthComponent` mutates health; `DamageInfo` is passed by reference so
every listener reads the same event; `UNAVOIDABLE`/`STARVATION` bypass defense.

## 8. Signal catalogue (`SignalHub`)

Grouped by domain: match lifecycle, players, combat & items, tower & floors, floor
travel, map/UI, debug. Payloads use the narrowest type that *already exists*;
`Resource` stands in for classes that arrive later and is tightened in the milestone
that adds them (`weapon_changed(owner: Node, weapon: Resource)` → `WeaponData` in M3).

**Rules:** emit facts, never commands. Systems listen; nothing in `SignalHub` listens.
The HUD is a pure listener and never mutates gameplay state.

## 9. Physics layers (2D)

| Layer | Name | Used for |
| --- | --- | --- |
| 1 | World | Floors, walls, cover |
| 2 | Player | Player bodies |
| 3 | Enemy | Bots / AI bodies |
| 4 | PlayerHurtbox | Damageable player area |
| 5 | EnemyHurtbox | Damageable bot area |
| 6 | Projectile | Bullets (pooled) |
| 7 | Interactable | Loot chests, travel items, buttons |
| 8 | Loot | Dropped pickups |
| 9 | FloorZone | Floor triggers, central shaft, deletion volumes |
| 10 | Sensors | AI vision, line of sight |

Set masks in the scene/scene data, not in `_ready()` by hand.

## 10. Data resources (`resources/`)

| Resource | Status | Milestone |
| --- | --- | --- |
| `PlayerConfig` | planned | M1 |
| `FloorData`, `FloorDeletionSchedule` | planned | M2 / M8 |
| `WeaponData` | planned | M3 |
| `MeleeWeaponData` | planned | M4 |
| `ItemData`, `FoodData` | planned | M5 / M6 |
| `LootTable` | planned | M11 |
| `ElementData`, `StatusEffectData` | planned | M12 |
| `MergeRecipe`, `MergeItemData` | planned | M13 |
| `SkinData`, `ShopItemData` | planned | M16 / M18 |
| `SoundLibrary` | **implemented (empty)** | filled when audio exists |

Conventions: `class_name X extends Resource`, `@export` fields with sane defaults,
`resource_local_to_scene = true` for anything mutated at runtime, and an explicit
`# PROTOTYPE DEFAULT — not final` comment on provisional balance numbers.

## 11. Code conventions

Tabs for indentation · UTF-8 · LF · snake_case for files, variables and functions ·
PascalCase for `class_name` · `SCREAMING_CASE` for constants · typed GDScript
(`var x: int`, typed parameters and returns) · `##` doc comments that explain *why*,
not *what* · no `class_name` on autoload scripts · one class per file.

Style is mirrored from this developer's existing Godot project so both repos read
the same way.

## 12. Rules we must NOT silently break

Locked by the design brief; if a new feature conflicts with one of these, stop and
ask instead of quietly changing it:

1. Vertical tower battlefield; players move up and down between floors.
2. Floors progressively disappear and cannot be brought back.
3. Randomised starting floors.
4. A central descending platform that travels top → bottom.
5. Upper floors generally hold better loot; lower floors keep a melee-oriented identity.
6. Melee weapons reduce incoming gun damage.
7. Rage synergises with melee.
8. Hunger is a survival system, not a second health bar.
9. Super Hunger exists as a distinct, configurable state.
10. Special food gives buffs/debuffs; rotten food accelerates Hunger/Rage.
11. Elemental weapons exist; merging two elemental weapons costs a very rare item
    and is always a strategic decision.
12. Exactly one floor-changing item per player at match start; it is slow, has a
    cooldown, warns the destination floor, and spawns the traveller in that floor's centre.
13. Normal camera shows one floor; the map is the only whole-tower view.
14. The hotbar is Minecraft-*structured* (six slots, categories, keys 1–6) with
    original art.
15. Skins are cosmetic only — never any gameplay advantage.
16. Currency: gems (premium-style) and coins (earned); data-driven prices.
17. Visual direction: clean flat vector, bold shapes, crisp outlines.

## 13. Deliberately still configurable (never hardcode)

Floor count · player count · match duration · floor layouts and deletion schedule ·
weapon and melee stats · elemental effects · merge recipes and merge-item spawn
rates · Hunger/Rage/Super-Hunger values · food values · travel duration, cooldown and
interruption rules · central platform speed and loot · inventory size · victory rules ·
matchmaking · monetisation.

Prototype defaults are guesses that live in `.tres`/config constants and are flagged
as such. They are *not* design decisions.

Known 2D-specific open questions (configurable prototype answer chosen, developer
confirmation pending):
* normal floor traversal: stairs/elevator markers in `FloorData` **and** an optional
  drop through the central shaft, versus the travel item alone;
* what happens to a player standing on a floor when it is deleted
  (`ELIMINATE` / `DAMAGE` / `DROP_TO_NEIGHBOUR`).

## 14. Milestone map

| Milestone | Contents | State |
| --- | --- | --- |
| **M0** | Foundation: project config, autoloads, test harness, debug tools, docs | **done** |
| M1 | Player: movement, camera, FSM, health, death | next |
| M2 | One floor → reusable `FloorData`/`FloorController`, match scene | |
| M3 | One gun (data-driven, pooled projectiles) | |
| M4 | One melee weapon + gun-damage reduction | |
| M5 | Inventory + six-slot hotbar | |
| M6 | Hunger, Rage, Super Hunger skeleton, food | |
| M7 | Multiple floors, transitions, detection | |
| M8 | Floor deletion (warning → collapse → deleted) | |
| M9 | Floor travel item (select, long travel, warning, centre arrival) | |
| M10 | Live tower map | |
| M11 | Loot tables | |
| M12 | Elements + status effects | |
| M13 | Weapon merging (recipes, tiers) | |
| M14 | Central descending platform | |
| M15 | Weapon roster expansion (data only) | |
| M16 | Player skins | |
| M17 | Main menu | |
| M18 | Economy, shop, packs, save | |
| M19 | Polish: VFX/SFX/animation | |
| M20 | Multiplayer (server-authoritative) | |

## 15. Testing & debug tooling

* **Framework:** `tests/framework/TestCase.gd` (assertions that record failures instead
  of aborting) + `TestRunner.gd` (discovers suites, writes `tests/results/last_run.md`,
  returns an exit code, has a watchdog).
* **Suites:** `tests/foundation/*` cover core contracts. New systems add a suite in the
  same milestone that introduces them — no milestone is "done" without one.
* **Run it:** `powershell -ExecutionPolicy Bypass -File tests\run_tests.ps1` (see
  `docs/TOOLING.md` for the manual equivalent and why the command looks unusual).
* **Debug overlay (F3):** FPS, node count, plus any line registered via
  `DevTools.register_provider(label, callable)`.
* **Cheat console (F10, backtick-free):** commands registered via
  `DevTools.register_command()`. Systems own their own cheats.
* Both tools vanish in release builds (`OS.is_debug_build()`), so gameplay code may
  call `DevTools.*` unconditionally.

## 16. Performance notes

* Pool anything that spawns per shot (`ObjectPool`, used by projectiles in M3).
* Never allocate in `_process`; reuse (e.g. one `InputIntent` per source).
* Only the floor the player is on exists as a scene; others are data.
* `DebugOverlay` refreshes at 5 Hz, not per frame.
* Prefer signals and physics-frame logic over per-frame polling; profile before optimising.


