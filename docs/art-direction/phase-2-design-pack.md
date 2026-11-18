# Phase 2 design pack — first review

Status: V2 exploration, not final asset approval. Created with built-in image generation; exact prompts are in [the generation record](phase-2-prompts.md). No models, rigs, textures or gameplay replacements have been installed.

## Approved direction

Grounded human characters and environments; greater color range and unusual forms become appropriate as distinct alien factions, spacecraft and creatures enter the story. Day and night missions are required. Lighting does not yet change sight, stealth, accuracy or enemy behavior. Environment destruction scope remains open.

## Review sheets

### Squad

[Squad studies](squad-studies-01.png): front and rear equipment exploration, with small silhouette comparisons. MSG's radio/antenna, Ortiz's broad medical pack, Bell's asymmetric tools and Park's lighter optics kit provide role cues from behind. Recommended direction: preserve those four equipment profiles while simplifying small details for the game camera.

Faces, hairstyles, head protection and exact insignia are provisional. The generated MSG rank patch must not be treated as an accurate approved uniform detail. The MSG remains customizable. Bell's dangling tools should be secured in production, and Ortiz/Park need further separation when seen as small black silhouettes. Verify sling paths, hands, shoulders and hip clearance before rigging. This is a first equipment sheet, not a complete turnaround or final character identity sheet.

### Recovery machine

[Three alternatives](machine-alternatives-01.png): alternatives for one machine, not three new enemy classes.

| Option | Strength | Design risk |
| --- | --- | --- |
| A — Folded shell | Compact, clear envelope, protected cargo | Can read as armored combat equipment |
| B — Ribbed cradle | Exposed cargo and asymmetric ribs convey recovery work | Tall parts could obscure adjacent people; requires camera test |
| C — Low arch | Low silhouette preserves sightlines | May blend into ground and lose identity at distance |

Recommendation: develop B, with A's compact footprint discipline. This recommendation is not an approved selection. Keep neutral work posture distinct from hostile shot preparation, paused work, diversion and disabled states. Generated symbols and amber lamps are design suggestions, not a new language or gameplay signaling rule. The machine retains one logical occupied cell; confirm its silhouette and overhang at actual map scale.

### Farm Road and lighting

[Day/night and modular kit](farm-road-day-night-01.png): atmosphere and material targets, with paired views and isolated kit pieces. The generated view is too low/perspective-heavy to define the final camera; retain the existing elevated orthographic Godot camera. The two panels approximate the same layout but are not a geometry-matched engine lighting test. Night figures need stronger edge/value separation in the V3 benchmark. Do not brighten by turning every material blue.

| Asset group | First production specification | Gameplay constraint |
| --- | --- | --- |
| Road, gravel, ground | Tileable surfaces; quiet detail under route markers | Flat square grid, unchanged traversal |
| Low cover | Consistent short profile, readable top edge | Existing north/south cover edges only |
| Full wall | Distinct taller profile; preserve openings | Exact four wall cells and gaps from mission resource |
| Pump skid | Compact recognizable recovery cargo | Traversable objective cell; collection rules unchanged |
| Breaker | Upright service cabinet with clear open/isolated states | Blocked fixture; adjacent operation |
| Console | Sloped interface, readable at night | Blocked fixture; authentication/diversion rules unchanged |
| Fence, barn, foliage, poles | Background modules, modest wear and ordinary life | No unannounced collision or blocked sightlines |
| Lighting | Day rig and night rig on identical geometry | Readability only until separate mechanics approved |

A production checklist must also include civilian group design, squad/civilian extraction markers and machine hazard overlays. Those are not sufficiently specified by these sheets and remain V2 work.

## Next gate

Review the squad direction, choose or revise the machine alternative, and accept/revise the day/night mood. Then complete civilian silhouettes, selected-machine front/side/back studies, character identities/headgear and precise kit dimensions. Build only a small representative V3 scene after those decisions; do not animate the entire placeholder roster or model a whole campaign yet.

The V3 test must compare the approved designs at normal camera scale in daylight and darkness, check grayscale role recognition and overlapping silhouettes, and confirm that cover, routes and warnings remain visible. Performance budgets follow measured results on target hardware.
