# Mission 02 · River Bridge — playable spec (v1 greybox)

Status: BUILT (v1 greybox), approved by Spence 19 Nov 2026. Source: GDD v3.1 §09 (Mission 02), §20 (threats), §28 (Grey and Nordic contracts), §13 (tactical rules). Every number is a test value.

## What the player does

The task force has to get a civilian column across the river before dusk. Reports from the far bank don't agree: machines that reroute around people on one side, people being taken on the other. They aren't the same thing, and this mission is where the squad learns that.

Objectives:
1. **Escort the column across.** Three civilian groups (12 people) from the west bank to the CIVILIAN EXIT on the east bank. Same command rules as Farm Road (MSG's voice, 1 AP orders, panic).
2. **Recover the damaged sensor** in the reeds south-west of the bridge. Optional, but it feeds Act I's evidence.
3. **Get the squad out** through the east-bank EXIT squares. MSG must get out.

Deadline: the crossing closes after round 9 (dusk).

## Map (20 × 16)

- River: columns 9–10, impassable to everyone. It blocks movement, not sight.
- Bridge: columns 9–10, rows 7–9. Three rows wide.
- West bank: squad spawns at column 2, rows 7–10. Civilian groups at (4,5), (4,8), (4,11).
- Sensor: (6,14), in the reeds.
- East bank: CIVILIAN EXIT (19,8), squad EXIT squares column 19, rows 6–10. A stone barn at (14–15, 11–12) gives shelter.
- Grey site: north-east field around (15,3).

## The choice: who gets the bridge

At the checkpoint on the west end of the bridge (8,8), a soldier standing next to it spends 1 AP to set the lanes, once:

- **People first.** All three bridge rows open to civilians. The supply trucks wait and don't cross: supplies are lost to the task force.
- **Heavy lane.** Rows 8–9 go to the supply convoy, so civilians cross single file on row 7: one group on the bridge at a time, at most 2 squares a turn while crossing. That's slower and they bunch up, but the supplies get through.

Until someone sets the lanes, civilians can't step onto the bridge. Capacity and time stop you doing everything; neither choice is "right".

## Greys (GDD §28: extract selected specimens; escalate only when a shipment is interfered with)

Two units. Balance values live at the top of `systems/grey_team.gd`. They act in the machine's phase, after the player and before civilians.

**Collector**, 8 HP, abduction emitter.
- **Tell:** marks the nearest civilian group within 6 squares with **LIFT 2**. It moves 3 squares a turn toward the nearest group until one is in reach.
- **Timing:** each Grey phase the countdown drops by 1. At 0 the target is taken: the group's status becomes TAKEN. Not dead, and recorded by name.
- **Counterplay:** any hit on the Collector breaks the lift and resets the target, and so does getting the group into the barn. Once it's locked on, distance doesn't break it (GDD §20: interrupt the emitter or reach shelter). Changed from the first draft after balance runs showed groups simply outran every lift.
- **Captives come first.** It prefers people over the squad.

**Sentry**, 6 HP, beam.
- **Escalation:** passive until the squad interferes. That means shooting either Grey, or a soldier coming within 3 squares of the Collector. After that it stays hostile.
- **Tell:** once hostile, at the end of its phase it shows an aim line to a soldier in sight within 8 squares.
- **Fire:** next phase it fires along that line. The first person in the line takes 4 damage; a civilian group caught in it takes 2.
- **Counterplay:** break the line by moving or by putting a wall or cover in the way.

**Withdrawal.** The extraction clock beats territory: the Greys leave at the end of round 8, or right away if the Collector drops. They abandon cheap hardware, which can be recovered as evidence, and carry their tagged cargo.

## The unidentified craft (GDD §05, §28: finite protection charge, then departure)

Once per mission, the first time a lift on a civilian group would complete, an unidentified craft spends its only shield charge. The lift fails, that group can't be targeted for the rest of the round, and the craft limps east trailing smoke. Its identity isn't confirmed here; the record notes "unidentified craft, shield spent, damaged".

## Panic

Grey units and active aim lines count as threats for civilian panic, the same as the machine and gunfire at Farm Road.

## What the mission records (campaign record, mission 02)

Each group's fate (crossed, taken, stranded), the lane choice and supplies (kept or lost), the sensor (recovered or not), how the Greys ended (withdrew or Collector down), whether the craft shielded someone, and squad status.

## What it carries forward (applies as later missions are built)

- **Supplies:** kept supplies count as resources at the operations base.
- **Sensor:** raises intel confidence for Main Street (Mission 03).
- **Taken groups** stay named and unresolved; they become a rescue opportunity at Rail Yard (Mission 05).
- **Witnesses:** civilians who crossed corroborate "machines reroute, Greys take people". That moves the squad toward rejecting the single-invasion line.
- **The craft** is the first Nordic sighting, verified later at the Regional Airfield (Mission 08).
- **If the column isn't fully across by dusk:** the remainder takes the longer convoy route, and that's recorded.

## Build plan

1. `missions/river_bridge.tres` (map data) plus `river_bridge.gd`, extending the encounter controller with the Farm Road machine switched off.
2. `systems/grey_team.gd` for Collector and Sentry rules, and `systems/bridge_lanes.gd` for the lane choice, sensor recovery and craft event.
3. HUD: draw the river, bridge, Greys, LIFT countdowns and aim lines. Add Set lanes and Recover sensor buttons, a River Bridge briefing and a results/debrief.
4. Campaign: Mission 02 goes playable on the operations board, launched after Farm Road, and writes its record.
5. Tests: Grey rules, lane choice, craft event, record, and HUD play. Full suite on the Mac before each push.
