# 3D presentation milestone

Direction: angled orthographic 3D, inspired by the requested XCOM/Shadowrun presentation. GDD v3.1 gameplay remains the baseline. This follows foundation acceptance; it does not add a mission, overwatch, elevation or diagonal movement.

## P1 — map and readability study: complete

Run the normal demo and click **3D Preview** at the upper right. The encounter is hidden and paused; **Back to demo** restores the same scene and unsaved state. This avoids dependence on a function-key shortcut. Direct Run Current Scene on `map_preview_3d.tscn` remains supported. F5 still runs the existing playable demo.

The preview reads the existing Farm Road resource: 20×16 cells, walls, cover edges, fixtures, spawns and evacuation area. Primitive models distinguish four squad roles, civilian groups of four, and the tracked neutral machine. A pulsing orange cell marks its authored next patrol step. Clicking cells shows coordinates and context; scroll zooms and Home refits. The inspector stays screen-fixed. The existing 2D magnifier is hidden only while this preview is active.

This is an inspection-only starting layout, with no movement, combat, save loading or campaign writes. Shapes are temporary models, not final character art. Click the ground cell under a marker; terrain-plane picking does not yet select tall models by their silhouette. The orange marker is a static starting-state prediction, not a running simulation.

Validation: Godot script/import checks; 320 world/screen/cell round trips; squad/danger inspection checks; rendered OpenGL compatibility captures inspected for framing and readability. Forward Plus and a human user playtest remain unverified. [Preview image](verification/3d-preview.png).

## P2 — connect the existing encounter

Bind the view to a detached display snapshot from the standalone controller. Route selection/movement intents to existing rules; show legal movement and path previews. Preserve action costs, deterministic results, civilian orders and save formats. Do not reimplement combat in the renderer.

## P3 — action readability

Animate movement and attacks from resolved events, distinguish neutral/hostile machine posture, and show impact/shot warnings. Keep the full encounter loop and fixed-screen controls readable before replacing the main scene. Re-run recorded routes and do a focused visual/user playtest.

The prototype remains separate until those criteria pass. Existing magnification and the playable demo are unchanged.

Launch follow-up: automated and rendered tests exercise the Preview/Back buttons, duplicate-launch guard, exact encounter-state preservation and magnifier input restoration. The original F6 failure was not reproduced; no keyboard-configuration cause is claimed.
