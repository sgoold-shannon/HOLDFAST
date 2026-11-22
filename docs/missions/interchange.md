# Mission 04 · Interchange — playable spec (v1 greybox)

Status: APPROVED (Spence, 21 Nov 2026), building v1. Sources: GDD v3.1 §10 Mission 04, §06 Drovers, §07 (why contact fails), §12 overwatch and suppression, §13 interaction contract. All numbers are test values. This is Act II's opener: "The Hidden War". Missions 04–07 teach the player that the threats are different, and that treating one like another costs lives.

## What the player does

A highway interchange east of town is the only road out that Ward's convoy can still use. Armed Drovers are loading cargo in the middle of it, fast and nervous. A civilian group is stuck on the overpass above them. Somewhere south, something small and grey is watching.

The player picks how to get the road open. There are three ways, and the GDD wants all three to be valid:

1. **Honor a corridor pause.** MSG radios the work crew. If they accept, they hold fire and let people through a marked lane for a few rounds while they finish loading.
2. **Escort the stranded group.** Send soldiers up onto the overpass and walk the group down through or around the work zone, with or without a pause.
3. **Assault immediately.** Shoot the Drover security, take the junction and the cargo. Suppression and restraint are the new tools here.

Objectives:
1. **Reopen the junction.** Get three civilian groups (12 people) to the east CIVILIAN EXIT.
2. **Get the squad out.** MSG must get out.
3. Optional: **attribute the drone.** Observe the Grey recon drone before it acts, so everyone knows who did what.

Deadline: Ward's convoy window closes after round 10. The Drovers leave at the end of round 7 if their hauler is still running.

## Map (20 × 16, a highway interchange)

- **Junction work zone** (columns 8–13, rows 6–11). This is the fast way east. The Drover hauler sits at (11,8). Cargo containers are low-cover fixtures scattered around it.
- **Overpass** (rows 2–3, columns 6–16), with a barrier wall along row 4. Ramps go down at the west end (6,4) and the east end (16,4). Group C is stranded at (12,2).
- **Frontage road** (rows 13–14). The slow way round the south side. It's open ground, and it's where the drone comes in.
- Squad starts at the west edge (column 2). Groups A and B shelter behind a jackknifed truck at (4,7) and (4,10).
- The CIVILIAN EXIT is at (19,8). Squad EXIT squares are in column 19, rows 6–10.
- Civilian routes: "north" goes via the overpass's east ramp (16,4), and "south" via the frontage road (15,13).

## The Drovers (armed, recovering cargo, not hostile by default)

- **Hauler.** 20 HP, unarmed. It loads cargo until the end of round 7, then drives out east. While it's in place, the squares next to it are blocked.
- **Two Drover security units**, at (9,6) and (12,11).
  - 10 HP, range 8, 4 damage, Aim 65. They use cover like soldiers.
  - **Alert by default.** They turn hostile if a soldier shoots any Drover, or ends a move within 2 squares of the hauler when no pause is in effect.
  - **Hostile behavior.** Each Drover phase, each unit fires at the nearest soldier in sight. If none is in sight, it moves 2 toward the soldier who provoked it. Their aim line shows a turn ahead, like the Sentry's at River Bridge.
  - They never target civilians. They aren't here for people.
- **"Wary" instead of "Alert"** if the Main Street platform was preserved (isolated or redirected). The first provocation gets a warning shot and a status-lamp signal instead of retaliation.

## The corridor pause

This is Farm Road's bounded-signal test, scaled up.

- **Request.** MSG, within voice range (6) of the hauler, spends 1 AP to **Transmit pause**. The Drovers answer during their next phase.
  - With ACK-01 recorded at Farm Road, they accept straight away.
  - Without ACK-01, MSG first has to **Observe** the hauler (1 AP, in sight), so the request carries a verified pattern. Then he can transmit.
- **Effect.** For 3 rounds, both security units hold fire, and a corridor lane through the work zone is marked in green.
  - Soldiers and civilians can pass within 2 squares of the hauler without provoking anyone.
  - A soldier who shoots a Drover, or steps off the lane next to the hauler, breaks the pause.
- **Return the component.** If the Drover component was recovered at Main Street, MSG can hand it over as part of the request. The pause then lasts 5 rounds, and the record notes returned goods. Keeping it instead is also valid: it's leverage later, at County Hospital.
- **Who breached it.** A broken pause is never automatically treachery. The results screen and debrief say exactly who broke it and why: the squad, the Greys, or nobody (the pause ran out).

## The Grey recon drone (the second pattern)

- **Arrival.** It enters at (18,14) at the start of round 2 and moves 3 squares a turn toward the hauler. 4 HP, so one hit kills it.
  - It's shown when it's within 6 squares of a soldier.
  - If the River Bridge sensor was recovered, it's shown from the moment it arrives.
- **The breach.** In round 4's Grey phase, if the drone is alive and within 6 of the hauler, it fires on the hauler: 4 damage.
  - If the squad has **Observed** the drone first (1 AP, in sight, any soldier), the Drovers see who fired. The pause holds, and the security units turn on the drone.
  - If not, the Drovers treat it as a human breach. They go hostile for 2 rounds, then calm down.
- **Shooting it** also works. Shooting it before it fires stops the breach. The drone counts as a hostile for suppression and fire.
- **Why it's there.** A second operational pattern: Greys watching Drover operations, and willing to provoke a fight between Drovers and humans. The debrief records what was seen, not why.

## New squad tools

- **Suppress** (GDD §12 Gate D rule). 1 AP and 2 magazine rounds, no damage. Targets one visible hostile within 8 squares.
  - It gives the target −20 Aim and a 2-square move until the suppressor's next player phase.
  - It ends early if the suppressor moves, loses sight or goes down.
  - It doesn't stack, and it uses up the soldier's attack for the round.
  - It works on Drover security and the drone. It doesn't work on the hauler.
- **Restrain.** A soldier adjacent to a **suppressed** Drover security unit at 5 HP or less spends 1 AP to take it out of the fight alive. It's recorded as a held Drover, not a kill. Restraint is optional: killing is also legal and is recorded as such.
- Overwatch is still a separate later item.

## Assault path

- Kill or restrain both security units, and the hauler is unprotected.
- **Disable the hauler** (shoot it to 0): the cargo is seized. Supplies go up for Ward. The Drovers record a loss, and the local agreement is "none: assault".
- **Leave it running:** it drives out at the end of round 7 with the cargo.

## Failure and partial outcomes

- A soldier still on the map at the deadline is recorded as **left behind, wounded**. They're a recovery opportunity later, not confirmed dead. That's the GDD's "wounded personnel for a later recovery".
- Groups not out at the deadline are stranded and stay on the record.
- MSG lost means retry, as always.

## What it records (campaign record, mission 04)

- Each group's fate and the squad's status.
- **The local agreement:**
  - honored
  - breached by the squad
  - breached by the Greys (attributed or unattributed)
  - expired
  - none: assault
- Component returned or kept.
- The drone: observed, shot or ignored.
- Drover security: unharmed, restrained or killed, for each unit.
- Cargo: left with the Drovers, or seized.
- Supplies gained.

## What carries forward

- **Agreement honored, or broken by the Greys and attributed.** Ward designates MSG as field contact for limited Drover agreements (GDD §04). County Hospital (Mission 06) offers the "monitored Drover passage" option. Kesh's first direct contact is recorded.
- **Breached by the squad, or assault.** No field-contact role yet. At Hospital, the Drover convoy contests the road. Restrained Drovers can be returned later as a gesture; killed ones can't.
- **Cargo seized.** Ward gets supplies, and the Drover ark loses a component. That shows up as a repair demand at Quarry (Mission 07).
- **Drone observed.** First verified evidence that the Greys monitor rival factions. It feeds the Rail Yard (Mission 05) records.
- **Component returned.** A returned-goods gesture is on the record; the Drover stewards remember it.

## Build plan

1. `missions/interchange.tres` and `interchange.gd`, extending the encounter controller with the Farm Road machine switched off (the River Bridge pattern).
2. `systems/drover_crew.gd`: hauler, two security units (alert, wary, hostile), the pause state machine and attribution. `systems/grey_drone.gd`: arrival, breach shot, observe and shoot.
3. Suppress and Restrain as squad actions, available from Mission 04 on. Suppress is generic, so later missions get it free.
4. HUD:
   - Map drawing: work zone, overpass, lane, hauler, security units and their aim lines, the drone, containers.
   - New buttons: Transmit pause, Observe, Return component, Suppress, Restrain.
   - The Mission 04 briefing, a priority box, and an Act II opening page.
5. Campaign: Mission 04 playable on the board, a record entry, and carry-forward lines. The carry-ins come from Missions 01–03: ACK-01, platform preserved, component, and sensor.
6. Tests plus a balance sim for each approach (pause, escort, assault). Full suite on the Mac before pushing.
