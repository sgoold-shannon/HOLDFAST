# First production asset — Machine A

Status: scoped production plan, not a completed or accepted model. Machine A's folded-shell direction is owner-selected. Start with one reusable machine asset; keep it in the separate benchmark until its acceptance checks pass. Current blockout geometry is reference material, not the final mesh.

## Benchmark review

| Finding | Current evidence | Production consequence |
| --- | --- | --- |
| Rounded shell and aperture | Procedural shell reads as a distinct volume; backing removed seam holes | Preserve layered panels with recessed backing and a real cargo opening |
| Empty/loaded state | Toggle works on unchanged geometry | Model cargo as a separate removable part |
| Day/night | Both lighting rigs render; night separation improved | Validate final surfaces under both rigs, not just a flattering studio light |
| Close-up | Shape can be inspected; blockout remains visibly primitive | Refine silhouette, panel thickness and material transitions before small surface marks |
| Civilians sharing space | Single formation readable; multiple cohorts still obscure bodies | Do not approve shared-space offsets for production from this study alone |
| Group markers | Selected members remain identifiable despite occlusion | Useful diagnostic; final marker styling and picking remain separate UI work |

## New owner requirement: gameplay zoom

Players must be able to zoom in and out during gameplay. This requirement is recorded now; this task does not implement or change zoom. Existing prototype wheel zoom is not evidence of a finished camera feature.

Retain the elevated, behind-squad orientation. Zoom must preserve logical cells, action costs, hit tests and selected targets. Proposed behavior: bounded smooth zoom with a reset/fit control; fixed-screen interface text and action controls remain readable. Exact range, speed, input bindings, focus behavior and persistence are open until camera testing. No camera rotation or free-flight behavior is implied.

All final assets must be evaluated at close, normal and wide gameplay framing, in day and night conditions. At wide framing, identity and tactical state must not depend on tiny markings. At close framing, shell seams, normals and cargo articulation must hold up. At all framings, labels/markers must not become an overlapping wall of text. Test pointer-to-cell mapping and UI separation when the production camera is implemented.

## Deliverables and order

1. **Static model candidate.** Consistent front/side/rear/top geometry based on selected A, including shell thickness, backing, opening, compact base and folded recovery tool. Root at cell center, ground contact at zero. Use one benchmark grid unit as the provisional cell reference, not an asserted real-world meter scale. Proposed resting envelope: no more than 0.95 cell width/depth, with height decided against the soldier. Record any intentional tool overhang.
2. **Asset assembly.** Separate base/shell, tool joints, cargo socket, work lamps and defensive emitter. Provide an editable source and a Godot-importable model/scene with named parts. Avoid rebuilding final geometry on each scene launch. Choose authoring tooling before model production; no external mesh service has been selected.
3. **Material candidate.** Restrained stone/olive repaired metal-ceramic shell; readable differences between shell, joints, cargo and lamps. Empty bay must remain legible. Emission must switch independently from surface color. Produce mapped materials appropriate to the chosen mesh workflow; concept images are not texture maps.
4. **Static state review.** Empty, skid-loaded, alternate-component-loaded, paused, hostile, charged, disabled and destroyed appearances. Make alternate cargo depend on actual mission state. Disabled stays intact and unlit; destroyed cannot create extra collision, cover or damage. Departed disappears.
5. **Benchmark acceptance.** Evaluate the same candidate at close/normal/wide framing, day/night and silhouette view. Inspect against ground/walls and beside people. Record mesh/material counts, texture memory and measured frame timing on the current Mac before setting expansion budgets. A representative PC check remains required later.
6. **Animation handoff.** Only after the static candidate is accepted: confirm pivots/tool range, then animate travel, work, pause, defensive charge/shot and shutdown. Gameplay resolves independently; animation cannot change timing, targeting, damage or outcomes.
7. **Mission integration.** Replace only the machine presentation behind the existing state snapshots; rerun combat, protocol, breaker, evacuation and complete-route comparisons. Keep the original presentation available until validated.

## Acceptance checklist for the static candidate

- [ ] Owner-selected folded-shell identity survives front/rear and elevated tactical views.
- [ ] Resting footprint stays inside the documented envelope; nearby actors and warning tiles are readable.
- [ ] No shell gaps, reversed normals, visible intersections or accidental cargo permanence.
- [ ] Neutral equipment does not look permanently hostile; charge is distinguishable from ordinary work lights.
- [ ] Paused, disabled and destroyed communicate different outcomes without relying on color alone.
- [ ] Day/night and close/normal/wide views inspected; final camera limits remain explicitly provisional.
- [ ] Editable source, importable asset, material set and documented part hierarchy exist.
- [ ] Performance measurements recorded without claiming an untested target budget.

Do not mark this gate passed because a code smoke test succeeds. This is an art/technical review of the actual candidate. No final asset is produced by this planning document.

## Next work item

Blender 5.2.2 is the chosen local authoring workflow. [Static candidate 01](machine-a-candidate-01.md) now exists as an editable Blender file and baked GLB in the isolated benchmark. Its import, footprint, cargo toggle and tool hierarchy pass checks; the acceptance gate remains open. Next refine the shape/material treatment and create the remaining state variants. Defer fine wear, insignia/glyph lore, animation, new destruction rules and additional enemy designs until its shape and import pipeline are proven.
