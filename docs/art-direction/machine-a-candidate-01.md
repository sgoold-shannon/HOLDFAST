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
- Nine solid-color materials, no texture maps or animation. Emission is separate from shell materials. Work lamps are on in this static candidate; disabled/charged behavior is not yet wired.

Rebuild from the repository root:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/art/build_machine_a.py
```

## Measurements and checks

Evaluated source: 12,440 triangles, 94 mesh objects, nine materials, zero texture bytes. Resting bounds: approximately 0.920 × 0.912 cells on the ground, 0.961 cells tall. These are benchmark cell units, not real-world meters. The mesh count is an initial authoring structure, not a production draw-call budget; consolidate static parts after shape review while retaining moving/state-controlled parts.

Godot rendered benchmark tests pass: imported footprint and ground origin, no collision objects, preserved tool hierarchy, empty initial cargo, cargo toggle, day/night controls, silhouette material restoration, and unchanged encounter on exit. Front/rear close-ups, wide daylight and close night were inspected on Apple M4 Max using the compatibility renderer. The full close/normal/wide × all-state acceptance matrix is incomplete. No performance budget, frame-time result or representative PC acceptance is claimed.

## Next gate

Refine the shell/material candidate against the selected concept, then build alternate cargo, paused, hostile/charge, disabled and collapsed-wreck appearances. Review their silhouettes and zoom readability before animation. Keep the candidate in the separate benchmark until this gate passes; gameplay zoom requirements and production camera work remain deferred.
