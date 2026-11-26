# Mission 10 · The Dam — playable spec (v1 greybox)

Status: APPROVED (Spence, 25 Nov 2026), built as v1. Tuning changes from the first sims are under "v1 tuning" at the end.

Sources:
- GDD v3.1 §11 Mission 10.
- §06 Drovers.
- §07: Kesh, authentication, and mutual accountability.
- §26: the Quarry habitat can't be restored.

All numbers are test values. This is Act III, "The Enemy of My Enemy".

## What the player does

The dam north-west of the valley feeds the buried power trunk. The reservoir behind it is rising, because the Fallow have been at the dam face. Two human groups are on the lowland below the spillway. A Drover habitat sits in the cavern at the dam's base. Its families and its ecological cargo are what the Quarry platform was powering. Kesh is on the channel, offering guidance in exchange for protecting Drover dependents. This is the GDD's first cooperative objective.

Objectives:
1. **Get the human groups out.** Groups A and B (8 people) go from the lowland to the south exit.
2. **Protect the Drover dependents.** Group C stays in the habitat. It's safe if the habitat is **stabilized** and isn't flooded at the end.
3. **Don't breach the dam.** Keep the pressure below breach.
4. Optional: **move the ecological cargo.** Two crates go from the habitat mouth to the trunk tunnel.
5. **Get the squad out.** MSG must get out.

Deadline: after round 10, the trunk has to be sealed and everyone leaves.

## Pressure and the spillways (the flood clock)

- **Pressure** starts at 2. It goes up 1 each round, and 1 more each time the Fallow fold a strip of the crest into rift. At **8 the dam breaches**: the lowland and the habitat both flood. Anyone still on low ground is lost, and the habitat is lost.
- **Two spillway valves** on the crest. A soldier adjacent spends 1 AP to open one. It **drops pressure by 3**, and the water has to go somewhere:
  - **West spillway** floods the **west lowland** for 2 rounds. That's where groups A and B start.
  - **East spillway** floods the **habitat mouth** for 2 rounds. Anyone there takes 4 damage, and crates there are lost.
- There's no free valve. Every release costs somebody something. Timing it is the puzzle.

## Kesh's guidance (an authenticated partial channel)

Each round, Kesh tells you which spillway's channel is clear of Drover dependents, and how many rounds until the next Fallow mark hits the dam. How much you get depends on the Quarry.

| Quarry outcome | What Kesh can give |
|---|---|
| **Controller recovered** (authenticated) | Full guidance every round. MSG can also open a valve **remotely**, from anywhere on the crest. |
| **Habitat powered but no controller, or isolated** | Partial guidance: every other round, and no remote valves. If the habitat was isolated, its power junction needs **repair** (2 AP) before it can be stabilized. |
| **Habitat lost** | Kesh's terms harden. She says what the Drovers need and nothing more. No guidance until the dependents are stabilized. |

## Power allocation (human evacuation, the habitat, the ark)

The turbine room gives **3 power**. MSG assigns it at the turbine (1 AP per change).

- **Lowland footbridge**, 1 power. It extends across the spillway channel, cutting the human groups' route roughly in half.
- **Habitat life support**, 1 power. It's required before the habitat can be stabilized (2 AP of work at its console, done by any soldier).
- **Ark trunk**, 1 or 2 power. It sends power down the trunk to the ark. 2 power is best for the ark's state at Mission 11, and 1 is partial.

Every unit given to one thing is a unit another doesn't get.

## Transport

- **The Drive Rig** comes if you've had it since the Quarry. It carries one cargo crate per trip to the trunk tunnel.
- **A Drover cart** comes if no Drover security was killed at the Interchange (restraint counts). It also carries one crate per trip.
- With neither, soldiers carry crates. It's the casualty-carry rule: 2 squares per AP, and no firing.

## Pressure from the Fallow

A cutter and node work along the dam face from round 3, marking crest squares. Rift on the crest adds pressure (see above). Interrupt the node or kill the cutter; that's the Main Street rule.

## What it records (campaign record, mission 10)

- The human groups' fate.
- The dependents: stabilized, flooded, or left.
- Whether the dam breached.
- Valves opened, and who they flooded.
- Power allocation at the end.
- Ark trunk: 0, 1 or 2.
- Cargo crates moved.
- The Kesh channel level.
- Squad status.

## What carries forward

- **Habitat stabilized and cargo moved.** The ark stewards accept the parley terms Kesh negotiated. The best start at the Buried Ark (Mission 11).
- **Ark trunk power: 2, 1 or 0.** At the ark, this decides which ark systems (the Warden's controls, the lift) start powered.
- **A habitat abandoned, or equipment lost.** The GDD's failure path. Survivors still lead the team to the ark; the terms are harder.
- **The physical revelation.** Families, maintenance records older than any human city, and preserved ecology. These scenes play whatever the outcome.

## Build plan

1. `missions/the_dam.tres` and `the_dam.gd`, extending the encounter controller with the Farm Road machine off:
   - Dam crest, valves, turbine room, lowland, footbridge channel, habitat cavern, trunk tunnel, south exit.
2. `systems/dam_works.gd`:
   - pressure, valves, floods, breach;
   - power allocation and footbridge;
   - habitat stabilization and repair;
   - cargo and transport;
   - Kesh's guidance levels.
3. Reuse `systems/fallow_cutter.gd`, `systems/drive_rig.gd`, and the casualty-carry movement rule for crates.
4. HUD:
   - Map drawing: water and floods, the pressure gauge, valves, the bridge, crates.
   - Buttons: Open valve, Assign power, Stabilize, Repair, Load crate, Rig/cart orders.
   - A Kesh guidance line in the priority box; briefing.
5. Campaign: Mission 10 playable on the board, a record entry, carry-ins from Missions 01/04/07, carry-forward.
6. Tests and a balance sim. Full suite on the Mac before pushing.

## v1 tuning (first sims, 25 Nov 2026)

- Breach moved from 6 to 8, and a valve drops pressure by 3 (was 2). At the spec's numbers the dam breached by round 3 or 4 even with perfect valve play: pressure rose faster than the valves could take it off.
- A Fallow fold adds +1 for the whole strip, not +1 per square. The cutter marks one round and folds the next, so it's roughly +1 every other round.
- A spillway floods for 2 rounds: the round it's opened and the next. Then it can be opened again.
- The turbine moved to (8,4) so the turbine room opens onto the crest through the dam-wall gap at (10,3).
- MSG and one soldier start west of the channel, at (6,14) and (7,14), near the lowland groups. The other two start east, at (11,14) and (12,14). MSG has to be within 6 squares to order a group, and the old spawn was too far.
- Sim result: a scripted player who opens the west valve every other round holds the dam at 5–7 the whole way. Everyone gets out and the habitat is stabilized. The pressure sits one or two below breach most rounds. The rifts creep west along the crest and can cut off the east valve.
