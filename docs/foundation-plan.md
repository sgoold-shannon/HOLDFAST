# Foundation restructuring

Decision date: 15 November 2026. Design baseline: GDD v3.1, with the overwatch scheduling clarification below.

## Why

The active `farm_final.tscn` currently reaches the tactical base through eleven script layers. Each prototype gate added behavior through inheritance, including drawing, input, save handling and mission logic. The chain is useful history, but it should not become the template for a new campaign mission.

Restructure incrementally, keeping playable builds, old saves, deterministic action outcomes and the earlier gate scenes working. No new mission or combat rule is part of this pass.

## Completed: civilian simulation extraction

`holdfast/systems/civilian_evacuation.gd` is an independent `RefCounted` component. It owns the algorithms for safe pathfinding, complete route previews, route choice, following a soldier, waiting reasons and bounded civilian movement. It does not load a scene, draw, read input, advance turns or write saves.

Its constructor accepts explicit mission callbacks:

- Whether a cell is safe now.
- The waypoint for a route and the current civilian exit.
- Whether a route is available now.
- Whether a soldier can currently lead.
- Notification after an actual civilian step (for mission evidence/history).

Cohort and soldier dictionaries are supplied by the caller. The service does not cache the soldier array; loading or replacing a mission therefore cannot leave followers attached to stale state. Only `move_cohort` mutates a cohort. Path inspection and route selection leave state untouched. The existing east/north/south/west tie order is preserved.

`farm_evac.gd` now delegates to this component through compatibility methods. It still owns the civilian panel and controls, order allowance, turn sequencing, casualty effects, operation closure and save serialization. Existing return-map and breaker overrides supply the same live mission policies as before. The complete inheritance chain is **not removed yet**.

## Verification for this pass

- Independent 6×5-map tests instantiate only the component, without Farm Road. They cover route ties, changing route availability and hazards, no-route cases, a different exit, leader loss, replacement actor arrays, hold, stranded/extracted groups and exact step notifications.
- The full Follow rescue still evacuates 12 civilians and all four soldiers on origin and return in round 7. A legal wounded-leader rescue also evacuates all 12 and extracts MSG in round 7.
- Before/after snapshots match exactly after 119 legal actions across divert, disable, destroy, pause-only, nonintervention and early withdrawal. Outcome metrics also match.
- Opening/debrief, persistent roster, return consequences, ending fixture, civilian guidance, saves and staging-care regressions pass.

Run the committed tests from the repository root:

```sh
godot --headless --path holdfast --script res://tests/test_civilian_rules.gd
godot --headless --path holdfast --script res://tests/test_follow_rescue.gd
```

## Completed: machine activation and turn resolution

`holdfast/systems/machine_activation.gd` now owns patrol activation, occupied-cell impacts, charged fixed-cell shots, nearest eligible target selection, next-cell prediction, disabling, one-time pause, diversion and betrayal recovery. It takes caller-owned state and a mission plan; terrain/pathfinding, occupancy and damage arrive through explicit callbacks. It returns an action message and whether movement previews need rebuilding. It does not advance rounds, finalize reports, draw, process input, or save.

`farm_road.gd` retains the once-per-phase guard and delegates activation. Breaker and protocol layers now supply mission-plan fields rather than overriding activation or target selection. The peaceful return still supplies its explicit no-hostile-activation policy. Player weapon attacks and machine presentation remain outside this component.

`holdfast/systems/turn_resolution.gd` makes the sequence explicit:

1. Ignore gameplay resolution if the encounter is already ended.
2. Run pre-machine casualty checks; halt if the MSG bleeds out.
3. Clear pending early-close confirmation and resolve the machine action.
4. If the action ended the encounter, skip civilian movement and AP reset.
5. Move civilians, then evaluate the deadline before the complete-evacuation condition.
6. Close the operation or begin the next player phase and refresh eligible AP/attack allowances.
7. Run result/recovery/knowledge completion hooks, including on halted turns.

The rescue, result and story layers now provide named before/after hooks instead of overriding `next_phase`. Damage can request completion during an activation, but the entire enclosing activation still resolves before final dispositions. Phase guards and save-state ownership remain in the controller; the components add no hidden persistent state.

Validation: all 119 legal-action snapshot hashes and six route outcomes match the previous version. B1–B6, C1/C2, D1/D2, staging care and civilian guidance checks pass. The committed independent machine/turn test covers neutral versus hostile activation, fixed-cell damage after a target moves, target tie order and eligibility, pause/disable behavior, blocked and completed diversion, betrayal impacts and collection, destroyed/departed machines, deadline ordering, bleed-out and fatal-action halts, and finalization. Full Follow origin, return and wounded-leader runs also pass.

```sh
godot --headless --path holdfast --script res://tests/test_machine_turns.gd
```

## Completed: mission definitions and objective policies

The resources in `holdfast/missions/` now define the tactical sandbox, Farm Road and northbound return: board bounds, walls, cover, starting cells, machine routes, fixtures, civilian routes, exits and closure rules. `systems/mission_objectives.gd` evaluates deadlines and completion using those definitions and live encounter facts. Turn resolution calls that policy after civilian movement. Mutable actors, saves and mission selection remain controller-owned.

A custom 8×8 test map verifies that geometry, starts, cover, exits and completion conditions can change without editing the controller. All 119 recorded action snapshots still match, and existing mission and rescue regressions pass. The inherited scene adapters and mission-specific dialogue remain; this does not yet make arbitrary new campaign missions plug-and-play. Save validation still targets the existing mission family and retains its format. A new campaign mission needs an explicit save mapping or tested migration.

## Presentation direction: isometric tactical view

The intended final presentation is an angled/isometric tactical map inspired by XCOM and Shadowrun. The current square, top-down board is a mechanics prototype. The eventual choice between 2D artwork and a 3D scene remains open; this decision adds no elevation, diagonal movement or combat rules.

`presentation/grid_projection.gd` separates logical cells from screen coordinates and picking. Tests cover all 320 cells using both square and diamond-shaped bases (640 round trips). The playable renderer still uses the square basis. Terrain and unit drawing, depth ordering, camera framing and HUD separation must be completed before enabling an isometric view. Logical movement, cover and saves should remain independent of presentation coordinates.

```sh
godot --headless --path holdfast --script res://tests/test_missions_projection.gd
```

## Completed: terrain display boundary and tactical input translation

`presentation/board_view.gd` draws terrain, coordinate labels, walls, squad exits, selection outlines and movement costs from a detached display snapshot. It receives no encounter controller or gameplay callbacks. The controller computes legal movement costs; the renderer only displays them. This is the first view extraction, not the completion of presentation restructuring. It still draws square tiles and assumes the current screen layout.

`presentation/tactical_input.gd` translates keys and button hit tests into named intents. The controller dispatches those intents through its existing gameplay methods. Key release and repeated-key events remain ignored. Existing inherited modal handlers retain priority, and mouse coordinates are still converted through the current canvas transform before hit testing.

Character/target drawing, path and sight overlays, the tactical HUD, civilian panel, opening, roster and debrief views remain in the scene layers. Those are the next extraction work; this pass does not enable isometric rendering or remove the inheritance chain.

Validation: all 119 recorded gameplay snapshots match the prior version. Independent civilian, machine/turn, mission/projection and full Follow rescue tests pass. The new presentation test verifies key/button mapping, ignored releases/repeats, aim/clear dispatch, terrain labels and wall markers, detached display data and unchanged encounter state after drawing. Automated drawing checks do not replace a visual playtest.

```sh
godot --headless --path holdfast --script res://tests/test_presentation.gd
```

## Completed: soldier markers and tactical overlays

`presentation/actor_view.gd` renders soldier shapes, initials, health tint and the selection ring from marker data. `presentation/tactical_overlay.gd` renders movement paths, sight cells, wall blockers, aim lines and cover edges from detached display data. The controller still computes paths, sight and eligibility; the renderers cannot issue gameplay actions. Drawing order and square-tile dimensions are unchanged.

The tactical HUD, mission-specific machine/civilian drawing, hazard overlays and opening/roster/debrief panels still remain in scene layers. This pass extracts soldier markers, not every actor in the encounter. It does not enable an isometric renderer.

All five committed test suites pass, including new marker, route, blocked-aim, invalid-target and display-data isolation checks. All 119 recorded gameplay snapshots match the preceding build. These are automated checks; visual playtesting remains useful.

## Completed: machine/civilian views and gameplay panels

Four additional renderers receive detached snapshots rather than the encounter controller:

- `machine_view.gd`: track, fixtures, skid, impact/charged-shot warnings, machine hull/HP and pinned blast outline.
- `civilian_view.gd`: route waypoints, selected-group path, civilian exit and active group badges.
- `tactical_panel.gd`: selection/aim details, squad cards, tactical action buttons and save feedback.
- `civilian_panel.gd`: group cards, order controls, waiting reasons, evacuation totals, closure confirmation and deadline footer.

Pathfinding, danger forecasts, eligibility, order labels and combat previews are still computed by the controller through the same existing policies. Input hit regions and modal priority are unchanged. Drawing remains in the same order, with square-tile dimensions and the existing interface layout.

All five committed suites pass. Added renderer checks cover snapshot isolation, hostile/absent machine states, extracted-group visibility and early-close confirmation/cancel labels. All 119 recorded action snapshots match the preceding build. No visual screenshot comparison was performed.

Opening, roster, debrief, rescue/interaction panels and mission-specific overlays remain in the inherited scene adapters. Their extraction and the removal of layered drawing are still outstanding; the final isometric renderer is not enabled.

## Completed: narrative, roster, results and interaction panels

Six more snapshot-based renderers now own the main content of opening/log/debrief dialogue (`story_panel.gd`), persistent roster (`roster_panel.gd`), mission results (`results_panel.gd`), casualty rescue controls/markers (`rescue_panel.gd`), breaker controls/confirmation (`breaker_panel.gd`) and protocol controls/diversion hints (`protocol_panel.gd`). Eligibility, dialogue selection, history generation and forecast pathfinding remain in controller adapters. No renderer receives gameplay callbacks.

The existing roster history-page clamp now runs in its snapshot adapter instead of during rendering. Input routing and modal visibility still belong to the scene adapters, preserving their precedence. Small title/navigation overlays, return/final mission drawing and the inheritance chain remain; this is not yet a shallow composed controller or the final isometric presentation.

Validation: all five committed suites and seven targeted B3–B6/C1/C2/staging-care regressions pass. Renderer checks exercise all six snapshots, opening choice labels, roster page bounds and breaker confirmation/cancel controls. The 119-action before/after comparison still matches exactly. No visual screenshot comparison was performed.

## Completed: modal event translation and return/ending overlays

`presentation/modal_input.gd` translates keys, button hits and indexed rows into named intents for dialogue, roster and results. Scene adapters retain screen visibility, global shortcuts, action dispatch and inherited priority. Unknown events remain consumed by open modal screens. Repeated/released keys and non-left mouse clicks produce no intent; buttons retain priority over rows. The controller still performs canvas-to-local conversion before hit testing.

`return_overlay.gd` and `ending_overlay.gd` now draw return-mission information, cooling/repair hints, roster deployment overlays and the ending-test entry from detached snapshots. Small header/navigation overlays, other interaction input handlers and the inheritance chain remain. No new gameplay or isometric rendering is enabled.

All five committed suites and six targeted narrative/roster/results/return/ending/staging-care regressions pass. Added checks cover modal key isolation, roster selection and underlying dialogue restoration, click precedence, ignored events and overlay data isolation. All 119 recorded action snapshots match the prior build. No visual screenshot comparison was performed.

## Completed: interaction intent translation

Civilian order/card controls, breaker confirmation, protocol actions and casualty action buttons now share the event-to-intent decoder through `interaction_command`. Controllers retain gameplay dispatch, map selection, drop targeting and the exact inherited priority. Civilian exit/follow buttons still precede map selection; cards precede route/closure buttons. Isolation confirmation still consumes competing inputs, and aiming still disables the breaker mouse button. Existing drop-mode Escape and post-closure save/load semantics are unchanged.

All five committed suites and B2–B5 regression checks pass. New direct input tests cover isolation blocking rescue/protocol/end-turn, cancellation, aim-mode breaker exclusion, civilian card/order dispatch and drop-targeting isolation. All 119 action snapshots match the preceding build. The small overlays, remaining outer routing and deeper controller/save restructuring are still outstanding.

## Completed: shared small overlays

`scene_chrome.gd` centralizes base/scene headers, navigation buttons and the civilian instruction banner. `machine_status.gd` draws danger, intent, forecast, save feedback and pinned-machine details from a detached snapshot. Existing layer order, text, dimensions and screen visibility are preserved. Input/controller adapters still decide what is shown; inheritance and save orchestration remain future work.

All five committed suites pass, including small-overlay geometry/text and snapshot-isolation checks. All 119 recorded gameplay snapshots match. Installed in the Desktop project and tracked on the HOLDFAST Trello board. No visual screenshot comparison was performed.

## Remaining sequence before a new mission

1. Separate HUD/input and opening/roster/debrief views from simulation. Remove inherited drawing overlays as those views move.
2. Move save orchestration to a boundary that serializes the same checked state. Preserve old saves or provide an explicit tested migration before changing formats.
3. Introduce a shallow encounter controller that composes the extracted services. Keep gate scenes as fixtures until parity checks pass, then retire redundant adapters deliberately.

Each step should ship with equivalence and failure-path checks. File movement alone does not count as finishing the architecture work.

## Overwatch scheduling clarification

**Overwatch is deferred until after Gates A–D, alongside suppression and the first armed, moving Grey/Reptilian encounter; it is not an outstanding requirement for the current Farm Road prototype.**

Farm Road's machine can become hostile when attacked, so a theoretical trigger exists. The decision is about sequencing and useful encounter coverage, not a claim that it can never be hostile. No overwatch trigger or suppression rule is added in this refactor. This tracked decision clarifies the schedule; the original v3.1 Word document remains intact.
