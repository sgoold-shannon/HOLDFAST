extends RefCounted
## Drover cargo crew (Interchange). GDD v3.1 §06/§10: armed Drovers recover cargo under
## pressure, retaliate when threatened, never target civilians. The corridor pause is Farm
## Road's bounded-signal test scaled up, and a broken pause always records who broke it.
## State is one plain dictionary on the board (board.crew). Balance numbers live here.
const HAULER_HP := 20
const SECURITY_HP := 10
const SECURITY_RANGE := 8
const SECURITY_DAMAGE := 4
const SECURITY_AIM := 65        # soldiers are 75; sight_preview's chance is shifted by the gap
const SUPPRESSED_AIM := 20
const SECURITY_MOVE := 2
const PROVOKE_RANGE := 2        # a soldier this close to the hauler without a pause provokes them
const ZONE_MIN := Vector2i(9,5)  # the work zone spans the junction, barrier to barrier
const ZONE_MAX := Vector2i(13,11)
const LEAVE_ROUND := 7          # hauler drives out at the end of this round
const PAUSE_ROUNDS := 3
const PAUSE_ROUNDS_GIFT := 5    # when the Main Street component is handed back
const VOICE_RANGE := 6          # MSG to hauler for Observe / Transmit pause
const BLAME_ROUNDS := 2         # an unattributed Grey breach makes them hostile this long
const RESTRAIN_HP := 5
const SHOT_DAMAGE := 4
const NONE := Vector2i(-1,-1)
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]

static func initial(hauler: Vector2i, security: Array, wary: bool) -> Dictionary:
	var units: Array = []
	for cell in security:
		units.append({"cell":cell,"hp":SECURITY_HP,"restrained":false,"suppressed_by":-1,"aim":{}})
	return {"hauler":{"cell":hauler,"hp":HAULER_HP},"units":units,"left":false,
		"stance":"wary" if wary else "alert","warned":false,"hostile_until":-1,
		"pause":{"state":"none","until":-1,"requested":-1,"gift":false},"observed":false,
		"agreement":"none","breach":"","cargo":"loading","provoked_by":"","log":[]}

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func present(crew: Dictionary) -> bool:
	return not crew["left"]

static func hauler_running(crew: Dictionary) -> bool:
	return not crew["left"] and crew["hauler"]["hp"] > 0

static func unit_fighting(entry: Dictionary) -> bool:
	return entry["hp"] > 0 and not entry["restrained"]

static func armed(crew: Dictionary) -> bool:
	if crew["left"]: return false
	for entry in crew["units"]:
		if unit_fighting(entry): return true
	return false

static func pause_active(crew: Dictionary) -> bool:
	return crew["pause"]["state"] == "active"

static func hostile(crew: Dictionary, phase: int) -> bool:
	return armed(crew) and phase <= crew["hostile_until"]

## 0 = hauler, 1.. = security units (index+1). -1 = nothing of theirs there.
static func unit_at(crew: Dictionary, cell: Vector2i) -> int:
	if crew["left"]: return -1
	if crew["hauler"]["cell"] == cell: return 0
	for index in range(crew["units"].size()):
		var entry: Dictionary = crew["units"][index]
		if (entry["hp"] > 0 or entry["restrained"]) and entry["cell"] == cell: return index+1
	return -1

## Inside the armed work zone civilians won't walk unless a pause holds.
static func zone_closed(crew: Dictionary, cell: Vector2i) -> bool:
	if not hauler_running(crew) or not armed(crew) or pause_active(crew): return false
	return in_zone(cell)

static func in_zone(cell: Vector2i) -> bool:
	return cell.x >= ZONE_MIN.x and cell.x <= ZONE_MAX.x and cell.y >= ZONE_MIN.y and cell.y <= ZONE_MAX.y

static func threat_cells(crew: Dictionary, phase: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not hostile(crew,phase): return cells
	for entry in crew["units"]:
		if unit_fighting(entry):
			cells.append(entry["cell"])
			if not entry["aim"].is_empty(): cells.append(entry["aim"]["cell"])
	return cells

## Something made them hostile. A wary crew answers its first provocation with a warning.
static func provoke(crew: Dictionary, phase: int, who: String, rounds: int = 99) -> String:
	if not armed(crew): return ""
	if crew["stance"] == "wary" and not crew["warned"]:
		crew["warned"] = true
		crew["log"].append("warning:%s" % who)
		return "Drover security fires a warning shot into the air and flashes a status lamp: back off."
	var was: bool = hostile(crew,phase)
	crew["hostile_until"] = maxi(crew["hostile_until"],phase+rounds if rounds < 99 else 99)
	if crew["provoked_by"] == "": crew["provoked_by"] = who
	break_pause(crew,who)
	return "" if was else "Drover security turns on the squad."

static func break_pause(crew: Dictionary, who: String) -> void:
	if crew["pause"]["state"] == "active" or crew["pause"]["state"] == "requested":
		crew["pause"]["state"] = "breached"
		crew["breach"] = who
		crew["agreement"] = "breached_" + who
		crew["log"].append("breach:%s" % who)

## MSG asks for a pause. Returns "" when accepted for next Drover phase, or a reason.
static func request_pause(crew: Dictionary, phase: int, acknowledged: bool, gift: bool) -> String:
	if not hauler_running(crew): return "The crew is gone; there's nothing to pause."
	if hostile(crew,phase): return "They're not listening while they're under fire."
	match crew["pause"]["state"]:
		"active": return "The pause is already holding."
		"requested": return "Request already sent. They answer in their phase."
		"breached": return "The pause was broken. They won't take another request today."
	if not acknowledged and not crew["observed"]: return "Without ACK-01 on record, MSG has to Observe the hauler first so the request carries a verified pattern."
	crew["pause"]["state"] = "requested"
	crew["pause"]["requested"] = phase
	crew["pause"]["gift"] = gift
	crew["log"].append("pause_requested:%d" % phase)
	if gift: crew["log"].append("component_returned")
	return ""

static func take_hit(crew: Dictionary, index: int, damage: int, phase: int) -> String:
	var line := ""
	if index == 0:
		var hauler: Dictionary = crew["hauler"]
		hauler["hp"] = maxi(0,hauler["hp"]-damage)
		line = "Hauler hit for %d (%d HP left)." % [damage,hauler["hp"]]
		if hauler["hp"] == 0:
			crew["cargo"] = "seized"
			crew["log"].append("hauler_down")
			line = "Hauler hit for %d and grinds to a stop. The cargo is yours." % damage
	else:
		var entry: Dictionary = crew["units"][index-1]
		entry["hp"] = maxi(0,entry["hp"]-damage)
		line = "Drover security hit for %d (%d HP left)." % [damage,entry["hp"]]
		if entry["hp"] == 0:
			entry["aim"] = {}
			crew["log"].append("security_killed")
			line = "Drover security hit for %d. It goes down and doesn't get up." % damage
	var reaction := provoke(crew,phase,"squad")
	if crew["agreement"] == "none" and crew["pause"]["state"] == "none": crew["agreement"] = "assault"
	return line + ("" if reaction == "" else " " + reaction)

static func restrain(crew: Dictionary, index: int) -> String:
	var entry: Dictionary = crew["units"][index-1]
	entry["restrained"] = true
	entry["aim"] = {}
	entry["suppressed_by"] = -1
	crew["log"].append("security_restrained")
	return "Drover security restrained and held. Alive, unarmed, on record."

## The Drover phase. `board` supplies people, sight, the rng and damage.
static func act(crew: Dictionary, board) -> String:
	if crew["left"]: return ""
	var phase: int = board.phase
	var report: Array[String] = []
	# 1. Answer a pause request.
	if crew["pause"]["state"] == "requested":
		crew["pause"]["state"] = "active"
		crew["pause"]["until"] = phase+(PAUSE_ROUNDS_GIFT if crew["pause"]["gift"] else PAUSE_ROUNDS)
		crew["agreement"] = "active"
		report.append("The hauler's lamp turns green. Security lowers its weapons: corridor pause for %d rounds%s." % [crew["pause"]["until"]-phase," (the returned component bought two more)" if crew["pause"]["gift"] else ""])
	# 2. Squad crowding the hauler.
	if hauler_running(crew) and armed(crew):
		for index in range(board.soldiers.size()):
			if not board.soldier_can_act(index): continue
			var cell: Vector2i = board.soldiers[index]["cell"]
			if distance(cell,crew["hauler"]["cell"]) > PROVOKE_RANGE: continue
			if pause_active(crew) and board.on_lane(cell): continue
			var line := provoke(crew,phase,"squad")
			if line != "": report.append("%s came too close%s. %s" % [board.soldiers[index]["name"]," off the lane" if crew["breach"] == "squad" else "",line])
			break
	# 3. Hostile security fires its aimed shots, then re-aims.
	if hostile(crew,phase):
		for entry in crew["units"]:
			if not unit_fighting(entry): continue
			if not entry["aim"].is_empty(): report.append(fire(entry,board))
			entry["aim"] = {}
			var target := aim_target(entry,board)
			if target < 0:
				step_toward_squad(entry,board)
				target = aim_target(entry,board)
			if target >= 0:
				entry["aim"] = {"cell":board.soldiers[target]["cell"],"soldier":target}
				report.append("Drover security aims at %s." % board.soldiers[target]["name"])
	else:
		for entry in crew["units"]: entry["aim"] = {}
	# 4. Pause runs its course.
	if pause_active(crew) and phase >= crew["pause"]["until"]:
		crew["pause"]["state"] = "expired"
		crew["agreement"] = "honored"
		report.append("The pause ends on schedule. The lamp goes amber.")
	# 5. Loading clock.
	if phase >= LEAVE_ROUND and hauler_running(crew):
		crew["left"] = true
		crew["cargo"] = "left"
		if pause_active(crew):
			crew["pause"]["state"] = "expired"
			crew["agreement"] = "honored"
		report.append("The hauler finishes loading and drives out east. Security goes with it.")
	return " ".join(report).strip_edges()

static func fire(entry: Dictionary, board) -> String:
	var aim_cell: Vector2i = entry["aim"]["cell"]
	board.round_noise.append(entry["cell"])
	if board.soldier_at(aim_cell) < 0: return "Drover security fires at (%d,%d): nobody there now." % [aim_cell.x,aim_cell.y]
	var info: Dictionary = board.sight_preview(entry["cell"],aim_cell)
	if not info["can_fire"]: return "Drover security loses the shot."
	var chance := clampi(int(info["chance"])-(75-SECURITY_AIM)-(SUPPRESSED_AIM if entry["suppressed_by"] >= 0 else 0),5,95)
	var roll: int = board.shot_rng.randi_range(1,100)
	if roll > chance: return "Drover security fires (%d%%) and misses." % chance
	return "Drover security fires (%d%%): %s." % [chance,board.apply_casualty_damage(aim_cell,SECURITY_DAMAGE)]

static func aim_target(entry: Dictionary, board) -> int:
	var best := -1
	var nearest := 1000
	for index in range(board.soldiers.size()):
		if not board.soldier_can_act(index): continue
		var info: Dictionary = board.sight_preview(entry["cell"],board.soldiers[index]["cell"])
		if info["clear"] and info["distance"] <= SECURITY_RANGE and info["distance"] < nearest:
			nearest = info["distance"]
			best = index
	return best

static func step_toward_squad(entry: Dictionary, board) -> void:
	var goal := NONE
	var best := 1000
	for index in range(board.soldiers.size()):
		if not board.soldier_can_act(index): continue
		var gap := distance(entry["cell"],board.soldiers[index]["cell"])
		if gap < best:
			best = gap
			goal = board.soldiers[index]["cell"]
	if goal == NONE: return
	var steps := SECURITY_MOVE
	for step in range(steps):
		var next: Vector2i = entry["cell"]
		for direction in DIRECTIONS:
			var candidate: Vector2i = entry["cell"]+direction
			if not board.cell_is_in_bounds(candidate) or board.WALL_CELLS.has(candidate) or board.FIXTURES.has(candidate): continue
			if board.soldier_at(candidate) >= 0 or board.cohort_at(candidate) >= 0 or board.target_at(candidate) >= 0: continue
			if distance(candidate,goal) < distance(next,goal): next = candidate
		if next == entry["cell"]: return
		entry["cell"] = next
