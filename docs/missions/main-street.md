# Mission 03 · Main Street — playable spec (v1 greybox)

Status: APPROVED and built (v1 greybox, 2026-11-19). Sources: GDD v3.1 §09 Mission 03, §06 Fallow, §20 threat tells (gravity effect, coordination link), §28 contracts, §13 tactical rules. All numbers are test values. Act I's major tactical encounter, and the first time the player sees the Fallow.

## What the player does

A large Drover recovery platform rolls down Main Street toward the town substation while the town evacuates. Authorities call it an assault engine; up close, it's maintenance equipment with a specific job. Midway through, something new arrives: a small Fallow cutter that marks a strip of ground and transforms it the next turn. The team can't hold the town. They save who they can and get out by a different route than the one they planned.

Objectives:
1. **Evacuate the town:** three civilian groups (12 people) to the east CIVILIAN EXIT. Same command and panic rules as before.
2. **Stop dangerous platform movement** before it reaches the substation.
3. **Get the squad out.** MSG must get out.

Deadline: the corridor closes after round 9. If the platform reaches the substation, the power fails and it closes two rounds after that.

## Map (20 × 16, a small town) — as built

- Main Street runs west to east along rows 6–10, between two rows of shopfronts (walls on rows 5 and 11, with gaps at columns 6 and 12/13). Civilian route "south": via (15,8).
- North alley along rows 1–4, behind the shops. The way round. Civilian route "north": via (15,3).
- Squad starts west (column 2). Groups start at (4,7), (4,9) and (5,13). CIVILIAN EXIT (19,8); squad EXIT squares column 19, rows 6–10.
- Platform starts at (8,8) and grinds east, then drops south to the substation at (11,10) (drawn on the south shopfront at 11–12, 11). Junction box JB (breaker) at (14,10). Control panel CP (console) at (7,6).
- Redirect route: (12,6) → through the gap at (12,5) → (12,4) → parks at (13,3) across the alley.
- Fallow entry (17,2), coordination node (18,2). Drover security starts at (8,7), walking beside the platform.

## The platform (Farm Road's machine rules, bigger)

24 HP. It moves along Main Street toward the substation, and its path crushes anything in it. The three choices from the GDD map onto tools the player already knows from Farm Road:

- **Demolish** (shoot it to 0 HP). Opens the fast route: the wreck clears off Main Street. A defensible rescue choice, but nothing is preserved.
- **Isolate** at the junction box (Breaker, two steps). It stops where it is, before the crossing, so Main Street's crossing stays usable. Intact, inert, preserved.
- **Redirect** through the control panel (Observe → Transmit → Authenticate → Divert). It turns into the north alley and parks across it as a barrier, sheltering a slower evacuation. Civilians next to the parked platform are safe from the Fallow transformation and don't panic from it. Costs the most time and exposure.

Once redirected, the platform's maintenance purpose becomes explicit: the debrief reads its work order.

## The Fallow cutter (first Fallow contact)

- **Signaled entry.** End of round 3: a distortion appears at the north-east entry (17,2), shown on the map. Start of round 4: the cutter steps in, with a coordination node anchored at the entry. No invisible spawns.
- **Mark → transform.** Each Fallow phase, the cutter first transforms the strip it marked last time, then marks a new strip.
  - **Transform:** the marked squares become rift ground, impassable for the rest of the mission. Anyone still standing there takes 4 damage and is thrown to the nearest open square.
  - **Mark:** a straight line of 4 squares (2 without the node) across the path of the group nearest the exit, two columns ahead of it. It's shown in violet a full turn before it transforms.
  - **Move:** the cutter moves 2 toward the civilians.
- **Coordination node (the coordination-link tell).** It strengthens the cutter, which marks 4 squares instead of 2. A soldier adjacent spends 1 AP to **Interrupt** it, or any hit on it does the same. The cutter skips its next transform, which buys one turn. The node can't be destroyed: the team can't hold the whole area.
- **Counterplay.**
  - Get off marked squares.
  - Keep groups moving or route them away.
  - Interrupt the node to buy a turn.
  - Kill the cutter (12 HP, readable but tough). Killing it stops new marks. Rifts already formed stay.
- **No motive revealed.** The debrief states what was observed, never why.

Fallow units and marked strips count as threats for civilian panic.

## Drover security (reliable behavior, not a fight)

A Drover security unit walks beside the platform. In v1 it can't be targeted (it's guarding its people, not fighting yours); the shot-and-push-back behaviour comes later. When the cutter arrives, it abandons a valuable component at its feet to shield its own dependents, and leaves. A soldier adjacent spends 1 AP to **Recover** the component. That's evidence, and leverage at Interchange (Mission 04).

## Withdrawal

The cutter's strips will cut Main Street. The intended story beat is that the planned fast corridor fails and the player re-routes groups up the north alley, unless they demolished the platform early and pushed through fast. Both are valid.

## What it records (campaign record, mission 03)

Each group's fate, the platform's fate (demolished / isolated / redirected / reached the substation), whether the component was recovered, rift squares formed, node interruptions, whether the cutter died, and squad status.

## What carries forward

- **Platform preserved** (isolated or redirected): Drovers remember. Better footing at Interchange (Mission 04); the GDD's Quarry rig logic applies.
- **Component recovered:** a bargaining item, or a returned-goods gesture, at Interchange.
- **Act I exit:** with Main Street done, the squad formally rejects the single-command hypothesis. Ward accepts the local assessment and asks for independent corroboration. The debrief closes Act I and the Operations board marks Act I complete. Its strength is shown by evidence count: ACK-01, sensor, witnesses, work order, component.
- **Fallow:** learnable tactics recorded (mark → transform, node interrupt). The board adds "a new threat transforms ground; it does not negotiate" to what the task force knows.

## Build plan

1. `missions/main_street.tres` plus `main_street.gd`, extending the encounter controller with the Farm Road machine, breaker and console reused on the new map.
2. `systems/fallow_cutter.gd` (entry, mark/transform, node, rifts) and the Drover security unit.
3. HUD: draw street, alley, substation, rifts, marked strips, cutter, node, Drover unit and component. Add Interrupt node and Recover component buttons, a Main Street briefing, and an Act I closing page in the debrief.
4. Campaign: Mission 03 playable on the board, record entry, carry-forward lines, Act I complete.
5. Tests plus balance sims; full suite on the Mac before each push.
