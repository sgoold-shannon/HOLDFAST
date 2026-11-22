extends RefCounted
## Grey reconnaissance drone (Interchange). GDD v3.1 §10: a second operational pattern.
## It watches the Drover crew and, in round 4, fires on the hauler to start a fight between
## Drovers and humans. Observed first, the Drovers see who did it. State: board.drone.
const ARRIVE_ROUND := 1       # appears during this round's Grey phase (on the map from round 2)
const BREACH_ROUND := 4
const LEAVE_ROUND := 6        # gone after this round's Grey phase if still flying
const HP := 4
const MOVE := 3
const SUPPRESSED_MOVE := 2
const SHOT_RANGE := 6
const HAULER_DAMAGE := 4
const SPOT_RANGE := 8         # shown when a soldier is this close (or always, with the sensor)
const NONE := Vector2i(-1,-1)
const DroverCrew = preload("res://systems/drover_crew.gd")
const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.LEFT, Vector2i.DOWN, Vector2i.RIGHT]

static func initial(entry: Vector2i, revealed: bool) -> Dictionary:
	return {"stage":"waiting","cell":entry,"hp":HP,"observed":false,"revealed":revealed,
		"fired":false,"attributed":false,"suppressed_by":-1,"outcome":"ignored","log":[]}

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func flying(drone: Dictionary) -> bool:
	return drone["stage"] == "active" and drone["hp"] > 0

static func visible(drone: Dictionary, board) -> bool:
	if not flying(drone): return false
	if drone["revealed"] or drone["observed"]: return true
	for index in range(board.soldiers.size()):
		if board.soldier_can_act(index) and distance(board.soldiers[index]["cell"],drone["cell"]) <= SPOT_RANGE: return true
	return false

static func observe(drone: Dictionary) -> String:
	drone["observed"] = true
	if drone["outcome"] == "ignored": drone["outcome"] = "observed"
	drone["log"].append("observed")
	return "Drone observed and logged: Grey reconnaissance, watching the Drover crew, not you. Anyone who sees what it does now will know whose it was."

static func take_hit(drone: Dictionary, damage: int, by: String) -> String:
	drone["hp"] = maxi(0,drone["hp"]-damage)
	if drone["hp"] > 0: return "Drone hit (%d HP left)." % drone["hp"]
	drone["stage"] = "down"
	drone["outcome"] = "shot_after" if drone["fired"] else "shot"
	if by == "drovers": drone["outcome"] = "downed_by_drovers"
	drone["log"].append("down:%s" % by)
	return "The drone drops onto the asphalt in pieces."

## The Grey phase. Returns a line for the enemy message.
static func act(drone: Dictionary, crew: Dictionary, board) -> String:
	var phase: int = board.phase
	if drone["stage"] == "waiting":
		if phase < ARRIVE_ROUND: return ""
		drone["stage"] = "active"
		return "Something small and grey lifts over the frontage road to the south-east." if visible(drone,board) else ""
	if not flying(drone): return ""
	var hauler: Vector2i = crew["hauler"]["cell"]
	var line := ""
	if not drone["fired"] and phase >= BREACH_ROUND and DroverCrew.hauler_running(crew) and distance(drone["cell"],hauler) <= SHOT_RANGE:
		drone["fired"] = true
		drone["attributed"] = drone["observed"]
		crew["hauler"]["hp"] = maxi(0,crew["hauler"]["hp"]-HAULER_DAMAGE)
		drone["log"].append("fired:%d" % phase)
		if drone["attributed"]:
			crew["log"].append("grey_breach_attributed")
			line = "The drone fires on the hauler. Drover security saw where it came from: they turn on the drone, not on you."
		else:
			crew["log"].append("grey_breach_unattributed")
			var reaction := DroverCrew.provoke(crew,phase,"greys",DroverCrew.BLAME_ROUNDS)
			line = "Something fires on the hauler from the south. The Drovers think it was you. " + reaction
		return line.strip_edges()
	if phase >= LEAVE_ROUND:
		drone["stage"] = "gone"
		return "The drone climbs out of sight to the south." if visible(drone,board) else ""
	# Close on the hauler, keeping out of the squad's way.
	var budget := SUPPRESSED_MOVE if drone["suppressed_by"] >= 0 else MOVE
	for step in range(budget):
		if distance(drone["cell"],hauler) <= SHOT_RANGE-1: break
		var next: Vector2i = drone["cell"]
		for direction in DIRECTIONS:
			var candidate: Vector2i = drone["cell"]+direction
			if not board.cell_is_in_bounds(candidate) or board.WALL_CELLS.has(candidate): continue
			if board.soldier_at(candidate) >= 0 or board.cohort_at(candidate) >= 0 or board.target_at(candidate) >= 0: continue
			if distance(candidate,hauler) < distance(next,hauler): next = candidate
		if next == drone["cell"]: break
		drone["cell"] = next
	return ""
