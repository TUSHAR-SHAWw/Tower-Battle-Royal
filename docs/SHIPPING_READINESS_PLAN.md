# Shipping Readiness Plan

**Baseline reviewed:** 2026-10-06  
**Current assessment:** Pre-alpha prototype; not ready to ship.

This plan is the release-readiness source of truth until the project adopts a
tracked issue/release system. Milestones are gated: do not advance a release gate
while its exit criteria are failing.

## Baseline

- Godot 4.7 import completes successfully.
- Initial headless run: **11 suites, 1,175 assertions, 9 failures**, all in
  player movement/camera tests. The player suite called its asynchronous movement
  driver without awaiting it, so assertions ran before the simulated frames had
  completed and leftover coroutines accessed freed fixtures. The camera's
  vertical dead zone was also too small for the actual configured held jump.
- Current headless run after correcting the test/camera issues, wiring HUD
  updates and adding production-enemy integration coverage: **15 suites, 1,281
  assertions, 0 failures**. See
  [`tests/results/last_run.md`](../tests/results/last_run.md).
- Pixel-art scale is configured for a 426×240 logical canvas at 3× integer
  output (1278×720), with 8×8 source tiles targeting 24×24 screen pixels.
  Camera zoom retains the previous framing without changing physics units.
  Actual authored floors and target-device scaling still need manual validation.
- Floor background accents have been reduced from 10% to 0.2% of room cells;
  the density regression passes and the live-game screenshot confirms the
  repeated specks are sparse. Environment art is still placeholder quality:
  the slab repeats small atlas tiles, and `PropSpawner` is not wired into
  production floors. A theme-aware, asset-friendly art workflow remains part
  of Gate 3.
- Enemy AI movement, gun projectiles, melee damage and single emission of the
  global enemy-death signal now pass automated integration tests against the
  production `Enemy.tscn`. The spawner suite also verifies staggered spawns,
  wave completion, killer attribution, resource-scaled XP/gold, and spawn
  positions on a stacked floor. A tower integration test now exercises portal
  activation through delayed floor deletion and destination-floor handoff.
  A controlled enemy-death-to-physical-pickup-to-inventory integration test now
  passes. Loot balance/repeated drops in a real match and
  victory/defeat/restart remain to be playtested.
- HUD now has live health, hunger, rage, ammo, gold, XP, wave and floor UI
  with an automated signal-update suite; end-to-end presentation still needs
  playtesting.
- Startup routes through a boot scene directly into the match. Menu/results and
  other routes are still planned.
- There is no checked-in export preset or CI release build. The installed Godot
  4.7 template directory currently contains Web templates only; Windows and
  Android export templates are absent.
- Asset provenance is incomplete/inconsistent: some included asset packs have
  license files, but not every asset group has an evident attribution/license
  record.
- Historical entries in the development log still describe older milestone
  snapshots; treat them as history rather than the current shipping status.

## Decisions to lock before feature completion

1. **Launch platforms:** Windows desktop + Android selected. Minimum supported
   hardware/OS and distribution channels remain to be defined.
2. **Multiplayer:** single-player first is confirmed; online multiplayer is
   deferred to a later update. Gate 4 is not an initial-release gate.
3. **Product scope:** single-player is confirmed. Confirm final match length,
   tower size, progression/persistence, and whether shop/currency/battle pass
   are launch requirements.
4. **Content and legal:** approve final art/audio direction and confirm the
   commercial-use rights and attribution requirements for every shipped asset.

Record decisions in the project documentation before treating dependent
milestones as committed scope. Windows + Android and single-player-first are
confirmed; minimum device specs, distribution channels, progression/persistence,
and monetization remain open dependencies—not assumptions.

## Release gates

| Gate | Priority | Work | Exit criteria |
|---|---|---|---|
| 0. Scope and baseline | P0 | Resolve the decisions above; reconcile the README, architecture, handoff, and development log into one accurate status and feature list. Choose one canonical tower size and match loop. | A reviewed launch scope exists; documentation agrees on current behavior and on what is deferred. |
| 1. Core stability | P0 | Fix player movement, jump, camera, spawn/grounding and death/revive failures. Add regression coverage for any root cause found. Keep import/parse diagnostics and headless tests in the gate. | Fresh import succeeds; all tests pass repeatedly; manual keyboard/gamepad control and camera checks pass in the Godot 4.7 editor. |
| 2. Playable match loop | P0 | Verify end-to-end spawn → move/traverse → loot → fight → floor hazard/deletion → victory/defeat → results/restart. Enemy AI, gun/projectile, melee damage, one-time death signaling, staggered wave completion, killer attribution, XP/gold reward scaling, stacked-floor spawn coordinates, portal-to-floor-deletion handoff, and controlled enemy-death-to-pickup-to-inventory flow now have automated coverage; extend it to full-match loot balance and match termination. Repair HUD signal wiring and live health/hunger/rage/XP/ammo/floor/wave updates. | Automated tests cover the critical loop; a human can complete and restart a match without errors, blockers, or stale critical UI. |
| 3. Launch UX and content | P1 | Implement only the menu, settings, pause, results and onboarding required by Gate 0. Add usable Android touch controls and validate UI layouts on target aspect ratios. Use the 8×8/24-screen-pixel art scale; define theme-aware floor surfaces and props; replace procedural placeholder floors with approved, licensable assets. Tune balance using recorded playtests; finish launch visuals/audio and accessibility basics. Defer nonessential shop/battle-pass systems unless explicitly in scope. | New player can launch, understand controls/objectives, finish a match, and return/restart on Windows and Android; touch controls and device layouts pass playtests; floor assets read coherently at gameplay camera scale and pass provenance review. |
| 4. Multiplayer (post-launch) | Deferred | Integrate networking into the real match flow. Test host/server and clients across connect, spawn, movement, combat, authority/validation, disconnect/reconnect and match end. Exercise latency/loss and capacity targets. | Two or more independent clients complete a match reliably; invalid inputs do not grant authority; disconnects and server errors have defined outcomes; automated integration coverage passes. |
| 5. Persistence, economy and policy (conditional) | P1 if in scope | Define and implement save format/migrations, account/backend responsibilities, economy rules, privacy/consent and purchase handling only for features approved in Gate 0. | Data survives supported upgrades; recovery/error behavior is tested; legal, privacy and platform requirements are reviewed. |
| 6. Build, QA and release | P0 | Create export presets for agreed platforms; automate clean import, tests and exports; document versioning/signing/release steps. Audit asset licenses/attributions and dependencies. Test exported builds on target devices. Run crash/performance, resolution/input, accessibility and regression passes; prepare rollback/support notes. | Reproducible clean build/export; all release gates pass; no known blocker/critical defects; target-device smoke tests, asset audit, store materials and release checklist are signed off. |

## Recommended execution order

1. Gate 0 decisions and status reconciliation.
2. Gate 1 stability. **The player test sequencing and camera jump dead-zone
   fixes are complete; the full automated gate is green.** HUD signal handlers
   are wired and tested. Continue with real editor playtesting and the remaining
   stability checks.
3. Gate 2 end-to-end game loop. Combat, wave/reward mechanics, portal/deletion
   handoff, and loot pickup/inventory have automated coverage; continue with
   full-match loot tuning and match result/restart paths in a running match.
4. Gate 3 player-facing release flow and content.
5. Defer Gate 4 until after the single-player release.
6. Gate 5 only for approved persistence/economy scope.
7. Gate 6 build, target-device QA, legal/content audit and ship decision.

Do not put calendar estimates on these gates until launch scope, team capacity,
and target platforms are known. Each gate should be tracked as separate issues
with an owner, test evidence, and an explicit pass/fail status.

## Ongoing release rules

- Every gameplay bug fix includes a regression test when practical.
- Keep the import + headless test gate green; do not accept failures as baseline.
- Test actual exported builds, not only editor/headless runs.
- Preserve the latest test report and manual QA evidence for each candidate.
- Update this plan and the feature/status docs when a scope decision changes.
