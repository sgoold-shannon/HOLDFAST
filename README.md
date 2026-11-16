# HOLDFAST

A character-driven tactical sci-fi prototype built in Godot. The design baseline is **HOLDFAST Game Design Document v3.1**, included at the repository root.

## Run the prototype

Open `holdfast/project.godot` in Godot and press **F5**. The project has been tested with **Godot 4.7.2**. The main scene is `farm_final.tscn`; `battlefield.tscn` retains the earlier tactical sandbox.

The prototype contains the Farm Road encounter, conditional debrief, persistent roster, a return mission affected by the earlier machine outcome, and a separate ending logic test. It is not a complete campaign. The ending fixture's 24 passengers are test data, not accumulated campaign rescues.

## Readability

The demo starts at **3× magnification**. Scroll to pan; Shift + scroll moves sideways. Use **Fit**, **2×**, or **3×** at the bottom to change the view. Home returns to the top-left. At 3× you will need to pan to reach parts of the map and the civilian panel.

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
