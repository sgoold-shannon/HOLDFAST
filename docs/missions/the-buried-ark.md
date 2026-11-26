# Mission 11 · The Buried Ark — playable spec (v1 greybox)

Status: APPROVED (Spence, 26 Nov 2026), built as v1. Tuning changes from the first sims are under "v1 tuning" at the end.

Sources:
- GDD v3.1 §11 Mission 11, and the Act III exit.
- §07: Kesh, Ilen and the nursery habitat.
- §21: the ark negotiation and its terms.
- §27: the ark reveal (core, primary power link, reserve battery and connector, life support, boarding tunnel).
- §28: Drover behavior.

All numbers are test values. This is the close of Act III, "The Enemy of My Enemy".

## What the player does

The squad comes down the old service spur into the cavern under the ridge. The cavern holds the ark. It's still a vessel, grown over with habitat. In the sanctuary at its heart, a parley is meant to happen between three parties:
- human representatives (Ward's people, plus the council if it survived the Civic Center);
- the ark stewards (Kesh among them);
- Custodian Aven, if the Airfield made contact.

The Warden guards the gallery between the spur and the sanctuary. It's an ancient defensive system, and it doesn't know you. In round 4 a Fallow incursion breaks into the cavern and the meeting fractures.

Objectives:
1. **Reach the sanctuary.** Get MSG past the Warden into the sanctuary. Bypassing it, disabling it and negotiating with it all count.
2. **Hold the parley.** Build **terms** while MSG is at the table. The final agreement depends on them. Some agreement always exists; the GDD's narrow survival bargain is the floor.
3. **When the incursion hits, choose what to protect.** Pick among three things, all of which can be saved but rarely all at once:
   - **the delegates**, at the parley table;
   - **life support**, the plant on the west side;
   - **the nursery**, east, near where the rift opens. This is Kesh's apprentice Ilen and the habitat's children.
4. Optional: **inspect the reserve battery connector.** This is Bell's job. It sets up the reserve power path for later.
5. **Get the squad out.** MSG must get out, back up the spur.

Deadline: after round 12, the stewards seal the sanctuary.

## The Warden (bypass, disable, or negotiate)

The Warden is a fixed emplacement in the gallery. It is **not a boss to kill to unlock the truth**.

How it fights:
- It watches a cone of 3 rows in front of it.
- Each Warden phase it **marks** the squares a soldier in that cone is standing on.
- Next phase it fires on those squares: 4 damage to anyone still there.
- So it works like Reptilian aim lines: you see the danger a turn ahead and can step off.

Ways through:

| Approach | How | What it leaves |
|---|---|---|
| **Bypass** | Take the maintenance crawl along the west wall. It's longer (about 2 more rounds), and outside the cone. | Warden still hostile in the gallery, but intact. |
| **Disable** | Bell at its power coupling, 2 AP steps. | Warden **damaged**. Defenses need replacement later; no Warden at boarding. |
| **Negotiate** | MSG at the Warden console, 1 AP. Needs **authenticated control**: either ark trunk power 2 from the Dam, or Kesh's authenticated channel and trunk power of at least 1. | Warden **preserved and allied**. After the incursion it marks and fires on Fallow units instead. Later, it can protect boarding. |
| **Destroy** | Shoot it. It has 16 HP and is armored (half damage unless flanked from the crawl). | Warden **destroyed**. This is the GDD's continuity case: still a viable path, at a cost. |

With ark trunk power at 0, the console is dark, so negotiation is impossible and the lift doesn't run. With power 2, the lift runs too, and the squad starts two rows further in.

## The parley (terms)

- **The table** is in the sanctuary, with three delegate seats: human, steward, and Nordic if Aven came. Those delegates are cohort D, 4 people: the human representative(s), two stewards and Aven, or a third steward if there's no Aven.
- **Each round the parley sits, terms go up by 1.** It sits when MSG is within 2 squares of the table and no Fallow unit or mark is within 3 squares of it.
- **Bonuses** for this round: +1 if Kesh is at the table, which she is unless the Quarry habitat was lost and the Dam left her families unstabilized. +1 more if Aven is there (Nordic contact made).
- **Starting terms come from the campaign:**
  - +2: Dam habitat stabilized (the stewards accept Kesh's terms).
  - +1: Dam cargo delivered (at least 1 crate).
  - +1: Civic Center records recovered (Ward's credibility).
  - +1: Interchange agreement held, the corridor deal from Mission 04.
  - −1: Dam breached, or the habitat abandoned.
- **The agreement at the end:**

  | Terms | Agreement |
  |---|---|
  | 0–7 | **Narrow** |
  | 8–14 | **Working** |
  | 15+ | **Generous** |

  Generous terms only count if **life support is intact**. The GDD rule is that a generous bargain adds berths only when life support can carry them. Otherwise it's recorded as Working.

## The incursion (round 4)

At the start of round 4 a rift tears open on the east wall, next to the nursery:
- **A Fallow cutter and node come through.** It's the Main Street rule: interrupt the node, or kill the cutter (12 HP).
- **The cutter marks two things alternately.** One round it marks toward the parley table, the next toward the life-support plant. A marked square folds into rift the phase after (4 damage; 2 to groups).
- **Life support.** The plant has 3 integrity. Each fold that touches it costs 1, and at 0 it's lost.
- **The nursery** is group N (4: Ilen and the children). It's **penned** in the nursery until a soldier reaches it and opens the door (1 AP). Then it can be ordered back to the spur exit like any group. Groups left near the rift take fold damage.
- **The delegates** (group D) leave the table when the rift opens. They scatter toward the sanctuary shelter alcove unless ordered. While they're away the parley doesn't sit. **Order them back to the table** once the Fallow are driven off and the parley resumes.
- **A second strip.** If the cutter is still alive at round 7, a second node anchors and its strips lengthen. Same rule as before.
- **No delegate is executed for being picked.** All damage comes from visible marks and folds.

## Carry-ins

- **Ark trunk power (Dam): 0, 1 or 2.** This decides the Warden console and the lift (see above).
- **Dam dependents.** Stabilized: +2 terms. Flooded or left: −1, and Kesh's opening lines are harder.
- **Quarry habitat lost and Dam dependents not stabilized.** Kesh doesn't attend; another steward speaks. There's no Kesh bonus and no authenticated route to the Warden. (This is the GDD's "Kesh absent" continuity case.)
- **Nordic contact (Airfield).** Aven attends: +1 terms per round sat. If the Airfield left a protection charge, Aven can **shield** one 3×3 area for one fold (one use).
- **Civic Center.** Records recovered: +1 starting terms. Council out: the council's representative sits as a named human delegate.
- **Interchange agreement held.** +1 starting terms.
- **The squad** comes from the latest record, the same rule as before.

## The reserve battery (optional)

The reserve battery and its connector sit in a side bay off the gallery (GDD §27). Bell spends 2 AP steps inspecting and seating the connector. If it's inspected, the record notes **reserve connector seated**. That matters at the Substation (Mission 15): the reserve can then support one launch.

## What it records (campaign record, mission 11)

- The agreement: narrow, working or generous, plus the final terms.
- The Warden: allied, intact-hostile, disabled or destroyed.
- Life support integrity, and whether it was lost.
- The fate of the delegates (group D), including named delegates hurt.
- The nursery (group N), Ilen included.
- Whether the reserve connector was seated.
- Whether Kesh and Aven attended.
- The squad.

## What carries forward

- **The agreement** sets Act IV's evacuation terms: berths, boarding time and steward cooperation. Narrow still allows a launch, at higher cost.
- **The Warden.** Allied: it protects boarding in the final mission. Disabled: it needs replacement parts. Destroyed: it's gone, and the boarding defense is weaker.
- **Life support lost** caps how many berths any agreement can open.
- **The nursery saved.** Kesh's personal obligation is fulfilled, and that widens steward trust later.
- **Act III exit.** The debrief establishes that Earth can't be held. Then comes the quiet packing scene from GDD §07: Ortiz asks whether medical records count against personal cargo, and Bell sets down a spare tool. MSG gives one short line, choosing between duty, uncertainty, and the people still in reach. Replacement speakers fill in if Ortiz or Bell were lost. The goal becomes evacuation.

## Build plan

1. **Mission files.** `missions/the_buried_ark.tres` and `the_buried_ark.gd`, extending the encounter controller with the Farm Road machine off. The map:
   - the service spur and lift (south);
   - the gallery and Warden, the maintenance crawl (west wall), the battery bay;
   - the sanctuary (table, shelter alcove);
   - the life-support plant (west) and the nursery (east).
2. **`systems/ark_warden.gd`.** The cone, marking a turn ahead, fire, the console (negotiate), the coupling (disable), armored HP, and the allied mode (it targets Fallow).
3. **`systems/ark_parley.gd`.** Terms, the sitting rule, bonuses, starting terms from the record, and the agreement level.
4. **Reuse.** `systems/fallow_cutter.gd`, with a second-node rule and alternating targets. Penned groups and Aven's shield come from the Airfield/Civic patterns.
5. **HUD.**
   - Buttons: Negotiate (console), Disable Warden, Open nursery, Delegates to table, Aven shield, Seat connector, Interrupt node.
   - The priority box shows terms, the Warden state, and life support.
   - A briefing.
6. **Campaign.** Mission 11 playable on the board, a record entry, carry-ins from Missions 04/07/08/09/10, carry-forward, and the Act III exit scene.
7. **Tests and a balance sim.** Full suite on the Mac before pushing.

## v1 tuning (first sims, 26 Nov 2026)

- **The Warden fires on crossers.** Its cone marks alone did nothing. Movement happens in one action, so a soldier could stop just short of the cone and run through the gallery mouth next turn. Now, crossing the gallery mouth (except by the crawl) draws one shot per soldier per round: 75%, 4 damage. The cone marks still apply to anyone who stops in the cone.
- **The node re-links after an interrupt.** The scripted player interrupted the node every round, which froze the incursion completely. Now the node re-links for a round after each interrupt, so at best every other fold is skipped.
- **A second cutter, and a tougher one.** If the first cutter is dead by round 8, a second one comes through the rift. Ark cutters have 16 HP (Main Street's has 12). Without this, a focused squad killed the cutter in two rounds and then sat the parley untouched for the rest of the mission.
- **Terms thresholds raised.** Working is now 8+ and generous 15+ (were 4+ and 7+). At the old numbers every run ended generous.
- **Deadline moved to round 12 (was 10).** The nursery needs about 8 rounds to walk from its door to the spur. With a round-10 deadline it could never get out.
- **Delegates and keepers.** Both are penned groups, and they're sheltered in the sanctuary when it seals. A third group, the life-support keepers (L), stands at the plant. They make the life-support choice about people as well as equipment.
- **Sim results:**

  | Run | Carry-ins | Terms | Agreement | Nursery |
  |---|---|---|---|---|
  | Crawl only | None | 10 | Working | Lost (opened too late, caught in the Warden's crossfire on the way out) |
  | Bell disables the Warden | +1 | 15 | Generous | Saved |
  | Negotiate | Full: trunk 2, authenticated channel, Aven, +5 terms | 26 | Generous | Saved |

  The scripted player kills each cutter fast with three rifles and steady interrupts, so life support was never touched. A real player splitting attention between the nursery, the table and the Fallow will feel the three-way choice more. That needs a playtest.
