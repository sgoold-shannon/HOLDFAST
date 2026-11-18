# HOLDFAST visual direction brief — draft 01

Status: grounded visual direction approved by Spencer; individual designs and production assets remain provisional. Scope: Farm Road visual benchmark. Authority: GDD v3.1 sections 01, 21, 25–27; current mission resource; user's approved behind-squad, uphill-screen isometric direction. Calendar year, real-world location and final character appearances remain open.

## What the player should feel

A competent, recognizable team protecting people in an ordinary place that has become unfamiliar. Tactical danger should be understandable even when the machine's purpose is uncertain. The environment starts inhabited and functional; spectacle must not erase the importance of people or infrastructure.

## Established constraints

- Serious stylized military science fiction; grounded near-future human equipment.
- Fixed elevated angled 3D camera, squad toward the bottom advancing up-screen, mostly seen from behind. This is screen composition, not an elevation mechanic.
- Farm Road remains a 20 × 16 square grid. Existing walls, gaps, cover, fixtures, exits and paths retain their logical coordinates.
- Drover recovery machinery is neutral until attacked, has a one-cell gameplay footprint and exists to recover cargo. Its appearance must allow a plausible noncombat reading.
- MSG is a customizable active-duty Army PSYOP Master Sergeant. Ortiz, Bell and Park keep the roles and characterization established by the GDD.
- Silhouette, posture, symbols and material supplement color. Art must not obscure AP, ammo, casualty states, route warnings or extraction.

## Direction 02: approved foundation, provisional details

Use simplified, substantial forms and selective wear: fabric, painted metal, concrete, gravel and sun-aged farm surfaces. Keep fine camouflage and surface noise subordinate to readable body and equipment shapes. Use muted olive, slate, dry grass and warm concrete, with restrained amber machinery lights. Role accents should be small equipment/patch details, not whole bright uniforms. Exact palette remains provisional.

Day and night missions are a confirmed presentation requirement. Start with matched lighting studies on the same Farm Road geometry; this does not authorize stealth or darkness-based visibility mechanics. Preserve readable ground edges, silhouettes and interface contrast at night. Alien factions, spacecraft and creatures may progressively expand the palette and formal strangeness when appropriate to their identity and narrative context; do not recolor the grounded human baseline indiscriminately.

Daylight should make hazards readable without relying on darkness or red lighting to imply hostility. Test neutral, paused, diverted, hostile, disabled and destroyed machine states with pose, symbols and effects. An amber work lamp alone is not a danger indicator.

### People

| Character/group | Rear-view recognition proposal | Design constraint |
| --- | --- | --- |
| MSG / PSYOP | Radio pack, antenna, deliberate upright posture | Communication expertise, not a magical persuader; face and identity remain customizable |
| SFC Lena Ortiz / medic | Distinct compact medical bag and accessible supplies | Practical casualty handling; no stereotyped sexualized silhouette |
| SFC Daniel Bell / engineer | Asymmetric tool satchel, robust equipment harness | Competent technician; avoid turning tools into oversized fantasy props |
| SSG Evan Park / recon | Lighter load, compact optics and notebook pouch | Observant, not invisible or a universal alien expert |
| Civilian cohorts | Varied civilian clothing, posture and personal belongings | Preserve group readability; four people represented per cohort, without adding individual injury/pathfinding rules |

Before final modeling, produce front/back/side studies, head/portrait explorations and equipment callouts. Hats, helmets, markings, proportions, faces and demographics shown in the concept are exploration only. Preserve distinct roles at normal gameplay scale before adding facial detail. Medical markings need their own approved fictional graphic treatment rather than inheriting a generated symbol automatically.

### Recovery machine

Explore a compact, nonhumanoid recovery platform: repaired shell sections, a folded manipulator, cargo cradle and nonhuman structural rhythms. Keep moving parts and work purpose legible. Direction 02 improves scale and composition but still resembles terrestrial industrial machinery; the next machine sheet should compare more distinctive Drover forms. Avoid a humanoid face, villainous red eyes, skull motifs or a permanently aimed weapon. Model overhangs must not imply extra occupied cells.

### Farm Road kit

First kit: road/shoulder/ground surfaces, exact full-wall and low-cover pieces, pump skid, breaker, service console and exit treatment. Background kit: fence, barn/shed, field vegetation and utility poles. Background concepts such as livestock are optional atmosphere, not new simulated entities. Put large scenery outside playable lanes, or provide occlusion treatment. Never turn decorative fences or debris into unannounced blockers.

## Environment damage decision

Recommended first-slice scope, pending approval: cosmetic impacts, sparks, scorch marks and machine state changes. Existing machine destruction/blast, feeder power loss and gate bypass consequences remain authoritative. Visual debris must not add collision or obscure route markers.

Destructible cover/walls, fires, smoke affecting sight, terrain deformation, elevation advantages and new blocked routes are separate gameplay proposals. Decide which, if any, are desired before building damage-ready assets; record a baseline change and tests before implementation. Do not infer mechanics from concept art.

## Production phases and gates

| Phase | Deliverable | Gate before proceeding |
| --- | --- | --- |
| V1 — direction | This brief plus a scene concept and silhouette language | Tone, stylization and camera approved; damage mechanics remain a separate open decision |
| V2 — designs | Squad sheets, civilians, machine alternatives, modular environment sheets | Approved silhouettes, equipment, materials and asset list |
| V3 — benchmark | One soldier, one machine and a small Farm Road section in Godot | Camera-scale readability, lighting, occlusion and measured performance are acceptable |
| V4 — animation/feedback | Rigged move/aim/fire/hit/critical/carry/evacuate actions, machine states, sound and effects | Actions remain clear and cannot change resolved gameplay outcomes |
| V5 — environment states | Approved damage and powered/unpowered states | Visual states agree with rules, collision and paths |
| V6 — complete slice | Consistent Farm Road art, interface, audio and optimization | Full route regressions, accessibility checks and user playtest acceptance |

Do not set arbitrary polygon or texture budgets yet. Measure the representative V3 scene on the user's Mac and a selected PC target, then record budgets before expanding production. Build animation needs into V2 designs: accessible hands, usable joints, shoulder/carry clearance and equipment that will not clip through casualties.

## Review notes for concept 02

[Concept board](concept-02.png) is an AI-generated mood/composition study, not an exact level map, production model or screenshot. It is not a projection specification: the actual camera remains the tested Godot camera. Generated civilian counts, wall positions, scenery and machine proportions must be reconciled with the mission resource in V3. The current board is stronger on atmosphere and rear silhouettes than on unique alien design.

Next concrete design task after direction review: compare three Drover recovery-machine silhouettes and develop the four soldier rear silhouettes at the actual game camera scale. No animation production or gameplay changes begin at this gate.
