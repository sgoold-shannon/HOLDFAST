# Mission 06 · County Hospital — playable spec (v1 greybox)

Status: APPROVED (Spence, 24 Nov 2026), building v1.

Sources:
- GDD v3.1 §10 Mission 06.
- §05 Reptilians: "The Dominion".
- §14 fire team contract.
- §20 threat tells: human disguise, sonic attack.
- §20 encounter rules: screening must never mean shooting refugees.
- §26 Reptilian doctrine: two corroborating discrepancies and a nonlethal containment path.

All numbers are test values.

## What the player does

County Hospital is evacuating through one road east. Most patients can walk. A ward of critical patients can't. The hospital has power for one system, and the ambulance needs it. Someone inside the hospital isn't who their badge says. North of the fence, a Reptilian team is waiting for the perimeter to open. Halfway through, a Drover convoy wants the same road.

Objectives:
1. **Evacuate the hospital.** Get three groups (12 people) to the east EXIT:
   - A: mobile evacuees.
   - B: staff.
   - C: critical patients on gurneys. They move 1 square a turn on foot.
2. **Get the squad out.** MSG must get out.
3. Optional: **find the infiltrator** before they act, and contain them alive.

Deadline: the perimeter collapses after round 10.

## Power (where the carry-ins land)

The hospital can power a set number of systems. MSG assigns power at the generator room (1 AP), and can reassign it later for another 1 AP.

- **The base is 1 system.**
- **+1** if the Rail Yard handcar was recovered (generator cells).
- **+1** if the Drover convoy's coupling is spliced in. That happens after a monitored passage (see below).

Systems:
- **Ambulance charger.** Without it, the ambulance doesn't run.
- **Triage scanner.** A third kind of screening evidence.
- **Fence lights.** The Reptilian breach team is shown from the moment it's at the fence, not only when a soldier sees it.

## The ambulance (dividing transport)

- It carries **one group per trip** from the bay at (5,8) to the exit. A soldier at the bay spends 1 AP to load the group.
- A trip takes 2 rounds out and 2 back. Realistically that's two trips before the deadline.
- So: **critical patients by ambulance** (C can't walk out in time), or **mobile groups by ambulance** while soldiers protect C's slow walk. That's the GDD's "divide transport".

## Screening (evidence, not appearance)

Each group has one **person of interest**, named in the panel. All three look ordinary. One of them is the Reptilian infiltrator; the other two are not. Where the infiltrator is varies by campaign seed. The evidence types are:

- **Credentials.** A soldier at the triage checkpoint (12,8) checks a person in an adjacent group (1 AP). The result: consistent, or a discrepancy. A discrepancy can be innocent, like a lost badge or a temp contract.
- **Witnessed behavior.** In round 3 the infiltrator slips off to the fence gate. If any soldier has sight of the gate that round, the act is witnessed and recorded. It's a discrepancy for that person.
- **Scanner** (only if powered). A reading at the checkpoint. It's an anomaly for the infiltrator, and clean for everyone else.

Two corroborating discrepancies make a person **confirmed**. Then:
- **Contain** (1 AP, adjacent). Nonlethal. The infiltrator is held. That exposes one network: Reptilian logistics files that treat people as harvestable stock.
- **Detain on thin evidence** (one discrepancy or none) is allowed.
  - If you were right, it's recorded as "detained on thin evidence".
  - If you were wrong, it's a **false detention**. The group panics, the person's name goes on the record, and the debrief says it plainly.

There's no shooting into groups. Suspicion never makes anyone a target.

## The Reptilian breach

- If the infiltrator isn't contained by round 3, they open the north fence gate, and the **breach team arrives at the start of round 5**. If they're contained first, the team has to cut its way in and arrives in round 7.
- **Two Reptilian troopers**: 10 HP, armored, shots against them deal 3.
  - They go for civilians, slowest first. An adjacent group at the end of their phase is **taken**: Reptilian harvest, named and on the record.
  - They don't bother with soldiers unless a soldier is in the way.
- **Sonic attack.** Once a round, a trooper marks a cone 4 squares long and 3 wide, a turn ahead.
  - Soldiers inside start their next turn with 1 less AP.
  - Groups inside panic.
  - The counter is to spread out and step out of the cone.
- **An undetected infiltrator who walks out with their group** reaches the base. That's recorded and changes who's present at the base later.

## The Drover convoy

- It arrives at the east end in round 4 and needs the road (row 8) for rounds 5–6.
- **With Interchange field contact** (an honored agreement), MSG chooses:
  - **Monitored passage** (1 AP, MSG within 6 of the convoy). It passes in rounds 5–6 while a soldier watches. The road is closed to everyone for those two rounds. Afterwards they splice their coupling into the hospital: **+1 power system**.
  - **Reserve the road for humans.** The convoy waits and diverts. No coupling. The record notes the refusal; Kesh notes it too.
- **Without field contact**, the convoy comes through in rounds 5–6 regardless. It's contested. Anyone on the road is shoved aside (2 damage, thrown clear). No coupling.

## The supporting fire team (first one)

- **Guard Team Marsh**: four named Guard soldiers, sharing one order. They start at the ambulance bay.
- **Orders.** One free order update per turn, resolved in the allied phase:
  - **Hold** a chosen square: they engage within 6.
  - **Protect** a chosen group: they follow at 1 square and engage within 6.
  - **Withdraw** to the exit and leave.
- **Fire.** Two shots per allied phase at Reptilians in sight within 6: 65% each, 3 damage against armor.
- **Casualties.** Damage hits individual members. Each casualty is recorded by name, even though the team takes one order.
- An order to a square that's unsafe or unreachable shows a warning. The team stops when blocked; it never makes a suicidal detour.

## What it records (campaign record, mission 06)

- Each group's fate: out, stranded, or taken by the Reptilians.
- Transport split: which groups rode the ambulance.
- Power assignment and sources.
- The infiltrator: contained (confirmed / thin evidence), escaped to the base, or still in the hospital.
- False detentions, by name.
- Convoy: monitored passage, reserved, or contested.
- Guard Team Marsh casualties by name.
- Squad status.

## What carries forward

- **Contained infiltrator.** The logistics files show people treated as harvestable. That's the independent, unequivocal Reptilian threat. It opens the Civic Center (Mission 09) network.
- **Infiltrator reached the base.** Later base scenes and the Civic Center briefing change.
- **Critical patients out.** Medical capacity holds at the base. If they were lost or taken, it degrades.
- **Monitored passage.** The Drover stewards remember a kept route; it counts toward Quarry (Mission 07). **Reserved:** a recorded refusal. **Contested:** a grievance.
- **Guard Team Marsh survivors** are available as a supporting team later. Its dead stay dead.

## Build plan

1. `missions/county_hospital.tres` and `county_hospital.gd`, extending the encounter controller with the Farm Road machine off.
2. Systems:
   - `systems/hospital_power.gd`: power budget, assignment, ambulance.
   - `systems/screening.gd`: persons of interest, evidence, confirm, contain, detain, false detention.
   - `systems/reptilian_team.gd`: breach timing, troopers, sonic cone, harvest.
   - `systems/drover_convoy.gd`: passage, reserve, contested.
   - `systems/fire_team.gd`: orders, fire, individual casualties.
3. HUD:
   - Map drawing.
   - A power panel and a screening panel (persons of interest and their evidence).
   - Fire team order buttons, convoy choice buttons, load-ambulance.
   - Briefing and priority box.
4. Campaign: Mission 06 playable on the board, a record entry, carry-ins (Rail Yard supplies, Interchange field contact) and carry-forward.
5. Tests and balance sims: ambulance for C vs. ambulance for A/B, infiltrator caught early vs. late, each convoy option. Full suite on the Mac before pushing.
