# Mission 07 · Quarry — playable spec (v1 greybox)

Status: APPROVED (Spence, 24 Nov 2026), building v1.

Sources:
- GDD v3.1 §10 Mission 07.
- §06 Drovers.
- §08 deferred rules: a new mechanic must state its cost, timing, information, counterplay, save state and acceptance case.
- §26: the Quarry habitat can't be restored by later repairs.
- §20 Fallow tells.

All numbers are test values. This mission closes Act II, "The Hidden War".

## What the player does

Command has flagged the old quarry's power platform as hostile command infrastructure, and Ward's orders say to secure it. The briefing has already told you the truth. Before anyone moves, two quarry workers who saw Drover families below the ridge and the platform's own telemetry both confirm the same thing: **it powers an occupied Drover habitat**. This mission isn't a reveal. It's a known trade-off under time pressure.

Two civilian groups are trapped in the old haul tunnel. The tunnel face is coming down. The fastest way to reach them runs straight through the platform's live power trunk.

Objectives:
1. **Rescue the trapped groups**, then get all three groups (12 people) out of the quarry gate:
   - A and B: miners and refugees in the haul tunnel.
   - C: the quarry crew on the upper bench.
2. **Decide the platform's fate**: demolish, isolate, or recover its controller.
3. **Get the squad out.** MSG must get out.

Clocks:
- The tunnel collapses at the end of round 9. Anyone still inside is lost.
- The quarry is overrun after round 10.

## The three plans (GDD: disable versus destroy, with a timed recovery)

| Plan | How | Rescue | Platform and habitat |
|---|---|---|---|
| **Demolish** | Set a charge at the platform (2 AP, adjacent). It blows in the next environment phase. | The blast clears the west tunnel mouth at once. This is the fast, short route. | Platform destroyed. **The habitat and its ecological reserve are lost permanently.** A later repair can restore a power connection, never the habitat. |
| **Isolate** | Three steps (1 AP each): kill junction box West, kill junction box East, then confirm the safe-off at the platform. | With the trunk dead, the west-mouth debris can be dug out: 3 squares, 2 AP each, or the Drive Rig digs 1 square per turn. Then the short route opens. | The platform is intact but inert. The habitat runs on reserve; it survives, but its supply is strained. |
| **Recover the controller** | A timed recovery: one Download step per round, over 3 separate rounds, at the platform console. Any soldier can do it, but the platform keeps running, so the west mouth stays live. | Groups have to take the **long route**: the east airshaft path, around twice as far. Start them early and protect them. | Platform running. The habitat is fully powered. You have its controller for the Dam and the ark. |

The record keeps all three outcomes valid. The debrief **names what MSG knew, what he recommended, and what was actually saved**. That's the GDD's wording.

## New mechanic: elevation (scoped)

- **Where.** The upper bench (rows 1–5) is high ground. The quarry floor is low ground. Two ramps connect them.
- **Effect.** Shooting from high ground at a low target: +10. Shooting from low ground at a high target: −10. It stacks with range and cover as normal, clamped to 5–95%.
- **Cost.** None. Ramps are ordinary squares.
- **Information.** The aim preview shows the elevation modifier.
- **Counterplay.** Take the bench yourself, or break line of sight.
- **Acceptance.** Shooting from the bench shows +10, and shooting up shows −10.

## Pressure: a Fallow incursion

- A cutter and node arrive over the ridge at the start of round 4. The distortion is shown at the end of round 3. These are the Main Street rules: mark a strip, then transform it into rift the next phase; Interrupt the node; kill the cutter (12 HP).
- Ground next to the **Drive Rig** is sheltered from marks, the same as the parked platform at Main Street.

## The Drive Rig returns (carry-in from Farm Road)

- The rig shows up if the Farm Road machine was **disabled or diverted**. It's the same machine, now industrial gear with a defensive role.
- **Orders.** One free order a turn, given by MSG within 6 squares:
  - **Move** up to 2 toward a chosen soldier.
  - **Dig** an adjacent debris square (only once the trunk is dead).
  - **Brace.** It stays put, and every square next to it is safe from Fallow marks.
- If the Farm Road machine was destroyed or left on its own, there's no rig. Every plan is still possible by hand.

## Other carry-ins

- **The Interchange cargo was seized.** The platform is missing that component, so controller recovery takes 4 steps instead of 3. The Drovers' repair demand shows up here.
- **The Hospital convoy passed under watch.** The stewards open a maintenance hatch on the long route, which cuts about 4 squares off it.
- **The Rail Yard archive was recovered** (survey or full). The geology surveys show which debris is loose, so digging costs 1 AP a square instead of 2.

## What it records (campaign record, mission 07)

- Each group's fate.
- Platform: demolished, isolated, or running with the controller.
- Habitat: lost, strained or powered.
- Whether the controller was recovered.
- Whether the rig was present, and what it did.
- Fallow rifts.
- Squad status.
- The debrief line: what was known, what was recommended, what was saved.

## What carries forward (Act II closes)

- **Habitat lost.** It's permanent: the Dam (Mission 10) and the ark scenes keep the loss. Kesh's terms harden.
- **Habitat strained (isolated).** The Dam opens with a repair objective.
- **Habitat powered, controller recovered.** The best terms at the Dam. The controller authenticates a partial channel there.
- **Act II complete.** Ward accepts that these are separate threats with separate objectives, and that treating one like another costs lives. The Operations board marks Act II COMPLETE. Act III, "The Enemy of My Enemy", starts at the Regional Airfield.

## Build plan

1. `missions/quarry.tres` and `quarry.gd`, extending the encounter controller with the Farm Road machine off:
   - Map with benches, ramps, the tunnel, the platform, two junction boxes and debris.
   - Elevation via a `sight_preview` override.
2. Systems:
   - `systems/quarry_works.gd`: platform plans, charge, isolation steps, controller recovery, debris and digging, tunnel collapse.
   - `systems/drive_rig.gd`: orders and shelter.
   - Reuse `systems/fallow_cutter.gd`.
3. HUD:
   - Map drawing.
   - Buttons: Set charge, Junction box, Confirm safe-off, Recover controller, Dig, and the rig orders.
   - Briefing (corroborated habitat facts), priority box, an Act II closing page in the debrief.
4. Campaign: Mission 07 playable on the board, a record entry, carry-ins from Missions 01/04/05/06, carry-forward, and Act II complete.
5. Tests and a balance sim for each plan, with and without the rig. Full suite on the Mac before pushing.
