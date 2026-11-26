# Mission 09 · Civic Center — playable spec (v1 greybox)

Status: APPROVED (Spence, 25 Nov 2026), building v1.

Sources:
- GDD v3.1 §11 Mission 09.
- §05 Reptilians, "The Dominion": the split after their extraction facility fails.
- §20 threat tells: plasma mortar, human disguise.
- §19 captures and intelligence.

All numbers are test values. This is Act III, "The Enemy of My Enemy".

## What the player does

The county civic center is Reptilian-held. The council and a crowd of civilians are inside, and nobody has come out in two days. Under the building is a concealed holding facility. A human convoy is waiting at the east gate to take the council out, if the council can reach it.

The GDD's tools for this mission are reconnaissance, alternate access, cover destruction and a withdrawal trigger.

Objectives:
1. **Get the people out.** Three groups (12 people):
   - A: the council, in the chambers.
   - B: civilians in the atrium.
   - C: detainees in the holding facility.
2. **Get the squad out.** MSG must get out.
3. **Choose:**
   - **Infiltration records.** Download them from the chambers terminal.
   - **Free the detainees.** Reach the hidden holding facility.
   - **Protect the departing convoy.** Keep the mortar off it when it leaves.

   You can't do all three well.

Deadline: the center is lost after round 10.

## Map (20 × 16, a civic center)

- **The main building** sits in the middle. The chambers are in the north wing, the atrium in the middle, and there's a lobby facing south.
- **The main entrance** is south. It's covered, which means trooper fire.
- **The service corridor** runs along the west side. That's the alternate access. Its door is locked: 1 AP to force it, or the Hospital files give you the code.
- **The holding facility** is under the east wing. Its entrance is concealed. Recon reveals it, or the Hospital files do. Group C is penned inside, and the Rail Yard lock rules apply: Bell bypasses, anyone can cut.
- **The east gate** has the human convoy, plus the CIVILIAN EXIT and the squad's exits.
- **The Reptilian mortar** is on the roof of the north-east annex.

## Reconnaissance (new: Scout)

- **Hidden troopers.** Reptilian troopers inside the building are hidden until a soldier is within 3 squares, or they're scouted.
- **Scout** (Park, 1 AP). It reveals every Reptilian within 6 squares of him, and the concealed facility entrance if it's within 6.
- **Last-known markers** persist where something was seen (GDD §12: last-known, not live tracking).

## The withdrawal trigger (the Reptilian split, made playable)

The **alarm** goes off at the start of round 5, or earlier if any of these happen first:
- a shot is fired inside the building;
- the facility pen is opened;
- the chambers terminal is touched.

When the alarm sounds, the Reptilians split. The split is announced and shown on the map:
- **Extraction faction** (2 troopers). They go for the holding facility and start moving detainees out through a tunnel. One loading step every 2 rounds, like the Grey Collector. Hit a trooper to stop a step.
- **Territorial faction** (2 troopers). They entrench in the atrium and the main entrance. They hold their squares, fire on soldiers within 5, and **destroy cover**: each round they shoot one low-cover edge in sight off the map.

Before the alarm, troopers patrol and take no shots. They'll still grab a group that's left next to them (the Hospital rule).

## Plasma mortar (cover destruction and the convoy)

- **The mark.** Each Reptilian phase after the alarm, the mortar marks a 3×3 impact a phase ahead, in orange.
- **The impact.** 4 damage to anyone inside, and every cover edge in the area is destroyed.
- **The convoy.** When the convoy leaves (end of round 6, or as soon as group A is aboard), the mortar targets it. Each impact on it costs one vehicle out of three.
- **Silencing it.** Kill the spotter on the annex roof (6 HP, reached up the annex stairs), or keep a Nordic shield on the convoy if Aven still has a charge.

## Carry-ins

- **Hospital infiltrator contained.** The harvest files give the service door code and the facility entrance's location. Both are known from the start.
- **The infiltrator reached the base.** Your own movements leaked. The alarm comes at the start of round 3, not round 5.
- **Hospital groups taken by the Reptilians** are among the detainees. They're named in group C, and freeing them closes that thread.
- **Airfield contact made, and a charge left.** Aven can shield the convoy once.
- **Squad** from the latest record.

## What it records (campaign record, mission 09)

- Each group's fate.
- Records: downloaded or not. If downloaded, the record shows the old network and the Reptilian split.
- Detainees: freed, moved out, or left.
- Convoy: vehicles left out of 3.
- Alarm: the round it went off, and what set it off.
- Troopers down by faction.
- Squad status.

## What carries forward

- **Records recovered.** The old infiltration network is exposed and institutions are purged. Ward's credibility goes up, and that helps the ark parley's human representatives.
- **Records lost.** Surviving institutions are weaker (the GDD's partial failure): fewer human seats at the parley.
- **Council out, convoy intact.** Civilian leadership survives. Human representatives approve the evacuation terms at the ark.
- **Detainees freed.** Named and safe. If the extraction faction moved them out, they're named and unresolved.
- **The Nordic genetic evidence is not here.** It stays as an optional post-parley scene, per the GDD.

## Build plan

1. `missions/civic_center.tres` and `civic_center.gd`, extending the encounter controller with the Farm Road machine off.
2. Systems:
   - `systems/reptilian_garrison.gd`: hidden or revealed troopers, patrol, the alarm and its triggers, the faction split, entrenchment and cover destruction, extraction steps.
   - `systems/plasma_mortar.gd`: mark, impact, cover destruction, convoy targeting, spotter.
   - Reuse the pen locks, the Rail Yard archive download pattern and the Nordic shield.
3. Squad actions: Scout, Force service door, Download records, Bypass and Cut pen, Board convoy.
4. HUD:
   - Map drawing: hidden and last-known markers, faction tags, mortar marks, convoy.
   - New buttons.
   - Briefing, priority box.
5. Campaign: Mission 09 playable on the board, a record entry, carry-ins from Missions 06 and 08, carry-forward.
6. Tests and a balance sim for each priority. Full suite on the Mac before pushing.
