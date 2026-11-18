# Machine A — static candidate 01

Status: first imported static candidate, **not final art or an accepted animation gate**. Created locally in Blender 5.2.2 LTS from the selected folded-shell direction. No paid asset service or additional software is required.

## Review

[Front, daylight](machine-a-candidate-01-front-day.png) · [Rear, daylight](machine-a-candidate-01-rear-day.png) · [Front, night](machine-a-candidate-01-front-night.png)

These are actual Godot compatibility-renderer captures, with sample cargo toggled on. The scene starts empty. The front opening, rear vent, removable cargo, separate lamps and folded tool now belong to an exported asset instead of geometry constructed at scene launch. Close-up inspection caught and corrected shell-rim shading and an embedded rear service panel.

The candidate remains cleaner and more regular than the repaired concept. Panel layout, surface variation, rim construction, opening proportions and lamp placement need art review. The one-sided tool and contact pads are mechanism proposals, not an approved animation or locomotion design. No glyphs or invented insignia are canonized. Sample cargo is a dimensional reference, not an approved rendering of every collectible.

## Source and export

- Editable source: `art-source/machine-a/machine_a_01.blend` (outside the Godot project, avoiding automatic Blender import dependency).
- Reproducible authoring recipe: `tools/art/build_machine_a.py`. Running it overwrites the named candidate source and export; save hand-edited revisions separately first.
- Runtime asset: `holdfast/assets/machine_a/machine_a_01.glb`, imported through its committed Godot import settings.
- Assembly: MachineA → Shell, Base, ToolShoulder → ToolElbow → ToolWrist; CargoSocket; WorkLights; separate DefensiveEmitter. Parts can be edited independently. The source has non-destructive edge modifiers; GLB bakes them.
- Blender uses Z up/front -Y; the export uses Godot Y up/front +Z. The benchmark rotates the asset to face the squad. Ground contact is at zero and the root is cell-centered.
- Nine solid-color materials, no texture maps or animation. Emission is separate from shell materials. The benchmark now provides static Working / Paused / Hostile / Charged / Disabled studies through a separate presentation-only adapter. Disabled extinguishes both work lamps and the emitter; hostile alone leaves the emitter dark. Charge extends the emitter as a geometric cue. Cargo is independent. These do not yet consume mission snapshots.

Rebuild from the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/art/build_machine_a.py
```

## Measurements and checks

Evaluated source: 14,184 triangles, 106 mesh objects (including both mutually exclusive cargo assemblies), nine materials, zero texture bytes. Resting bounds: approximately 0.920 × 0.912 cells on the ground, 0.961 cells tall. These are benchmark cell units, not real-world meters. The mesh count is an initial authoring structure, not a production draw-call budget; consolidate static parts after shape review while retaining moving/state-controlled parts.

Godot rendered benchmark tests pass: imported footprint and ground origin, no collision objects, preserved tool hierarchy, empty initial cargo, cargo toggle, day/night controls, silhouette material restoration, and unchanged encounter on exit. Front/rear close-ups, wide daylight and close night were inspected on Apple M4 Max using the compatibility renderer. The full close/normal/wide × all-state acceptance matrix is incomplete. No performance budget, frame-time result or representative PC acceptance is claimed.

## Next gate

Refine the shell/material candidate against the selected concept, then review the existing cargo and static-state appearances. Review their silhouettes and zoom readability before animation. Keep the candidate in the separate benchmark until this gate passes; gameplay zoom requirements and production camera work remain deferred.

## Static state review update

Use **State: Working** in the benchmark to cycle six appearances. [Charged capture](machine-a-charged-01.png) · [Disabled capture](machine-a-disabled-01.png). The tool stows inward for pause/defensive posture. Tests cover every work lamp, charge-only emission, independent cargo, pose bounds, exact reset, changing states in silhouette view, and encounter preservation. Rendered checks pass on the current Mac.

Pose differences remain subtle at wide framing; the status text is a diagnostic aid, not final gameplay UI. A target-cell warning remains mandatory for a pending shot when integrated. The departed display, detailed material work, the full day/night/zoom matrix and animation remain open. No production camera or gameplay changes were made.

## Destroyed candidate

A separate editable collapsed-shell model is now available as **State: Destroyed**. [Day](machine-a-wreck-day-01.png) · [Night](machine-a-wreck-night-01.png). Missing upper plates, an uneven inward collapse, exposed supports and a detached crown fragment give it a lower broken silhouette. Disabled remains intact. This is a static shape candidate, not final fracture or material work.

Source: `art-source/machine-a/machine_a_wreck_01.blend`; reproducible builder: `tools/art/build_machine_a_wreck.py` (reads the intact Blender source); runtime: `holdfast/assets/machine_a/machine_a_wreck_01.glb`. Ground envelope approximately 0.89 × 0.86 cells, height 0.406 cells, 3,112 triangles, 29 mesh objects. No lights, animations or collision are authored. Performance budgeting remains open.

The benchmark swaps presentation roots, preserves the intact cargo choice, disables the cargo control while viewing the wreck, and restores it on return. Tests cover all six states, pose bounds, power-down, silhouette restoration and unchanged encounter state. Day/night close-up captures were inspected. The wreck does not add cover, blast damage, debris physics or fire; mission integration remains deferred.

Next: material/surface refinement and cargo review, followed by the full distance/state review before animation. The body remains visually simple, and state readability at wide gameplay framing is not accepted yet.

## Material and alternate-cargo pass

The Cargo button now cycles **empty → skid → alternate → empty**. The alternate component is a rectangular finned module; the skid study retains its cylindrical pump silhouette. Both are removable and mutually exclusive. Exact cargo identity/detail remains an art proposal, and mission-state wiring is still deferred. The wreck hides either choice and restores the remembered choice when returning to an intact state.

Shell stone, olive and replacement panels now have more distinct base colors, metalness and roughness; four small rear service fasteners add restrained repair detail. The wreck was rebuilt from the revised source. These are still solid-color material studies without texture maps, wear maps or final surface acceptance.

[Alternate cargo, day](machine-a-alternate-day-01.png) · [Alternate cargo, night](machine-a-alternate-night-01.png). Rendered benchmark checks pass for exclusive cargo visibility, the three-option cycle, alternate cargo through wreck/restore, all six states, footprint bounds and unchanged original encounter. Day/night close-ups inspected. The export counts include both cargo assemblies even though only one is shown.

Next: complete the close/normal/wide state-and-cargo review, record readability problems and performance measurements, then decide what needs refinement before animation. Passing behavior checks does not approve final art.

The [108-view static review](machine-a-static-review-01.md) is complete. Animation acceptance remains open due to state readability at normal/wide framing. See its concrete follow-up and bounded performance results.

## Runtime export consolidation

Stationary shell, base and each cargo assembly are combined only after saving the editable Blender source. The intact source still contains 106 separate mesh objects; its runtime export now has 19 mesh objects and 28 material slots. The wreck source retains 29 objects; its export has one mesh and six material slots. Material slots are not a measured draw-call count. Shoulder/elbow/wrist hierarchy, individual work lamps, emitter and separate cargo roots remain controllable. Shared export logic lives in `tools/art/export_helpers.py`.

The same 108-view matrix was captured before and after export consolidation. [Before](machine-a-export-review/before.png) / [After](machine-a-export-review/after.png) shows the working machine close up. Captures are not pixel-identical: small edge/shadow/shading differences remain after import. Whole-sheet mean absolute channel differences were 0.011–0.076 on a 0–255 scale; the metric includes background and is not an art-acceptance threshold. [Difference summary](machine-a-export-review/pixel-comparison.json). Visual close-up comparison did not reveal a material or silhouette regression. Benchmark behavior tests pass for cargo, states, bounds, hierarchy, silhouette restoration and encounter preservation.

Whole-scene draw calls in the repeatable sample fell from 428 to 278 for intact states, and 284 to 238 for wreck. This includes interface and scenery; it is not a per-model count. [Before sample](machine-a-export-review/before-measurements.json) / [After sample](machine-a-export-review/after-measurements.json). Frame-interval scheduling differed substantially between runs, so no speedup or guaranteed frame-rate claim is made. Representative hardware/full-mission profiling remains open.

Next art work remains repaired-surface/edge treatment and final mechanism review before animation approval. This export pass changes no camera, collision, gameplay or save behavior.
