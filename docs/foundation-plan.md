# Foundation restructuring

Decision date: 15 November 2026. Design baseline: GDD v3.1, with the overwatch scheduling clarification below.

## Why

The active `farm_final.tscn` currently reaches the tactical base through eleven script layers. Each prototype gate added behavior through inheritance, including drawing, input, save handling and mission logic. The chain is useful history, but it should not become the template for a new campaign mission.

Restructure incrementally, keeping playable builds, old saves, deterministic action outcomes and the earlier gate scenes working. No new mission or combat rule is part of this pass.

## Completed: civilian simulation extraction

`holdfast/systems/civilian_evacuation.gd` is an independent `RefCounted` component. It owns the algorithms for safe pathfinding, complete route previews, route choice, following a soldier, waiting reasons and bounded civilian movement. It does not load a scene, draw, read input, advance turns or write saves.

Its constructor accepts explicit mission callbacks:

- Whether a cell is safe now.
- The waypoint for a route and the current civilian exit.
- Whether a route is available now.
- Whether a soldier can currently lead.
- Notification after an actual civilian step (for mission evidence/history).

Cohort and soldier dictionaries are supplied by the caller. The service does not cache the soldier array; loading or replacing a mission therefore cannot leave followers attached to stale state. Only `move_cohort` mutates a cohort. Path inspection and route selection leave state untouched. The existing east/north/south/west tie order is preserved.

`farm_evac.gd` now delegates to this component through compatibility methods. It still owns the civilian panel and controls, order allowance, turn sequencing, casualty effects, operation closure and save serialization. Existing return-map and breaker overrides supply the same live mission policies as before. The complete inheritance chain is **not removed yet**.

## Verification for this pass

- Independent 6×5-map tests instantiate only the component, without Farm Road. They cover route ties, changing route availability and hazards, no-route cases, a different exit, leader loss, replacement actor arrays, hold, stranded/extracted groups and exact step notifications.
- The full Follow rescue still evacuates 12 civilians and all four soldiers on origin and return in round 7. A legal wounded-leader rescue also evacuates all 12 and extracts MSG in round 7.
- Before/after snapshots match exactly after 119 legal actions across divert, disable, destroy, pause-only, nonintervention and early withdrawal. Outcome metrics also match.
- Opening/debrief, persistent roster, return consequences, ending fixture, civilian guidance, saves and staging-care regressions pass.

Run the committed tests from the repository root:

```sh
godot --headless --path holdfast --script res://tests/test_civilian_rules.gd
godot --headless --path holdfast --script res://tests/test_follow_rescue.gd
```

## Remaining sequence before a new mission

1. Extract machine activation/intent and explicit turn resolution behind tested interfaces. Preserve the visible warning → player response opportunity → damage sequence.
2. Separate mission layout and objective policies from the encounter controller. Origin and northbound return become data/configuration users of the same services.
3. Separate HUD/input and opening/roster/debrief views from simulation. Remove inherited drawing overlays as those views move.
4. Move save orchestration to a boundary that serializes the same checked state. Preserve old saves or provide an explicit tested migration before changing formats.
5. Introduce a shallow encounter controller that composes the extracted services. Keep gate scenes as fixtures until parity checks pass, then retire redundant adapters deliberately.

Each step should ship with equivalence and failure-path checks. File movement alone does not count as finishing the architecture work.

## Overwatch scheduling clarification

**Overwatch is deferred until after Gates A–D, alongside suppression and the first armed, moving Grey/Reptilian encounter; it is not an outstanding requirement for the current Farm Road prototype.**

Farm Road's machine can become hostile when attacked, so a theoretical trigger exists. The decision is about sequencing and useful encounter coverage, not a claim that it can never be hostile. No overwatch trigger or suppression rule is added in this refactor. This tracked decision clarifies the schedule; the original v3.1 Word document remains intact.
