# HOLDFAST

A character-driven tactical sci-fi prototype built in Godot. The design baseline is **HOLDFAST Game Design Document v3.1**, included at the repository root.

## Run without the editor (Mac)

Double-click **Play HOLDFAST.command**, beside the `holdfast` folder. This opens the playable demo directly with the tested compatibility renderer, bypassing editor inspection/input modes. Godot must be installed at `/Applications/Godot.app`. Existing saves are used normally. Close the game window to stop it.

If an embedded run appears frozen, use this launcher. Standalone GUI-input tests verify Fit, 3×, scrolling and Preview/Back. The reported editor-specific freeze has not been reproduced or conclusively diagnosed; this is a tested alternative launch path, not a claim that all editor issues are fixed.

## Run the prototype

Open `holdfast/project.godot` in Godot and press **F5**. The project has been tested with **Godot 4.7.2**. The main scene is `farm_final.tscn`; `battlefield.tscn` retains the earlier tactical sandbox.

The prototype contains the Farm Road encounter, conditional debrief, persistent roster, a return mission affected by the earlier machine outcome, and a separate ending logic test. It is not a complete campaign. The ending fixture's 24 passengers are test data, not accumulated campaign rescues.

## Current foundation status

The active encounter now uses `encounter_controller.gd` directly under Node2D, through the stable `farm_final.gd` entry point. It no longer depends on the prototype gate inheritance chain. State ownership, controller separation and foundation acceptance are complete. See the [verification record](docs/verification/foundation/README.md) for test evidence, screenshots and remaining readability issues. Earlier gate scenes are retained as regression fixtures.

## 3D evacuation practice

Run the demo normally and click **3D Preview** at the upper right. Select a soldier or their bottom-panel button, hover a highlighted cell to preview the route, then click to move. Green costs **1 AP**, blue costs **2 AP**. **Reset practice** restores the squad; **Back to demo** restores your untouched original encounter. Scroll zooms and Home fits the map.

The camera looks from behind the squad toward the enemy, so advances move upward on screen. Select a **Group A/B/C** button, then **Evacuate** to choose an exit route, **Follow soldier** to follow your selected soldier, or **Hold** to stop. You can issue one free group order per turn; orders persist. **End turn** resolves machine actions, moves ordered civilians and refreshes AP. At the teal exit cells, use **Extract soldier** (1 AP). The live display tracks turns, machine intent and evacuated people. Practice uses production rules but never saves campaign progress. **Combat:** select a soldier, then click **Target machine** at the upper right (or click the machine). Review the hit chance and warnings, then click **Fire**; targeting alone never fires. Fire and Reload each cost 1 AP; each soldier can attack once per turn. Squad cards show ammunition as rounds/4. The machine label shows HP and neutral/hostile status; orange marks movement danger and red marks a charged shot. **Rescue:** select a standing rescuer, then click a critical/stable teammate’s card. Move adjacent, then use **Stabilize** (1 AP and a medical charge) and **Carry** (1 AP). Stabilizing stops bleeding but does not restore the casualty’s ability to act. Carriers have limited movement and cannot fire. At extraction, **Extract soldier** brings both out. **Put down** then a free adjacent cell releases the casualty for 1 AP; **Cancel put down** returns to movement. Critical labels show bleeding turns remaining. **Equipment / protocol** opens the panel at the upper right. MSG can Observe then Transmit a one-turn pause; Bell can Authenticate and Divert from beside the console at (11,12), before skid collection. Each action costs 1 AP. Beside the breaker at (9,4), open the housing, request isolation, then confirm its consequences (or cancel free). Blocked attempts explain their requirements in the panel. See the [presentation plan](docs/presentation-plan.md).

## Readability

The demo starts at **3× magnification**. Scroll to pan; Shift + scroll moves sideways. Use **Fit**, **2×**, or **3×** at the bottom to change the view. Home returns to the top-left. Fit scales the full page into the space above the toolbar, adjusting when the viewport changes. At 3× you will need to pan to reach parts of the map and the civilian panel.

## Rescue civilians

1. Select group **A**, **B**, or **C** using its card on the right.
2. Choose **Move to EXIT** to select an available evacuation route. A highlighted path shows the selected group's route.
3. Press **N** to end the turn. After the machine responds, ordered groups move up to three cells.
4. Order the other groups on later turns. **Orders persist**; you do not need to renew them each turn.

You get **one free civilian-group order per player phase**, shared across all groups. It does not spend soldier AP. Reaching the civilian exit automatically evacuates that group. The road deadline still applies after the machine is destroyed.

To escort a group, select a standing soldier on the map, select the group, then choose **Follow**. The group moves toward a cell adjacent to that soldier. It waits if the leader goes down or the path is blocked; choose another order to redirect it. After the leader extracts, followers continue toward the civilian exit. **Hold Position** stops a group and provides no cover bonus.

## Tactical controls

| Control | Action |
| --- | --- |
| Click a soldier, then ground | Select and move |
| T | Toggle movement / aiming |
| Click machine while aiming, then F | Pin target and fire |
| R | Reload |
| N | End turn |
| E | Extract selected soldier from a squad exit tile for 1 AP |
| S / U / J | Stabilize / pick up / put down selected casualty |
| V | Cycle casualties |
| K / L | Save / load the current mode's slot |
| Tab | Scene log and intelligence |
| G | Roster |
| T in the roster | Staging care for extracted recovering survivors |

The machine starts neutral. Orange marks its next impact cell; an occupant takes four damage. Attacking it makes it hostile. A surviving hostile machine can charge a fixed-cell shot after its activation; the red X resolves for four damage at the next activation. Move off the marked cell before ending the next turn. Four rifle hits can destroy the 16-HP machine before it responds. Its destruction also causes a nearby blast.

## Repeatable rescue test

From the repository root, with `godot` available on your command line:

```sh
godot --headless --path holdfast --script res://tests/test_follow_rescue.gd
```

On macOS with Godot installed in Applications:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path holdfast --script res://tests/test_follow_rescue.gd
```

The test uses legal game actions and button/key handlers to complete:

- All three groups following MSG through Farm Road, including mid-mission save/load.
- All three groups following MSG through the northbound return, preserving the original mission record.
- A leader critically wounded by actual machine impacts, followers waiting, reassignment to the exit, and Ortiz stabilizing/carrying MSG out.

Expected output includes `FOLLOW END-TO-END FAILURES: 0`; a failed expectation produces a nonzero exit code. Test saves go into a separate `holdfast-tests-*` folder in the operating system cache. Tests neither resume nor replace the player's campaign. Set `HOLDFAST_TEST_OUTPUT` to a writable directory to override the cache location.

These checks validate rules and progression. Human playtesting is still needed to assess clarity, tension, character recognition, and balance.

## Foundation work

The [foundation plan and decisions](docs/foundation-plan.md) track the gradual move away from gate-by-gate inheritance. Civilian movement, machine activation, and turn resolution now run in independent components; mission layouts and objective policies now use dedicated resources and a shared evaluator. HUD and presentation separation remain in progress. Overwatch is deferred to the first armed-enemy encounter after Gates A–D.

Test the civilian component independently of any mission scene:

```sh
godot --headless --path holdfast --script res://tests/test_civilian_rules.gd
```

Test machine behavior and turn ordering without loading a mission scene:

```sh
godot --headless --path holdfast --script res://tests/test_machine_turns.gd
```

## Presentation direction

The final map is intended to have an isometric/angled tactical view inspired by XCOM and Shadowrun. The current square board remains the playable mechanics prototype. Logical grid coordinates are now separated from screen projection; the final terrain, characters, depth ordering and camera presentation are future work.

Test mission definitions, objective rules and square/diamond coordinate conversion:

```sh
godot --headless --path holdfast --script res://tests/test_missions_projection.gd
```

Terrain drawing now receives a detached display snapshot, and tactical keys/buttons translate into named actions. Character drawing, overlays and the larger interface panels still use the existing scene layers. Test this first presentation boundary with:

```sh
godot --headless --path holdfast --script res://tests/test_presentation.gd
```

Soldier markers and movement/aim/cover overlays now also use separate renderers with detached display data. The presentation test covers their drawing output and isolation from game state. Mission-specific machine/civilian art and the larger panels remain to be extracted.

Machine hazards and appearance, civilian groups/routes, the tactical action panel and civilian-order panel now use separate snapshot-based renderers. Opening, roster, debrief and other mission-specific panels remain in the scene layers. The same presentation test covers the new renderers.

Opening/log/debrief dialogue, roster, mission results, casualty rescue, breaker and protocol panel content now also render from detached snapshots. Scene adapters retain modal input/visibility and smaller mission overlays; the inheritance cleanup remains in progress.

Dialogue, roster and results inputs now translate through a shared modal intent decoder. Controllers retain modal priority and action execution. Return-mission and ending-entry overlays also use detached display snapshots.

Civilian order/card controls, casualty actions and machine interaction buttons now use the shared intent decoder while controller guards preserve confirmation, aiming and targeting priorities.

Shared headers/navigation decorations and machine status/footer drawing now live in presentation helpers. Remaining foundation work is controller/view routing, save orchestration and reducing the inherited scene chain.

The main encounter now uses an explicit view router rather than traversing the inherited drawing chain. Roster, dialogue, results and tactical screen priority and layer order are tested. Earlier gate scenes retain compatibility drawing adapters; gameplay inheritance and save orchestration remain to be simplified.

Encounter save/load now passes through a shared validation boundary before restoring live state. Existing save formats and migration behavior are retained. Test rejected-load isolation and save round trips with:

```sh
godot --headless --path holdfast --script res://tests/test_persistence.gd
```

Campaign/report/completion write ordering and the existing C2-to-D1 migration now have dedicated services. Persistence tests cover failures at each write step and migration source isolation. Successful earlier writes remain intact if a later file fails, matching existing behavior.

The main scene now composes its save snapshot and extra-state restore order explicitly, preserving binary field order and independent copies of nested state. Earlier gate scenes reuse the same state adapters through compatibility entry points.

Shared restore sections now apply mission state before tactical movement rebuilding, clear transient input modes and preserve repeated-load behavior across compatibility scenes. Live state ownership still remains in the scene adapters.

Combat state now has a scene-independent owner for actors, rounds, RNG and shot history. Existing scene adapters forward to that model. Test model isolation and deterministic restoration with:

```sh
godot --headless --path holdfast --script res://tests/test_combat_state.gd
```

Machine/protocol and civilian evacuation state now have independent owners, with transient UI selections kept in controllers. `tests/test_mission_state.gd` checks instance isolation and detached nested data.

Story knowledge/choices, campaign and return history, and rescue/result records now also have independent state owners. The dedicated-state milestone is complete; composed gameplay/input control and final cleanup/playtesting remain.

The main scene now dispatches input through an explicit priority router, preserving modal blocking and earlier gate compatibility. Gameplay composition and final foundation acceptance remain in progress.

Mission completion now has an explicit sequence for closure, dispositions, reports and campaign history, with repeated-call protection. Main-scene post-turn completion hooks also bypass inherited orchestration. Other gameplay and startup adapters still need composition.

Main-scene startup now follows an explicit initialization sequence and restores saved progress only after roster and return-map setup. Startup checks cover fresh-state parity, automatic resume, disabled resume and corrupt saves (`tests/test_startup.gd`).

Main-scene save/load now calls persistence and migration directly, retaining existing slots, campaign checkpoints and error behavior. Regression checks include older campaign upgrades and failed writes.

Machine turns and protocol commands now use explicit main-scene orchestration, preserving once-per-phase activation, recovery/finalization ordering and peaceful return-map restrictions.

Attack, damage, rescue and extraction now use explicit main-scene orchestration. `tests/test_actions.gd` checks lethal blast finalization, carrier costs/links and rescue record integrity. The foundation refactor remains in progress.

Movement, civilian orders and breaker/return-repair actions now use explicit main-scene orchestration. Checks preserve carrying behavior, order limits, confirmation costs and cooling-route eligibility.

Main-scene mission selection, safety/occupancy checks and action eligibility now use explicit policies. `tests/test_policies.gd` compares all 320 cells across six encounter states against the compatibility scene.

Movement search is now a scene-independent component with stable route ordering. Main-scene movement refresh, bleeding and reload hooks use explicit calls. Full-grid policy checks include the 1-based far edges.

Narrative routing, survivor labels and story/campaign persistence now use explicit main-scene orchestration. `tests/test_narrative.gd` checks content and navigation parity across five scenarios.

Machine status/outcome text and map-display policies now use explicit main-scene composition. Eleven machine-state comparisons preserve existing labels and visible tracks/fixtures. Shared method/data relocation remains outstanding.

At mission closure, **Practice results** lists civilian outcomes, squad dispositions, machine/feeder outcomes and rescue records. Scroll for the full report. **Review map** keeps the resolved board visible; **Mission results** reopens the report. **Restart practice** starts a fresh attempt, while **Back to original demo** restores the paused encounter. Practice never saves campaign progress.

**Visual benchmark** (top toolbar of the normal demo) opens an isolated early art blockout. Use Day/Night, Helmet/Cap and Empty/Loaded to compare lighting, headgear and machine cargo. Scroll zooms; Home resets framing. Back restores the original demo. Machine A now uses an imported static candidate; people and environment remain simple design volumes. These are not finished art or new mission mechanics.

Benchmark inspection: **View** cycles close-ups; **Silhouettes** removes color/material detail; **Overlap** tests a soldier sharing the civilian group space. These are reversible visual tests, not new gameplay options.

**Stress** in the visual benchmark cycles an adjacent wall and a second four-person cohort. This exposes crowding limits without changing the playable encounter.

In the two-group benchmark stress test, fixed **Group A/B** buttons show numbered markers for the selected cohort, including obscured figures. These are inspection cues only.

Visual production next step: [Machine A asset plan and gameplay zoom requirements](docs/art-direction/first-production-asset.md). Zoom is a confirmed presentation requirement; final camera behavior remains pending.

Machine A [static candidate 01](docs/art-direction/machine-a-candidate-01.md) is available in the visual benchmark. Editable Blender source and the reproducible export builder are included. Static art acceptance, material work, state variants and animation remain open.

The visual benchmark now has a **State** button for Machine A working, paused, hostile, charged, disabled and destroyed static appearance studies. This does not change the playable encounter.

Machine A’s benchmark **Cargo** button cycles empty, skid and alternate-component appearances. The latest material pass separates olive shell and replacement panels; final texturing and visual acceptance remain open.

[Machine A static review](docs/art-direction/machine-a-static-review-01.md): 108 captured combinations; next fix is readable state/cargo cues at normal and wide framing before animation acceptance.

Machine A’s benchmark now has a fixed-screen state panel with symbols and plain labels. Cargo details appear when the **View** control focuses Machine A. These remain isolated art-review cues.
