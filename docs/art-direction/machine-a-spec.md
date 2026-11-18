# Machine A — folded-shell design specification, draft 01

Selection: Spencer chose option A. Its compact folded shell is the approved direction; this specification's mechanism details and state treatments are proposals pending camera-scale validation. [Turnaround and states](machine-a-turnaround-states-01.png). Generated with the built-in image tool; [prompt](machine-a-prompt.md).

## Shape and construction

Preserve the original A silhouette: compact segmented dome, recessed forward cargo opening, short articulated recovery tool, repaired stone/olive metal-ceramic plates and restrained amber work lamps. Rear service seams and vents distinguish the back from the cargo opening. Avoid adding B's tall ribs or C's broad arch. Exact seam count, invented glyphs and joints in generated views are not binding; reconcile all views into one consistent model before detailed surfacing.

The shell should read as protective working equipment rather than a face or a tank turret. Preserve visible cargo access and tool articulation at the elevated game camera. The foot/contact system remains a locomotion proposal, not an approved walking animation.

## Model assembly proposal

- Root/pivot: centered on the existing one-cell logical position, ground contact at zero height. No authored model scale may change collision, movement cost or occupied cells.
- Base and shell: one stable readable volume, with separately controllable service/tool panels where needed.
- Recovery tool: short articulated hierarchy, folded pose inside the envelope; collecting pose must not imply attacks on adjacent people.
- Cargo socket: removable visual component. Empty before collection; show the correct collected component afterward. The sheet's pump is illustrative, not permanently attached.
- Lamp/emitter surfaces: separate materials so work lighting and a pending defensive shot can be controlled independently.
- Destroyed variant: compact collapsed shell. Debris is visual only; do not add collision, cover, a crater or extra blast damage.

## State mapping

| Existing resolved state | Proposed visual treatment | Required distinction |
| --- | --- | --- |
| Neutral working | Intact shell, purposeful tool pose, restrained work lamps | Not a guaranteed safe object: existing next-step impact warning remains visible |
| Pause acknowledged | Tool stowed, intact powered shell, pause icon in interface | One activation pause, not disabled equipment |
| Diverted | Same machinery and cargo-dependent appearance, route/acknowledgement interface cue | Not a new model or magical recoloring; show actual alternative route |
| Hostile, no pending shot | Intact shell, defensive readiness pose, hostile icon | Hostility alone does not mean a shot fires immediately |
| Hostile, shot pending | Separate emitter charge and existing target-cell warning | Charge follows pending-shot data; color never substitutes for the marked cell |
| Disabled | Intact shell, lowered/stowed tool, all powered lamps off | Recoverable machinery; no collapsed plates or destruction blast |
| Destroyed | Broken collapsed shell, extinguished lamps | Existing destruction event only; wreck display must respect original collision policy |
| Departed | Remove machine from map | Never leave a decorative wreck for a departed machine |

State precedence proposal: departed/removed, destroyed, disabled, then powered pose and protocol cues. Hostility and pending-shot overlays must follow actual data; the sheet is not a mutually exclusive five-state implementation specification.

## Concept review corrections

The generated disabled sketch retains amber accents; production must use non-emissive dark lamps when disabled. The generated sketches all contain cargo; production must begin empty and distinguish skid/component collection. Front/side/top images are approximate perspective studies, not dimensionally consistent orthographic drawings. Some peripheral parts overhang the illustrated footprint; the model envelope must be tested against adjacent actors and selection markers. The hostile emitter and specific locomotion design still need mechanism review.

## Validation before animation

1. Build a simple non-rigged shape study in the separate benchmark, preserving current mission logic.
2. Inspect front, rear and camera-facing silhouettes at normal play zoom in day and night lighting. Also inspect in grayscale.
3. Check cargo-empty versus cargo-loaded, neutral versus charged, paused versus disabled, and intact versus destroyed without reading color alone.
4. Confirm labels, route warnings and adjacent civilian/soldier figures remain visible. Test against both wall and ground backgrounds.
5. Confirm root footprint/picking and collision remain unchanged; then settle exact dimensions, tool reach and moving parts.

A procedural benchmark now supports day/night, close-up, silhouette and overlap inspection. These checks do not validate a final model. Machine A is the first scoped production asset; follow the [production plan](first-production-asset.md), including the newly required gameplay-zoom readability matrix. Civilian studies are drafted and scenario-dependent helmet/cap use is approved; final identities and dimensional asset work remain open.
