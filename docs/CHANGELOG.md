# HOLDFAST development history

This is the running log of prototype and foundation work, moved out of the README on 18 November 2026. Newest entries are at the bottom of each section. For how to run the game and tests, see the [README](../README.md).

### Mission 06 · County Hospital, v1 greybox (Nov 2026)

Spec: `docs/missions/county-hospital.md` (approved by Spence, 24 Nov 2026). Launch it from the Operations board.

- `county_hospital.gd` + `county_hospital.tscn` + `missions/county_hospital.tres`: one road east, three groups (walking patients, staff, critical patients on gurneys who walk 1 square a turn). The perimeter collapses after round 10.
- `systems/hospital_power.gd`: power for 1 system (+1 from Rail Yard generator cells, +1 from the Drover coupling), assigned by MSG at the generator room: ambulance charger, triage scanner, fence lights. The ambulance takes one group a trip; people on the road step aside, the convoy and troopers stop it.
- `systems/screening.gd`: one person of interest per group, one of them the infiltrator. Credentials check and scan at the triage tent, a witnessed act at the north gate in round 3. Two discrepancies confirm; detaining on less is allowed and a wrong call is a recorded false detention. Groups are never targets.
- `systems/reptilian_team.gd`: two armored troopers (10 HP, rifle hits deal 3) through the gate in round 5 if the infiltrator opened it, round 7 if not. They take a group they end next to (gurneys first) and mark a sonic cone a turn ahead (−1 AP, panic).
- `systems/drover_convoy.gd`: arrives for round 4 and uses the road in rounds 5–6. With Interchange field contact: monitored passage (+1 power afterwards) or reserve the road. Without it, they force the road and shove people off it.
- `systems/fire_team.gd`: Guard Team Marsh, four named members, one free order a turn (hold by a soldier, protect the selected group, withdraw), two shots a turn, named casualties.
- Campaign record gains a mission 06 entry (ambulance trips, power, infiltrator outcome, false detentions, convoy, taken groups, team dead, critical patients) with carry-forward to Quarry and Civic Center.
- Not yet: save/load inside the hospital, final art.
- Tests: `test_county_hospital.gd` plus HUD launch checks. `sim_county_hospital.gd`: ambulance for the gurneys with early screening gets 8/12 and contains the infiltrator; ambulance for the walkers gets 4/12. Tune after playtests.

### Mission 05 · Rail Yard, v1 greybox (Nov 2026)

Spec: `docs/missions/rail-yard.md` (approved by Spence, 24 Nov 2026). Launch it from the Operations board.

- `rail_yard.gd` + `rail_yard.tscn` + `missions/rail_yard.tres`: a Grey extraction site in the county rail yard. All three groups start in field pens; the exit is west, the way the squad came in. Penned groups sit out the civilian phase; freed groups come out shaken and already pointed at the exit.
- `systems/grey_yard.gd`: Collector marks a pen in rounds 3, 5 and 7 and takes it the round after (hit it or open the pen to stop it); two Sentries with River Bridge-style beams, passive until provoked; a Disruptor that marks a 3×3 blackout a round ahead (no radio, no lock bypass, no downloads); the transport lifts off at the end of round 8.
- Squad actions: Bypass lock (Bell, 1 AP), Cut lock (anyone, 2 AP, works in a blackout), Download archive (2 steps by the transport), Release handcar (rolls west 3 a round with generator cells), Accept Grey trade (round 2 only: survey records for leaving the transport, ramp and terminal alone for 3 rounds; the pens aren't covered).
- Carry-ins: River Bridge's taken groups are in the pens by name and manifest; Interchange drone evidence makes the archive a 1-step download; squad from the latest record.
- Campaign record gains a mission 05 entry (groups and origins, aboard, archive, supplies, trade, Greys down) with carry-forward to Hospital, Quarry and the Airfield.
- Not yet: save/load inside the Rail Yard, final art.
- Tests: `test_rail_yard.gd` plus HUD launch checks. `sim_rail_yard.gd`: people first gets 12/12; people plus the trade gets 12/12 and the survey records; sending a soldier for the full archive costs a pen and a wounded soldier. Tune after playtests.

### Mission 04 · Interchange, v1 greybox — Act II opens (Nov 2026)

Spec: `docs/missions/interchange.md` (approved by Spence, 21 Nov 2026). Launch it from the Operations board.

- `interchange.gd` + `interchange.tscn` + `missions/interchange.tres`: a highway interchange, Farm Road machine off. Group C starts on an overpass whose east end has collapsed; the only way down is the west ramp.
- `systems/drover_crew.gd`: hauler (20 HP, leaves at the end of round 7) and two security units (10 HP, aim lines a turn ahead, never target civilians). Civilians won't enter the work zone (columns 9–13) unless a pause holds; a soldier within 2 of the hauler without one provokes security.
- Corridor pause: MSG within 6 of the hauler transmits (1 AP); without ACK-01 he observes the hauler first. 3 rounds, or 5 with the Main Street component handed back. Soldiers stay on the green lane (row 9). Every broken pause records who broke it.
- `systems/grey_drone.gd`: arrives round 1, fires on the hauler in round 4. Observed first, the Drovers see who did it and shoot it down; unseen, they blame the squad for 2 rounds.
- New squad tools here: Suppress (1 AP + 2 rounds, −20 Aim, ends if the suppressor moves) and Restrain (a suppressed Drover at 5 HP or less, taken alive).
- Carry-ins: ACK-01 (no observation needed), preserved Main Street platform (crew is wary: warning shot first), component (longer pause), River Bridge sensor (drone visible from arrival). Carry-over reads the latest squad on record.
- Campaign record gains a mission 04 entry (agreement, breach, drone, Drover security tally, cargo). An honored agreement makes MSG Ward's field contact; Kesh speaks for the first time.
- Not yet: save/load inside the Interchange, overwatch, final art.
- Tests: `test_interchange.gd` plus HUD launch checks. `sim_interchange.gd`: pause plus an observed drone gets 12/12 out; frontage road only gets 8/12 (group C can't make it without the pause); the naive assault script gets MSG killed. Tune after playtests.

### Mission 03 · Main Street, v1 greybox — Act I closes (Nov 2026)

Spec: `docs/missions/main-street.md` (approved by Spence). Launch it from the Operations board.

- `main_street.gd` + `main_street.tscn` + `missions/main_street.tres`: a 20×16 town. The Farm Road machine rules drive a 24 HP Drover recovery platform heading down Main Street for the substation. Demolish it, isolate it at the junction box JB (14,10), or redirect it through the control panel CP (7,6); a redirected platform parks across the north alley and shelters the ground next to it.
- If it reaches the substation, the corridor closes two rounds later (otherwise after round 9).
- `systems/fallow_cutter.gd`: first Fallow contact. Distortion shown at the end of round 3, cutter and coordination node arrive in round 4. Each Fallow turn it turns last turn's violet strip into rift (impassable, 4 damage, thrown clear) and marks a new strip two columns ahead of the lead group (4 squares with the node linked, 2 without). Interrupt the node (1 AP, adjacent) to buy a turn; kill the cutter (12 HP) to stop new marks. Exits and route waypoints are never marked, so the town can be cut but not sealed.
- Drover security walks beside the platform (not a target), drops a component when the cutter arrives and leaves. Recover it for 1 AP.
- Carry-over reads the latest record (River Bridge, else Farm Road); replacements never double up a name.
- Campaign record gains a mission 03 entry (platform fate, component, rifts, interrupts, cutter). The debrief and the Operations board close Act I: the single-command hypothesis is rejected.
- Shared fixes: machine HP, breaker/console coordinates and the collect/depart stages now come from mission data instead of Farm Road's numbers.
- Not yet: save/load inside Main Street, Drover security reacting to being shot, final art.
- Tests: `test_main_street.gd` plus HUD launch checks. `sim_main.gd`: a simple scripted player gets 4/12 out ignoring the platform and 8/12 demolishing it. Tune after playtests.

### Mission 02 · River Bridge, v1 greybox (Nov 2026)

Spec: `docs/missions/river-bridge.md` (approved by Spence). Launch it from the Operations board.

- `river_bridge.gd` + `river_bridge.tscn` + `missions/river_bridge.tres`: extends the encounter controller with the Farm Road machine switched off. Reuses squad actions, civilian command and panic, and rescue.
- `systems/grey_team.gd`: Collector (LIFT 2 on the nearest civilian group; broken only by hitting it or reaching the barn), Sentry (passive until provoked, then a dodgeable beam aim line), withdrawal at the end of round 8 or when the Collector drops, and the unidentified craft's one-time shield. All balance numbers at the top of the file.
- Bridge lanes: People first (all rows, supplies lost) or Heavy lane (row 7 only, single file, supplies kept), set once by a soldier at the checkpoint for 1 AP. Optional sensor in the reeds.
- Farm Road's record carries in: soldiers lost there are replaced by named replacements, and wounded soldiers start at 4 HP.
- Campaign record gains a mission 02 entry (groups crossed/taken, lanes and supplies, sensor, craft, Greys), and the Operations board shows what it carries forward.
- Not yet: save/load inside River Bridge (buttons say so), named replacement backstories, final art.
- Tests: `test_river_bridge.gd` (lanes, lift, shield, beam, withdrawal, sensor, record, carry-over) plus HUD launch checks. `sim_river.gd` runs balance passes. With perfect play (instant calming, no panic) everyone gets across, so the pressure in real play comes from panic, the beam and MSG's positioning. Tune after playtests.

### Campaign arc connected (Nov 2026)

**Canon decision (Spence, 19 Nov 2026):** GDD v3.1 is the story authority. Drovers, Kesh, and four separate factions (Greys and Reptilians are not Fallow castes); companion deaths come from play, with no fixed quota. The earlier Kingdom Rush–style design doc is superseded where they conflict.

- `data/campaign_arc.gd`: the four acts and seventeen missions from GDD v3.1 Sections 08–12, condensed. Mission 01 playable, 02 River Bridge briefed as next, the rest planned.
- `systems/campaign_record.gd`: what each finished mission leaves behind (GDD Section 29): machine state, feeder, protocol acknowledgement, each group's fate, each soldier's status. Written to `user://holdfast_campaign_record.save` when Farm Road's result is recorded (the deployment-2 continuity test doesn't write it). Also produces the plain-language "what the task force knows" and "what carries forward" lines.
- HUD: **Operations** board (top bar, launch screen and results) shows the acts, mission cards, the record and the River Bridge briefing. Top bar reads "Act I · Mission 01 · Farm Road"; the briefing opens with the Act I title. The return map is labeled as a continuity test.
- Tests: `test_hud.gd` checks the board and that finishing Farm Road writes a record matching the outcome, using a throwaway record file.

### Controller split, steps 6–9: done (Nov 2026)

`encounter_controller.gd` is now a 1,140-line coordinator (from 2,595 at the start): shared state accessors, constants, the turn sequence, and one-line wrappers that keep every public name stable. The logic lives in:

- `systems/campaign_flow.gd`: roster, knowledge, recording results, staging care, deployment
- `systems/return_mission.gd`: deployment 2 rules, repair, cooling move, attempt swap, ending test
- `systems/civilian_orders.gd`: both civilian command models, civilian turn, closing early
- `systems/squad_actions.gd`: select, move, aim, fire, reload, extract, start of player turn
- `systems/machine_turn.gd`: the machine's plan, route, intent, activation, damage, blast
- `systems/mission_results.gd`: recovery failure, recording, dispositions, restart
- `systems/encounter_lifecycle.gd`: starting state, save/load, restoring sections

Every step passed the full suite (24 suites, including the 119-action parity and all 3D suites) on Godot 4.7.2 / macOS before it was committed. To add a mission rule, edit the system file for that area; the controller only needs a new wrapper if the HUD or tests must call it by name.

### Controller split, steps 2–5 (Nov 2026)

`encounter_controller.gd` 2,361 → 1,805 lines. Each step moved one area into its own file as static functions taking the board, left one-line wrappers with the original names (so tests, HUD and legacy panels are untouched), and passed the full suite on Godot 4.7.2 / macOS before commit:

- `presentation/view_models.gd`: the 16 `*_snapshot` builders panels and map layers draw from.
- `systems/rescue_actions.gd`: damage, bleeding out, stabilize, carry, put down.
- `systems/machine_controls.gd`: breaker and console protocol, including betrayal.
- `systems/story_flow.gd`: briefing, knowledge flags, evidence/debrief/log pages and scene choices.

### Civilian command and panic (Nov 2026)

Spence's design: MSG (PSYOP NCO, male, modeled on Spence) directs the crowd; crowd control is his job.

- `systems/civilian_command.gd` holds the rules and every tuning number.
- MSG orders any group within 6 squares (walking distance) for free. The map shows his range as a gold outline.
- Any other soldier can order a group within 2 squares for 1 AP.
- Panic: the machine, its target square, or gunfire within 3 squares at the end of a round raises a group one step: calm → SHAKEN (moves 2) → PANICKED (ignores orders, runs one square from danger or freezes). A quiet round with a soldier close by lowers it one step.
- MSG within 3 squares keeps a group from getting more scared. **Calm** (C): MSG within 6 squares spends 1 AP to settle a group completely; another soldier within 2 squares spends 1 AP to settle it one step.
- The one-order-per-turn rule is gone in the desktop game (`command_model = "authority"`). The legacy layout and its parity tests keep the original rule (`command_model = "phase"`, the default).
- Balance runs on a fresh Farm Road: machine left running → 0–4 of 12 saved; machine stopped → 8/12 if MSG stays put, 12/12 if he moves up to keep everyone in range.

### Controller split, step 1 (Nov 2026)

- The original single-page layout's drawing and click handling (18 functions, ~320 lines) moved from `encounter_controller.gd` to `presentation/legacy_screen.gd`. The controller is down from 2,595 to 2,279 lines and now holds game state and rules plus thin `_draw`/`_unhandled_input` hooks.
- No behavior change: the full suite (including the 119-action parity and all 3D suites) passes on Godot 4.7.2 / macOS.

### Desktop interface (Nov 2026)

- New main scene `game.tscn` (`presentation/hud/game_shell.gd`): 1920×1080 landscape, window opens maximized.
- The encounter controller gets `hud_mode`: it draws only the map (`presentation/hud/map_layer.gd`) and leaves mouse clicks to the HUD (`presentation/hud/map_input.gd`, same click priority as before). Keyboard shortcuts still go to the controller unchanged.
- Sidebar: selected soldier, every action as a button (disabled with the reason as a tooltip), squad, civilian groups and orders, threat. Story, results, roster and the breaker confirmation are pop-up windows.
- The magnifier toolbar (`readability.gd`) stays hidden in the new layout (`shell_mode`). 3D preview and visual benchmark moved to **Extras**.
- Right-click clears the selection, unpins an aim target or cancels put-down.
- `farm_final.tscn` and every existing test still use the old layout, so the 119-action parity suite is unaffected. New test: `tests/test_hud.gd`.
- Editor plugin `addons/claude_bridge` starts `Claude Bridge.command` if that file sits beside the project (Spence's Mac only).

### Run without the editor (Mac)

Double-click **Play HOLDFAST.command**, beside the `holdfast` folder. This opens the playable demo directly with the tested compatibility renderer, bypassing editor inspection/input modes. Godot must be installed at `/Applications/Godot.app`. Existing saves are used normally. Close the game window to stop it.

If an embedded run appears frozen, use this launcher. Standalone GUI-input tests verify Fit, 3×, scrolling and Preview/Back. The reported editor-specific freeze has not been reproduced or conclusively diagnosed; this is a tested alternative launch path, not a claim that all editor issues are fixed.

### Run the prototype

Open `holdfast/project.godot` in Godot and press **F5**. The project has been tested with **Godot 4.7.2**. The main scene is `farm_final.tscn`; `battlefield.tscn` retains the earlier tactical sandbox.

The prototype contains the Farm Road encounter, conditional debrief, persistent roster, a return mission affected by the earlier machine outcome, and a separate ending logic test. It is not a complete campaign. The ending fixture's 24 passengers are test data, not accumulated campaign rescues.

### Current foundation status

The active encounter now uses `encounter_controller.gd` directly under Node2D, through the stable `farm_final.gd` entry point. It no longer depends on the prototype gate inheritance chain. State ownership, controller separation and foundation acceptance are complete. See the [verification record](verification/foundation/README.md) for test evidence, screenshots and remaining readability issues. Earlier gate scenes are retained as regression fixtures.

### 3D evacuation practice

Run the demo normally and click **3D Preview** at the upper right. Select a soldier or their bottom-panel button, hover a highlighted cell to preview the route, then click to move. Green costs **1 AP**, blue costs **2 AP**. **Reset practice** restores the squad; **Back to demo** restores your untouched original encounter. Scroll zooms and Home fits the map.

The camera looks from behind the squad toward the enemy, so advances move upward on screen. Select a **Group A/B/C** button, then **Evacuate** to choose an exit route, **Follow soldier** to follow your selected soldier, or **Hold** to stop. You can issue one free group order per turn; orders persist. **End turn** resolves machine actions, moves ordered civilians and refreshes AP. At the teal exit cells, use **Extract soldier** (1 AP). The live display tracks turns, machine intent and evacuated people. Practice uses production rules but never saves campaign progress. **Combat:** select a soldier, then click **Target machine** at the upper right (or click the machine). Review the hit chance and warnings, then click **Fire**; targeting alone never fires. Fire and Reload each cost 1 AP; each soldier can attack once per turn. Squad cards show ammunition as rounds/4. The machine label shows HP and neutral/hostile status; orange marks movement danger and red marks a charged shot. **Rescue:** select a standing rescuer, then click a critical/stable teammate’s card. Move adjacent, then use **Stabilize** (1 AP and a medical charge) and **Carry** (1 AP). Stabilizing stops bleeding but does not restore the casualty’s ability to act. Carriers have limited movement and cannot fire. At extraction, **Extract soldier** brings both out. **Put down** then a free adjacent cell releases the casualty for 1 AP; **Cancel put down** returns to movement. Critical labels show bleeding turns remaining. **Equipment / protocol** opens the panel at the upper right. MSG can Observe then Transmit a one-turn pause; Bell can Authenticate and Divert from beside the console at (11,12), before skid collection. Each action costs 1 AP. Beside the breaker at (9,4), open the housing, request isolation, then confirm its consequences (or cancel free). Blocked attempts explain their requirements in the panel. See the [presentation plan](presentation-plan.md).

### Readability

The demo starts at **3× magnification**. Scroll to pan; Shift + scroll moves sideways. Use **Fit**, **2×**, or **3×** at the bottom to change the view. Home returns to the top-left. Fit scales the full page into the space above the toolbar, adjusting when the viewport changes. At 3× you will need to pan to reach parts of the map and the civilian panel.

### Rescue civilians

1. Select group **A**, **B**, or **C** using its card on the right.
2. Choose **Move to EXIT** to select an available evacuation route. A highlighted path shows the selected group's route.
3. Press **N** to end the turn. After the machine responds, ordered groups move up to three cells.
4. Order the other groups on later turns. **Orders persist**; you do not need to renew them each turn.

You get **one free civilian-group order per player phase**, shared across all groups. It does not spend soldier AP. Reaching the civilian exit automatically evacuates that group. The road deadline still applies after the machine is destroyed.

To escort a group, select a standing soldier on the map, select the group, then choose **Follow**. The group moves toward a cell adjacent to that soldier. It waits if the leader goes down or the path is blocked; choose another order to redirect it. After the leader extracts, followers continue toward the civilian exit. **Hold Position** stops a group and provides no cover bonus.

### Tactical controls

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

### Repeatable rescue test

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

### Foundation work

The [foundation plan and decisions](foundation-plan.md) track the gradual move away from gate-by-gate inheritance. Civilian movement, machine activation, and turn resolution now run in independent components; mission layouts and objective policies now use dedicated resources and a shared evaluator. HUD and presentation separation remain in progress. Overwatch is deferred to the first armed-enemy encounter after Gates A–D.

Test the civilian component independently of any mission scene:

```sh
godot --headless --path holdfast --script res://tests/test_civilian_rules.gd
```

Test machine behavior and turn ordering without loading a mission scene:

```sh
godot --headless --path holdfast --script res://tests/test_machine_turns.gd
```

### Presentation direction

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

Visual production next step: [Machine A asset plan and gameplay zoom requirements](art-direction/first-production-asset.md). Zoom is a confirmed presentation requirement; final camera behavior remains pending.

Machine A [static candidate 01](art-direction/machine-a-candidate-01.md) is available in the visual benchmark. Editable Blender source and the reproducible export builder are included. Static art acceptance, material work, state variants and animation remain open.

The visual benchmark now has a **State** button for Machine A working, paused, hostile, charged, disabled and destroyed static appearance studies. This does not change the playable encounter.

Machine A’s benchmark **Cargo** button cycles empty, skid and alternate-component appearances. The latest material pass separates olive shell and replacement panels; final texturing and visual acceptance remain open.

[Machine A static review](art-direction/machine-a-static-review-01.md): 108 captured combinations; next fix is readable state/cargo cues at normal and wide framing before animation acceptance.

Machine A’s benchmark now has a fixed-screen state panel with symbols and plain labels. Cargo details appear when the **View** control focuses Machine A. These remain isolated art-review cues.

Machine A runtime exports now consolidate stationary geometry while preserving editable source parts and independent cargo/tool/light controls. The benchmark draw-call comparison is recorded in the [candidate notes](art-direction/machine-a-candidate-01.md).
