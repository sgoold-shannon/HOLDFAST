# 3D presentation milestone

Direction: angled orthographic 3D, inspired by the requested XCOM/Shadowrun presentation. GDD v3.1 gameplay remains the baseline. This follows foundation acceptance; it does not add a mission, overwatch, elevation or diagonal movement.

## P1 — map and readability study: complete

Run the normal demo (prefer **Play HOLDFAST.command** on Mac) and click **3D Preview** at the upper right. **Back to demo** restores the same encounter and unsaved state. Direct Run Current Scene on `map_preview_3d.tscn` also works.

The camera now sits behind the squad: origin soldiers appear at the bottom and advance upward toward the machine. Soldiers initially face the enemy and turn with their last movement step. This is camera/model orientation only; the board remains flat with unchanged logical coordinates and rules. Temporary primitive models distinguish squad roles, civilian groups and the machine.

## P2a — squad movement practice: complete

The preview owns an isolated fresh Farm Road encounter with auto-resume disabled. It neither reads nor writes campaign saves. `presentation3d/movement_session.gd` delegates selection, pathfinding, movement costs and movement execution to the production encounter controller, returning detached display data to the 3D view.

Select a figure or one of the four fixed-screen squad buttons. Green cells cost 1 AP; blue cells cost 2 AP. Hover highlights a dotted route and reports its cost and length. Click a reachable destination to move. Health and AP remain in the screen-fixed panel. Reset practice restores the initial snapshot without disk access. Scroll zooms; Home fits the map. Movement resolves immediately; animation is deferred to P3.

Validation: all sixteen committed suites passed. Dedicated movement checks compare reachable costs for all 320 cells and all four soldiers, route ordering and exact post-move snapshots against the production controller. They also cover blocked cells, two-AP dashes, exhausted AP, reset, detached display data and the squad-below-enemy camera relation. All 320 picking round trips still pass. Preview/Back tests now include a practice move and verify the original demo state remains unchanged. A rendered compatibility-mode test used GUI input to select MSG, hover a route and move four squares for 1 AP. [Movement preview](verification/3d-movement.png).

## P2b — remaining encounter integration: next

Connect civilian orders, machine turns, extraction and other commands to the same rules. Replace static civilian/machine display with live snapshots and hazards. Decide when the complete 3D encounter replaces the practice view; never silently apply practice moves to the paused campaign. Preserve costs, deterministic outcomes and save formats, and run recorded-route comparisons before enabling the full loop.

## P3 — action readability

Animate movement and attacks from resolved events, distinguish neutral/hostile machine posture, and show impact/shot warnings. Keep the full encounter loop and fixed-screen controls readable before replacing the main scene. Re-run recorded routes and do a focused visual/user playtest.

The prototype remains separate until those criteria pass. Existing magnification and the playable demo are unchanged.

Launch follow-up: automated and rendered tests exercise the Preview/Back buttons, duplicate-launch guard, exact encounter-state preservation and magnifier input restoration. The original F6 failure was not reproduced; no keyboard-configuration cause is claimed.
