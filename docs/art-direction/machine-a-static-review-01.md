# Machine A static review 01

Date: 2026-11-18. Reviewed candidate from commit `d1b062d`. **Decision: keep the animation gate open.** The model imports and switches states correctly, but tactical state recognition needs a dedicated readability pass.

## Evidence

108 rendered combinations: six states × three cargo choices × three distances × two lighting rigs. Each sheet has columns Working, Paused, Hostile, Charged, Disabled, Destroyed; rows Empty, Skid, Alternate. Destroyed deliberately hides cargo, so its three rows match. Crops are 600 × 600 rendered pixels without rescaling. Open images at actual size to judge detail; shrinking an entire sheet changes apparent readability.

| Lighting | Close (2.5) | Normal study (8) | Wide (16) |
| --- | --- | --- | --- |
| Day | [Close](machine-a-review-01/day-close.png) | [Normal](machine-a-review-01/day-normal.png) | [Wide](machine-a-review-01/day-wide.png) |
| Night | [Close](machine-a-review-01/night-close.png) | [Normal](machine-a-review-01/night-normal.png) | [Wide](machine-a-review-01/night-wide.png) |

The values are orthographic camera sizes for this review, not final gameplay zoom limits. Same elevated front-quarter orientation throughout; this is not a rear/occlusion/accessibility review or a user playtest. World markers remain in some crops, but machine state text is outside the crop.

## Findings and required follow-up

| Check | Observed result | Next action |
| --- | --- | --- |
| Intact versus destroyed | Collapsed height remains distinct across tested distances and lights | Retain silhouette; refine broken-edge surfaces later |
| Working / paused / hostile | Tool changes visible close up, too subtle at normal/wide framing | Pair pose with distinct, readable state symbols and plain labels; do not recolor the whole neutral shell as an enemy |
| Charged versus hostile | Small lit aperture reads close up; resembles work lamps and becomes hard to discriminate at distance | Give pending-shot indication a distinct symbol/shape and preserve the actual target-cell warning during integration |
| Disabled | Lamps correctly extinguish; intact body still easily confused with other uncharged states at distance | Add a power-off state cue; retain clear distinction from wreck |
| Empty / skid / alternate | Cylinder versus finned box distinguishable close; cargo identity weak wide | Provide a compact inspected/selected cargo label; do not require recognizing tiny fins to understand objectives |
| Night | Shell still visible; lower-contrast dark machinery and tiny lights weaken state reading | Review the new cues in both rigs, including silhouette/grayscale treatment |
| Surfaces | Large panels readable; still broad, clean, regular surfaces compared with the repaired concept | Final UV/texturing and seam/edge treatment remain open; avoid spending that effort before state readability is fixed |

## Bounded performance sample

Apple M4 Max, Godot 4.7.2, Compatibility/OpenGL through Metal. Standalone benchmark, camera size 8, daylight, alternate cargo selected (hidden in wreck), 20 warmup frames and 120 measured frame intervals per state. [Raw measurements](machine-a-review-01/measurements.json).

Median frame intervals ranged 8.181–8.252 ms; per-state p95 ranged 13.286–14.175 ms. Whole-scene draw-call monitor: 425 for intact states, 281 for wreck. These include the entire benchmark, people, scenery and interface, and cannot be attributed to the machine alone. Intervals include frame scheduling/presentation and are not GPU timings or a guaranteed shipping frame rate. This short sample does not establish a hardware budget or demonstrate full-mission performance. A representative PC and more actors/effects remain untested. Static mesh consolidation is worth evaluating before scaling scene population.

## Next bounded work item

Build a presentation-only state cue proposal in the existing benchmark: Working, Paused, Hostile, Shot pending, Disabled and Destroyed with distinct symbols plus text. Include cargo information when selected/inspected. Preserve actual gameplay concepts: hostile does not imply a pending shot; paused does not mean disabled; a neutral working machine can still threaten its route. Repeat the normal/wide day/night comparisons before animation acceptance. This does not authorize new mechanics or change the deferred production zoom work.

## Reproduction

From repository root, run with graphics enabled and a writable output directory:

```sh
HOLDFAST_ART_REVIEW=/private/tmp/holdfast-machine-matrix HOLDFAST_TEST_OUTPUT=/private/tmp /Applications/Godot.app/Contents/MacOS/Godot --path holdfast --rendering-method gl_compatibility --script res://tests/review_machine_matrix.gd
```

The review script creates a standalone visual benchmark and writes only review output/test-support temporary files. It does not load a campaign encounter. Its successful completion means captures were generated, not that art acceptance passed. No playable-scene or camera behavior changed in this review.

## State-cue proposal implemented

A fixed-screen, high-contrast Machine A review panel now uses distinct text symbols and explicit state names: `>> WORKING`, `II PAUSED`, `! HOSTILE`, `(+) SHOT PENDING`, `O DISABLED`, `X DESTROYED`. Hostile explicitly says no shot is pending; paused stays powered; disabled stays intact. Working retains a route-risk description. The charge study explicitly has no live target; actual integration still requires the resolved target-cell warning.

Cargo text appears only while Machine A is the inspection focus, including empty, skid/pump, alternate and hidden-by-wreck descriptions. The panel retains its screen size when the camera changes and remains visible during silhouette inspection. This is a proposal for this single-machine benchmark, not a scalable enemy list or a production targeting UI.

[Day normal](machine-cues-day-8.png) · [Day wide](machine-cues-day-16.png) · [Night normal](machine-cues-night-8.png) · [Night wide](machine-cues-night-16.png). Rendered benchmark checks pass for all six names, hostile/pending distinction, inspection-only cargo details and encounter preservation. Screens show the charged state at normal/wide distances; they do not constitute a new 108-view matrix. Model silhouettes and final textures remain unchanged. Production snapshot wiring, multiple-machine selection, smaller-window layout, and user acceptance remain open.
