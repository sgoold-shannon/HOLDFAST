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

## Completed: composed main encounter view routing

The active `farm_final.gd` now composes an explicit drawing pipeline through `presentation/view_router.gd`, instead of calling `super._draw()` through the eleven-layer chain. Priority is roster → dialogue/log → mission results → tactical view. Ordered tactical layers and navigation/return/ending overlays preserve the existing sequence and visibility guards. Six tactical layers expose named draw methods; their original `_draw` adapters remain for earlier gate scenes.

This removes inherited drawing traversal from the main scene, not gameplay inheritance. Input dispatch, save orchestration and other controller responsibilities still need consolidation. Some navigation adapter code intentionally remains in both the compatibility scenes and the composed main scene until those adapters can be retired safely.

Validation: five committed suites and C1/C2/D1/D2 regressions pass; all 119 recorded action snapshots match. Router tests cover all 16 roster/dialogue/results flag combinations and exact layer call order for the four screen types. No visual screenshot comparison was performed.

## Completed: validated persistence boundary

`systems/encounter_persistence.gd` provides encounter read/write and checked restoration. It reads through the existing binary store, checks the expected encounter layout, and only then invokes the explicit `apply_loaded_encounter` adapter. Base and B1–B5 loaders now separate validation from applying live state. Main-scene checkpoint/report writes and the existing C2-to-D1 migration use the same persistence entry points.

The binary format, checksum/engine checks, validators, save paths, success/error text and state-application order remain unchanged. Missing, corrupt and wrong-encounter data never reaches the apply callback. Invalid state cannot overwrite a previously valid slot. Application callbacks are trusted adapters; this does not introduce rollback for arbitrary callback errors or atomic transactions across multiple files.

Six committed suites plus B1–B6/C1/C2/D1/D2, clarity and staging-care regressions pass. The new persistence suite checks rejected-load isolation, exact round trips and preservation of existing save bytes. All 119 gameplay snapshots match. Campaign checkpoint ordering, migration policy and layered snapshot assembly remain in controller adapters and are the next persistence work.

```sh
godot --headless --path holdfast --script res://tests/test_persistence.gd
```

## Completed: ordered campaign persistence and migration policy

16 November 2026: `systems/campaign_persistence.gd` owns ordered report/completion and campaign/report/completion writes. It captures state for each attempted write, stops on the first error, and omits completion writes for retry-required outcomes. Already successful files remain saved; this preserves the existing non-transactional multi-file behavior.

`systems/save_migration.gd` owns the existing C2-to-D1 upgrade: copy legacy state, add initial return-map state, write through the validated store, and select the campaign slot only on success. Unreadable and non-C2 saves still go through the normal loader. Live restoration, feedback and snapshot assembly remain in scene adapters. No save format, balance or slot changes.

All six committed suites and B6/C1/C2/D1/D2/staging-care regressions pass. New injected-failure tests cover every checkpoint write position, completion-slot exclusion, snapshot capture order, migration source isolation and write failure. The existing D1 regression exercises actual legacy migration. All 119 recorded action snapshots match.

## Completed: composed main snapshot and extra-state restoration

The main scene now assembles its complete snapshot through `systems/encounter_snapshot.gd`, without traversing inherited `encounter_snapshot` methods. Section order matches the existing binary snapshot exactly. Shared UI, evacuation and story capture methods keep compatibility scenes aligned; all nested mutable values are copied into the result.

Main-scene extra-state restoration now explicitly invokes return-map, results, story and campaign adapters in the original order. Earlier gate scenes retain their inherited compatibility entry points, using the same named state adapters. Common tactical restoration and live state ownership still remain in scene controllers; this is not the removal of gameplay inheritance.

All six committed suites and B1–B6/C1/C2/D1/D2, clarity and staging-care checks pass. New checks verify nested snapshot isolation, serialized key order and extra-state application order. All 119 recorded binary snapshot hashes and route outcomes match the preceding build. Save format and migration policy are unchanged.

## Completed: shared tactical restore sections

`systems/encounter_restore.gd` now sequences validated restoration: extra state, rescue selection, protocol, breaker, evacuation, machine, then tactical/UI state. Each section has one controller adapter reused by subsequent gates. The sandbox supplies only tactical restoration; B1–B5 add their supported sections. This removes repeated state-assignment blocks without changing when movement is rebuilt or which temporary controls are cleared.

All six committed suites and twelve gate/clarity/staging-care regressions pass; all 119 action snapshots match. Added checks verify dependency order independent of callback registration, sandbox-only restoration, temporary input reset and repeated-load stability. The service operates only on validated snapshots and does not roll back callback errors. Live state still belongs to the scene adapters; introducing a dedicated state model and retiring gameplay inheritance remain outstanding.

## Completed: first live-state owner — combat

`state/combat_state.gd` now owns soldiers, enemy actors, phase, shot RNG/history and enemy-activation record/message. It snapshots and restores that data without a scene, input, drawing or disk access. `battlefield.gd` exposes forwarding properties for existing adapters and delegates combat capture/restore to the model. Movement rebuilding and transient UI state remain controller responsibilities.

Acceptance for this slice passes: independent model instances, detached captures/restores, deterministic RNG continuation, seven committed test suites, twelve gate/clarity/staging-care regressions and all 119 binary snapshot hashes unchanged. Machine/protocol/evacuation and campaign/story state still need owners; the dedicated-state step is only partially complete.

## Completed: machine/protocol and evacuation state owners

`state/machine_state.gd` owns machine route/hostility, breaker progress and communication protocol. `state/evacuation_state.gd` owns civilian cohorts/manifests, order allowance, closure status/reason and last civilian phase. Existing adapters forward their properties into these per-encounter models; model restoration copies mutable data. Actor HP/position remain in combat state. Selected group, targeting and confirmation prompts remain controller UI state.

Eight committed suites and twelve regressions pass, with all 119 gameplay snapshots unchanged. Model tests verify independent instances, nested manifest isolation and detached restore/capture. Dedicated-state acceptance remains partial: campaign/story/return history and remaining persistent rescue bookkeeping still need explicit ownership before the composed-controller step.

## Completed: campaign/story/result owners and state inventory

`state/story_state.gd` owns persistent dialogue progress, choices, gate evidence and soldier knowledge. `state/campaign_state.gd` owns campaign/roster history and return-map consequences. `state/result_state.gd` owns verified rescue events and result-finalization flags. UI pages, roster selection, feedback, targeting and file paths remain controller concerns.

Saved-field audit: `combat` → CombatState; `machine`, `breaker`, `protocol` → MachineState; `evac` domain fields → EvacuationState; `rescue_events` and finalization → ResultState; `story` → StoryState; `campaign` and `return_map` → CampaignState. The layout identifier remains mission configuration. Legacy saved `ui`, `evac.selected` and `rescue_target` remain intentional UI compatibility data, not domain-state omissions. Casualty wounds, timers, carrying and medical charges reside on CombatState soldiers.

The dedicated-live-state acceptance criteria are met: eight committed suites and twelve regression checks pass, all model families have instance/deep-copy tests, save round trips and migration remain valid, and all 119 binary snapshot hashes match. Controllers still expose forwarding properties and mutate these models through existing rules. This completes state ownership, not the composed-controller or final cleanup milestones.

## Completed: explicit main-scene input routing

`systems/encounter_input.gd` dispatches events in the existing priority order: ending, return, roster, story, results, rescue, protocol, breaker, civilian, tactical. Each handler reports consumption, including modal blocking. The main scene no longer traverses inherited input entry points. Earlier gate scenes retain compatibility wrappers around the same handlers.

Eight committed suites and twelve regressions pass. Routing tests verify each stopping position and unconsumed events; real-scene checks cover roster/story blocking, isolation confirmation, drop cancellation, civilian orders and aim interactions. All 119 recorded gameplay snapshots and route outcomes match. Gameplay handlers and other lifecycle orchestration still live in inherited adapters, so the composed-controller milestone remains open.

## Completed: explicit encounter completion and post-turn hooks

`systems/encounter_completion.gd` owns the pending/ready guard and the ordered completion sequence: close the operation, clear the pending reason, finalize soldier dispositions, mark results ready, save the report, commit campaign history, then save campaign results. Campaign callbacks are optional for the earlier B6 result fixture. Existing save-failure behavior remains unchanged; this does not add a transaction across files.

The main scene directly composes evacuation/rescue closure, campaign/return history recording and post-turn recovery/finalization/knowledge hooks. These paths no longer traverse gate-to-gate overrides. Completion remains deferred until the enclosing action resolves, with the existing explicit action-end calls preserved. Other gameplay actions, startup and save/load adapters remain inherited; the composed-controller milestone is still open.

Eight committed suites and twelve regressions pass. Completion checks cover pending/ready guards, exact callback order, living/dead/extracted dispositions, finalized report state, repeated calls and earlier-gate compatibility. All 119 recorded gameplay states and six route outcomes match the previous build. No visual playtest was performed for this change.

## Completed: explicit main-scene startup

The main scene now initializes tactical geometry/RNG, machine behavior, evacuation, interaction/rescue data, story, roster and return configuration in an explicit order. It does not traverse inherited `_ready` methods. Earlier gate scenes call the same initialization adapters through compatibility wrappers. Roster initialization receives an explicit resume flag, so the main scene no longer temporarily mutates its auto-resume preference to prevent premature loading.

Return configuration and report paths are established before automatic campaign restoration. Default slot selection and legacy fallback are unchanged. Nine committed suites and twelve regressions pass; all 119 recorded states and six route outcomes match. The startup suite compares fresh main-scene state with the return fixture byte-for-byte, verifies services and instructions, resumes saved progress, respects disabled resume and rejects corrupt state without altering the fresh encounter.

Gameplay action composition, save/load entry-point consolidation and final adapter cleanup/visual acceptance remain outstanding. Startup adapters are still defined in the compatibility classes; explicit orchestration is a step toward removing that dependency, not completion of the composed-controller milestone.

## Completed: explicit main-scene save/load entry points

The main scene now calls the existing persistence and migration services directly rather than traversing inherited save/load overrides. Slot aliases, custom paths, migration-before-lower-alias resolution, validated restoration, campaign checkpoints and success/error feedback retain their previous behavior. Earlier fixtures retain their existing entry points.

Requested-slot success still returns true if the subsequent campaign checkpoint fails, with the checkpoint error shown in feedback; a failed requested write does not attempt that checkpoint. Migration failure leaves live state and result feedback untouched. This preserves the existing contract and does not add multi-file atomicity.

Nine committed suites and twelve regressions pass, with all 119 recorded states and six outcomes unchanged. Direct main-scene tests cover aliases, custom paths, write/checkpoint failures, C2 upgrade and persisted D1 data, unchanged legacy source bytes and migration-write failure. Gameplay actions and remaining compatibility dependencies still need composition before foundation acceptance.

## Remaining sequence before a new mission

Reconciled with the code on 16 November 2026. Simulation, mission definitions, presentation components, main-scene view routing and persistence boundaries are extracted. Compatibility adapters still exist; the foundation phase is not finished.

1. **Dedicated live state — complete.** Combat, machine/protocol, evacuation, story, campaign/return and rescue/result records have independent owners. Instance isolation, detached snapshots, exact RNG restoration, save/migration checks and 119-action parity pass. UI compatibility data remains explicitly separate (see inventory above).
2. **Composed encounter controller — in progress.** Replace the main scene's inherited gameplay/input orchestration with explicit services and state owners. Acceptance: no gate-to-gate dependency in the main controller; preserve modal priorities, action costs, outcome timing, save slots and earlier fixture behavior.
3. **Retire redundant adapters and close foundation — pending.** Remove compatibility code only after replacement coverage exists; retain useful gate fixtures. Acceptance: complete automated suite, recorded-route parity, successful save/migration checks and a focused visual/playable smoke test. Record remaining usability issues separately; do not call automated checks human playtesting.

No new mission, balance change or final isometric conversion belongs to these steps. After foundation acceptance, choose the next gameplay or presentation milestone explicitly. Each pass must name its completed acceptance criteria and outstanding work; moving files alone does not close a step.

## Overwatch scheduling clarification

**Overwatch is deferred until after Gates A–D, alongside suppression and the first armed, moving Grey/Reptilian encounter; it is not an outstanding requirement for the current Farm Road prototype.**

Farm Road's machine can become hostile when attacked, so a theoretical trigger exists. The decision is about sequencing and useful encounter coverage, not a claim that it can never be hostile. No overwatch trigger or suppression rule is added in this refactor. This tracked decision clarifies the schedule; the original v3.1 Word document remains intact.
