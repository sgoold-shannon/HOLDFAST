# Mission 05 · Rail Yard — playable spec (v1 greybox)

Status: APPROVED (Spence, 24 Nov 2026), building v1. Sources:
- GDD v3.1 §10 Mission 05.
- §05 Greys: "The Observers".
- §20 threat tells: beam fire, abduction, blackout.
- §19 captures and intelligence.
- §26 Grey doctrine: bargains state object, time and route.

All numbers are test values.

## What the player does

A Grey extraction site has taken over the county rail yard. People are held in three field pens. A landed transport sits at the east end on a visible departure schedule. A Grey archive terminal and a loaded freight handcar sit between them. The squad can't save people, evidence and supplies all at once, and the Greys don't care which one they lose as long as the shipment leaves on time.

Objectives:
1. **Free the captives.** Release the three pens (12 people) and get them out of the west YARD EXIT.
2. **Get the squad out.** MSG must get out.
3. Optional: **recover the archive** (evidence) and/or **roll the handcar out** (heavy supplies).

Deadlines:
- The transport lifts off at the end of round 8, taking whoever is aboard.
- The yard is unsafe after round 10.

## Carry-ins

- **River Bridge groups taken by the Greys are here.** They're named and in the pens, and they keep their River Bridge manifest. The other pens hold rail workers and townspeople taken elsewhere, so there are always 3 groups.
- **The Interchange drone was observed or shot down.** Bell recognizes the Grey data format, so the archive download takes 1 step instead of 2.

## Map (20 × 16, a rail yard)

- Four tracks run west to east. Boxcars on them are full walls, with gaps for crossing.
- **Pens** (field-locked enclosures) sit in the middle of the yard at about (8,4), (9,9) and (8,13).
- **Transport** at the east end (17–18, 7–9). Its loading ramp is at (16,8).
- **Archive terminal** at (14,4), close to the transport.
- **Handcar** on the middle track at (12,11), loaded with generator cells. Its track runs west to the yard exit.
- The squad starts at the west edge (column 2). The YARD EXIT is on the west edge, column 1 or 2, rows 6–10. Groups leave the way the squad came in.

## The Grey team (River Bridge rules plus two new tells)

- **Collector** (8 HP).
  - It **loads** one pen every 2 rounds, starting in round 3.
  - It walks a group from its pen to the transport ramp, and that group is aboard.
  - Hitting the Collector while it's loading breaks that load. The group stays in its pen.
- **Two Sentries** (6 HP).
  - Each has a beam that aims a turn ahead, the same as at River Bridge: move off the red line.
  - They're passive until provoked. Provoking means shooting a Grey, opening a pen, touching the terminal, or a soldier within 3 of the transport.
- **Disruptor** (6 HP, stays near the transport).
  - Each Grey phase it **marks a blackout area** (3×3) in violet. That area goes dark the following round.
  - Inside a blackout:
    - No Observe, Transmit or Download.
    - MSG's voice reaches only adjacent groups (no radio).
    - Electronic pen locks can't be bypassed.
  - Killing it ends blackouts.

## Freeing a pen

Two ways:
- **Bypass the lock.** Bell, 1 AP, adjacent, not in a blackout.
- **Cut it open.** Bolt cutters: any soldier, 2 AP across one or two turns, adjacent. This works in a blackout. It's the manual-equipment counter.

Freed groups start SHAKEN. Normal command and panic rules apply.

## Archive

- **Download** at the terminal. A soldier adjacent spends 1 AP per step, with 2 steps (or 1 with the Interchange carry-in). It doesn't work in a blackout.
- **Full archive:** Grey resource accounting, plus rival-faction monitoring files. That's the evidence that the Greys watch Drovers, Reptilians and humans alike.

## Handcar (heavy supplies)

- A soldier adjacent releases the brake (1 AP, manual, works in a blackout).
- It rolls west 3 squares a round along its track and leaves through the yard exit.
- Anything on the track stops it: a soldier, a group or a Grey. It isn't hurt; it waits.

## Optional trade

The Grey commander opens a channel once, at the start of round 2.

- **The offer.** "Survey records for clearance: leave the transport and its ramp alone for 3 rounds, and you receive the archive's survey section."
- **If accepted** (MSG, 1 AP, not in a blackout):
  - The squad gets a **partial archive**: geology and resource surveys, harmless.
  - The Sentries hold fire for 3 rounds.
  - Any soldier within 3 of the transport, or any shot at a Grey, breaks it. The record names who broke it.
- **What the trade doesn't do.** It doesn't stop loading. The people in the pens are not part of it, and nobody can consent for them. Accepting is legal, and so is ignoring it. The debrief says plainly what the trade did and didn't cover.

## Outcomes and record (campaign record, mission 05)

- Each group: freed, still in a pen, or aboard the transport (custody).
- Archive: full, partial (trade) or none.
- Handcar: recovered or left.
- Trade: none, honored, or broken (with who broke it).
- Greys killed: Collector, Sentries, Disruptor.
- Squad status.

## What carries forward

- **Groups aboard the transport** stay in Grey custody, named. The record changes rescue options at the Regional Airfield (Mission 08) instead of erasing them.
- **Full archive:** first proof that the Greys monitor every faction. Ward accepts the "separate threats" assessment for Act II. It also opens the Grey intel line at the Airfield.
- **Partial archive** has the surveys only. It's useful for Quarry (Mission 07) planning, with no faction evidence.
- **Handcar supplies** give the base generator cells: one extra powered system at County Hospital (Mission 06).
- **Freed River Bridge groups** close that thread on the record. Ortiz has a line: "We have their names, and now we have them."

## Build plan

1. `missions/rail_yard.tres` and `rail_yard.gd`, extending the encounter controller with the Farm Road machine off (the River Bridge pattern). The civilian groups start inside pens with their orders locked.
2. `systems/grey_yard.gd`:
   - Collector loading on a schedule.
   - Sentry beams, reusing River Bridge's aim-and-fire.
   - The Disruptor blackout (mark, then go dark).
   - The transport clock.
   - The trade.
3. Squad actions: Bypass lock, Cut lock, Download, Release brake, Accept trade.
4. HUD:
   - Map drawing: tracks, boxcars, pens, transport, terminal, handcar, blackout marks, beams.
   - The new buttons.
   - The Mission 05 briefing and a priority box.
5. Campaign: Mission 05 playable on the board, a record entry, carry-in and carry-forward lines.
6. Tests and a balance sim for each priority: people, archive, supplies, trade. Full suite on the Mac before pushing.
