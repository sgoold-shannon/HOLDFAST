# Mission 08 · Regional Airfield — playable spec (v1 greybox)

Status: APPROVED (Spence, 25 Nov 2026), building v1.

Sources:
- GDD v3.1 §11 Mission 08.
- §05 Nordics: "The Architects".
- §26 Nordic doctrine: finite protection charges; exhausted protection forces departure.
- §14 the fire team contract.
- §20 encounter rules: Grey and Fallow units are not interchangeable enemy colors.

All numbers are test values. This is Act III's opener: "The Enemy of My Enemy".

## What the player does

Ward needs the regional airfield. It's the only transport capacity left in the valley, and something is waiting there that might help: a damaged, unidentified craft sits in hangar 2. A Grey crew is stripping the field. A Fallow incursion is coming in from the east along the runway. A supporting team holds the terminal while the squad decides what the airfield is for.

Objectives:
1. **Evacuate the stranded people.** Get three groups (12 people) across the runway and out the north-west ground route.
2. **Make contact.** MSG reaches the craft in hangar 2 before the contact window closes after round 6.
3. Optional, and you can't do all of these:
   - **Preserve the runway and aircraft.** Keep the transport plane's engines from being stripped, and keep rift off the runway.
   - **Retrieve the Nordic sensor data.**

Deadline: the field is lost after round 10. The Greys leave at the end of round 8.

## Visible hostility (multi-faction rules)

Every unit shows its faction and its current stance on its label. One rule of thumb per faction:

| Faction | Behavior |
|---|---|
| **Greys** | Strip assets on a clock, and fire only at whoever interferes with the shipment (River Bridge and Rail Yard rules). |
| **Fallow** | Always hostile to the ground. They mark, then transform. They don't negotiate. |
| **Nordic craft** | Not a combatant. It spends protection when it's asked to. |

They also fight each other where they meet. A Grey Sentry beam and a Fallow cutter don't cooperate. If a cutter marks ground under a Grey, the Greys withdraw from it. Nobody here is the same enemy in a different color.

## Map (20 × 16, an airfield)

- **The runway** runs west to east along rows 7–9. The transport plane is parked mid-runway at (11,8).
- **Hangars.** Hangar 1 at (5–6, 2–3), kept small so the approach to the exit stays open; hangar 2 at (14–16, 2–4) holds the craft.
- **Terminal** in the south middle (9–13, 11–14), door to the runway at (11,10). Groups A, B and C wait there.
- **North-west ground route exit** at (1,4), across the runway. Squad exits are on column 1, rows 2–6. (As built: the first draft put the exit next to the terminal, and everyone was out before anything happened.)
- **Fallow** enter from the east end of the runway (19,8).
- **Greys** land on the apron at (14,12) and work toward the plane.

## The Nordic craft and contact

- **Contact.** MSG adjacent to the craft spends 1 AP. It has to happen by the end of round 6, after which the window closes.
  - The craft's pilot, **Custodian Aven**, speaks in short, careful sentences. She shows her manifest: twelve seats, with a sister craft that never arrived.
  - If the **River Bridge craft spent its shield**, this is that craft. The record links the two: "it covered group X". Verified at last.
- **Protection charges** (a finite asset, used visibly).
  - The craft has **2 charges**, or **1** if it spent one at River Bridge.
  - After contact, MSG can ask for a **shield** over a 3×3 area (1 AP, any distance, needs radio). For one round, nothing in that area can be turned to rift, beamed or taken.
  - Each shield visibly uses a charge. When the charges are gone the craft has to leave: "Exhausted protection forces departure."
- **Sensor data** (optional). A soldier adjacent to the craft downloads it in 2 steps, and only after contact.
  - It's evidence of the incoming Fallow's scale, and of how few rescue ships exist.
  - It's the first hard number behind Act III.

## The Greys (stripping the field)

- A **Collector** (8 HP) strips the transport plane's two engines, one every 2 rounds once it's next to the plane. Hitting it mid-strip breaks that stage. Two Sentries (6 HP, beams) guard it and are passive until provoked.
- **The Grey intel line** opens if the full Rail Yard archive was recovered. MSG can accept a stated bargain once, in round 3:
  - **Object:** "one engine".
  - **Time:** 3 rounds.
  - **Route:** the apron.
  - The Greys hold fire on the people and take only what was stated. It's exact, like the Rail Yard trade.
- **Rail Yard captives.** If groups went aboard the Grey transport at the Rail Yard, they're here in a cargo pod on the apron. They replace group C: open the pod with Bypass or Cut, as at the Rail Yard, and they're named.

## The Fallow (coming down the runway)

- A cutter and node, using the Main Street and Quarry rules. They arrive in round 3 at the east end and mark across the runway and the people's routes.
- **Rift on the runway.** Two or more rift squares on the runway rows ruin the runway for the plane.

## The supporting team

- **Guard Team Marsh** returns with its Hospital survivors. If none survived, it's replaced by a fresh **Guard Team Holt** of four.
- **Orders:** Hold, Protect or Withdraw, with one free order a turn (the Hospital rules). It starts holding the terminal sector.

## What it records (campaign record, mission 08)

- Each group's fate, including any Rail Yard captives freed here.
- Contact made, the River Bridge craft verified, and the charges used.
- Sensor data recovered.
- Aircraft: intact, one engine, or stripped; runway clear or ruined.
- Grey bargain: none, honored, or broken.
- Fallow rifts.
- Team casualties.
- Squad status.

## What carries forward

- **Aircraft intact and runway clear.** Air support is available later at the Mountain Pass and the Valley.
- **Aircraft or runway lost.** The partial-failure path: no air support, but the ground route is always kept.
- **Contact made.** The Nordic line for the ark parley at the Buried Ark (Mission 11). The genetic-intervention evidence stays optional, after the parley.
- **Sensor data.** Ward sees the scale. Act III's turn toward evacuation starts here.
- **Captives freed.** The Rail Yard custody thread closes. Otherwise they stay named and in custody.

## Build plan

1. `missions/regional_airfield.tres` and `regional_airfield.gd`, extending the encounter controller with the Farm Road machine off.
2. Systems:
   - `systems/nordic_craft.gd`: contact window, charges, shield areas, sensor download, departure.
   - `systems/grey_strippers.gd`: Collector strip stages, Sentries, and the bargain.
   - Reuse `systems/fallow_cutter.gd`, `systems/fire_team.gd`, and the Rail Yard pod lock rules.
3. Faction labels and stance on every unit.
4. HUD:
   - Map drawing.
   - Buttons: Contact, Request shield, Download sensors, Accept bargain, and the pod locks.
   - Briefing, priority box, and the Act III opening.
5. Campaign: Mission 08 playable on the board, a record entry, and carry-ins from River Bridge (craft), Rail Yard (archive, captives) and Hospital (team). Carry-forward.
6. Tests and a balance sim for each priority. Full suite on the Mac before pushing.
