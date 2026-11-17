# Foundation acceptance — 16 November 2026

The active encounter is independent of the prototype gate inheritance chain. State ownership, explicit orchestration and standalone-controller acceptance are complete.

## Verification

- All twelve committed suites and twelve gate regressions pass after cleanup.
- All 119 binary state snapshots and six route outcomes match the pre-consolidation build.
- A project copy without prototype gate scripts/scenes passed full origin/return/wounded rescue and action tests.
- A rendered Godot 4.7.2 OpenGL compatibility run completed origin and return rescues in round 7 with all 12 civilians and four soldiers extracted, plus the wounded-MSG scenario. The run used automated actions and isolated temporary save paths; it did not load or modify the player's campaign.
- Screenshots below were visually inspected by the assistant. This is a rendered automated smoke test with visual inspection, not a human user playtest or exhaustive mouse/zoom coverage. Default Forward Plus rendering was not tested in this pass.

## Visual evidence

[Opening at 3×](opening-3x.png), [opening at Fit](opening-fit.png), [initial board](tactical-fit.png), [active orders](tactical-orders.png), [results](results.png), [roster](roster.png), [return board](return-map.png).

Opening text, coordinates, actor markers, order panels, outcomes and roster history rendered. Navigation into the tactical view, results/roster and return deployment worked during the rendered run.

## Cleanup decision

Removed the unreferenced `result_line` drawing adapter from the standalone controller and B6 fixture. Retained earlier gate adapters because their scenes and regression tests still use them. They are compatibility fixtures, not dependencies of the active controller. The standalone controller remains large; further component extraction is maintenance work rather than an unmet gate-dependency requirement.

## Follow-up usability issues

- **Fit overlaps the bottom toolbar.** Fit sets 100% magnification without reserving the toolbar's 64 logical pixels. Footer text and lower controls can appear behind it. Next bounded fix: calculate Fit against the unobscured viewport, preserving the requested default 3× view and pan controls.
- At 3×, long opening lines extend offscreen and require horizontal panning. This is expected with the current whole-canvas magnifier; future responsive panels should wrap text independently of map zoom.

These existing presentation limitations are recorded separately from structural acceptance. No new mission, balance change, overwatch or isometric conversion is included.
