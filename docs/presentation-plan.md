# 3D presentation milestone

Direction: angled orthographic 3D, inspired by the requested XCOM/Shadowrun presentation. GDD v3.1 gameplay remains the baseline. This follows foundation acceptance; it does not add a mission, overwatch, elevation or diagonal movement.

## P1 — map and readability study: complete

Run the normal demo (prefer **Play HOLDFAST.command** on Mac) and click **3D Preview** at the upper right. **Back to demo** restores the same encounter and unsaved state. Direct Run Current Scene on `map_preview_3d.tscn` also works.

The camera now sits behind the squad: origin soldiers appear at the bottom and advance upward toward the machine. Soldiers initially face the enemy and turn with their last movement step. This is camera/model orientation only; the board remains flat with unchanged logical coordinates and rules. Temporary primitive models distinguish squad roles, civilian groups and the machine.

## P2a — squad movement practice: complete

The preview owns an isolated fresh Farm Road encounter with auto-resume disabled. It neither reads nor writes campaign saves. `presentation3d/movement_session.gd` delegates selection, pathfinding, movement costs and movement execution to the production encounter controller, returning detached display data to the 3D view.

Select a figure or one of the four fixed-screen squad buttons. Green cells cost 1 AP; blue cells cost 2 AP. Hover highlights a dotted route and reports its cost and length. Click a reachable destination to move. Health and AP remain in the screen-fixed panel. Reset practice restores the initial snapshot without disk access. Scroll zooms; Home fits the map. Movement resolves immediately; animation is deferred to P3.

Validation: all sixteen committed suites passed. Dedicated movement checks compare reachable costs for all 320 cells and all four soldiers, route ordering and exact post-move snapshots against the production controller. They also cover blocked cells, two-AP dashes, exhausted AP, reset, detached display data and the squad-below-enemy camera relation. All 320 picking round trips still pass. Preview/Back tests now include a practice move and verify the original demo state remains unchanged. A rendered compatibility-mode test used GUI input to select MSG, hover a route and move four squares for 1 AP. [Movement preview](verification/3d-movement.png).

## P2b — civilian orders, turns and extraction: complete

The practice view now offers group selection, Evacuate, Follow soldier, Hold, explicit upper/lower routes, End turn and Extract soldier. It delegates every command to the production controller. Civilian and machine transforms, presence, skid and warning tiles come from live snapshots. The HUD reports turn, road deadline, evacuation count, machine intent and closure. One-order-per-turn restrictions and completion disable controls appropriately.

A practice-only controller overrides persistence entry points so automatic mission completion and story reporting cannot write campaign saves. Reset remains in memory; Back returns to the paused original encounter. All seventeen suites passed, including exact state comparisons through closure, follow/hold restrictions, extraction visibility, no report/save writes and Preview/Back after a resolved turn. Rendered mouse input verified group selection, Evacuate and End turn. [Evacuation preview](verification/3d-evacuation.png).

## P2c — combat targeting and reload: complete

Select a soldier and Target machine (or click its model/cell), review the displayed chance and neutral-to-hostile/blast warnings, then explicitly Fire. Targeting does not shoot. Fire and Reload delegate to the existing controller. The fixed-screen buttons display blocked-shot reasons and the legal shot chance; squad cards show magazine rounds. Machine labels show HP and posture, and current movement/charged-shot warning cells update after resolution. Target pins remain on the selected cell, so a moved machine must be retargeted.

All eighteen suites passed. New checks compare exact production state for targeting, shots (including RNG), reload and hostile turns, plus chance display, attack allowance, target position, warning visibility and reset. A rendered mouse-input test verified Target machine and Fire. [Combat preview](verification/3d-combat.png).

## P2d — casualty rescue: complete

Casualty card/figure selection preserves the active rescuer. Stabilize, Carry and Put down delegate to the existing rescue rules, with a cancelable adjacent-cell drop mode. Critical/stable figures and labels reflect resolved condition; carried figures follow their carrier and both disappear on extraction. The rescue status explains the selected casualty and bleeding timer; squad tooltips show medical charges.

All nineteen suites passed. Dedicated checks compare exact production snapshots for stabilization, pickup, turn resolution, drop and carried extraction. A rendered mouse-input scenario verifies selecting a rescuer and casualty, stabilizing and carrying. Labels were visually checked after correcting inherited model scaling. [Rescue preview](verification/3d-rescue.png).

## P2e — breaker and protocol: complete

The in-game Equipment / protocol panel exposes Observe, Transmit, Authenticate, Divert and breaker operation through production commands. It explains prerequisites and action failures without spending AP on rejected attempts. Breaker isolation uses the original request/confirm sequence, with explicit feeder/gate/bypass consequences and a free cancel. No mission policies or save formats changed.

All twenty suites passed (the live-controls suite timed out during the parallel run and passed on its isolated rerun). Dedicated equipment checks compare exact production state for the protocol sequence, housing opening, cancel and confirmed isolation. Rendered mouse input verified opening the breaker and confirming isolation; the final panel was visually checked. [Equipment preview](verification/3d-equipment.png).

## P2f — final encounter review: complete

Closure opens a scrollable practice report built from production result snapshots: civilian group outcomes, squad dispositions, machine/feeder state and rescue event count. Review map, reopen results, restart practice and return to the original demo are explicit controls. Results open once per attempt and reset correctly.

All twenty-one suites passed. Two complete command-interface routes compare exact state after commands and deferred completion: neutral evacuation ends round 5 with four civilians and the whole squad extracted; combat plus Follow ends round 7 with all twelve civilians and the whole squad extracted. These are two tested routes, not exhaustive coverage of every possible choice. Both results screens were rendered and the report visually inspected. [Results preview](verification/3d-results.png).

## P2g — automated practice acceptance: complete; user feedback open

Four complete legal command-interface routes now pass exact production-state comparisons after every command and deferred completion. Results fields (title, reason, dispositions, cohorts, machine, feeder, evacuation count and rescue events) also match. All four routes passed in rendered compatibility mode:

| Route | Completion round | Civilians evacuated | Squad extracted |
| --- | --- | --- | --- |
| Neutral machine / exit orders | 5 | 4/12 | 4/4 |
| Combat / Follow orders | 7 | 12/12 | 4/4 |
| Breaker isolation / bypasses | 8 | 12/12 | 4/4 |
| Observe / pause / authenticate / divert | 7 | 12/12 | 4/4 |

The breaker and protocol routes reach their fixtures through legal moves and AP costs; their tests do not teleport actors or alter AP. The protocol result screen was visually inspected. [Protocol result](verification/3d-protocol-acceptance.png). This is automated acceptance of four routes, not exhaustive choice coverage or a substitute for user feedback. A focused user playtest of the full encounter remains open. Address usability findings before animation/presentation polish. Decide when the complete 3D encounter replaces the practice view; never silently apply practice moves to the paused campaign. Preserve costs, deterministic outcomes and save formats, and run recorded-route comparisons before enabling the full loop.

## P3 — action readability

Animate movement and attacks from resolved events, distinguish neutral/hostile machine posture, and show impact/shot warnings. Keep the full encounter loop and fixed-screen controls readable before replacing the main scene. Re-run recorded routes and do a focused visual/user playtest.

The prototype remains separate until those criteria pass. Existing magnification and the playable demo are unchanged.

Launch follow-up: automated and rendered tests exercise the Preview/Back buttons, duplicate-launch guard, exact encounter-state preservation and magnifier input restoration. The original F6 failure was not reproduced; no keyboard-configuration cause is claimed.
