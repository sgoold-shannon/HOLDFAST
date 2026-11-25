extends RefCounted
## Quarry platform, tunnel and debris (Mission 07). GDD v3.1 §10: an informed infrastructure
## choice under a timed rescue: demolish (fast, habitat lost for good), isolate (two junction
## boxes and a safe-off, then dig), or recover the controller over several rounds (platform
## keeps running, the rescue takes the long way). State: board.works.
const CHARGE_AP := 2
const CONTROLLER_STEPS := 3
const CONTROLLER_STEPS_SHORT_PART := 4   # Interchange cargo seized: a component is missing
const DIG_AP := 2
const DIG_AP_SURVEYED := 1
const COLLAPSE_ROUND := 9                # tunnel comes down at the end of this round
const BLAST_DAMAGE := 4
const NONE := Vector2i(-1,-1)

static func initial(debris: Array, missing_part: bool, surveyed: bool) -> Dictionary:
	var piles := {}
	for cell in debris: piles[cell] = DIG_AP_SURVEYED if surveyed else DIG_AP
	return {"destroyed":false,"charge":0,"charge_set":false,"jb_west":false,"jb_east":false,"isolated":false,
		"controller_steps":0,"controller_needed":CONTROLLER_STEPS_SHORT_PART if missing_part else CONTROLLER_STEPS,
		"controller_phase":-1,"controller":false,"debris":piles,"collapsed":false,"lost":[],"log":[]}

static func trunk_dead(works: Dictionary) -> bool:
	return works["destroyed"] or works["isolated"]

static func platform_state(works: Dictionary) -> String:
	if works["destroyed"]: return "demolished"
	if works["isolated"]: return "isolated"
	return "running"

static func habitat(works: Dictionary) -> String:
	return {"demolished":"lost","isolated":"strained","running":"powered"}[platform_state(works)]

static func step_charge(works: Dictionary) -> String:
	works["charge"] += 1
	if works["charge"] >= CHARGE_AP:
		works["charge_set"] = true
		works["log"].append("charge_set")
		return "Charge set on the platform. It blows in the next environment phase. Clear the blast."
	return "Charge half set (%d/%d AP)." % [works["charge"],CHARGE_AP]

static func step_isolation(works: Dictionary, which: String) -> String:
	if which == "west" or which == "east":
		works["jb_" + which] = true
		works["log"].append("jb_" + which)
		return "Junction box %s dead. %s" % [which.capitalize(),"Now confirm the safe-off at the platform." if works["jb_west"] and works["jb_east"] else "One more box."]
	works["isolated"] = true
	works["log"].append("isolated")
	return "Safe-off confirmed. The platform is inert; the trunk through the west mouth is dead. The habitat drops to reserve power."

static func step_controller(works: Dictionary, phase: int) -> String:
	works["controller_steps"] += 1
	works["controller_phase"] = phase
	if works["controller_steps"] >= works["controller_needed"]:
		works["controller"] = true
		works["log"].append("controller")
		return "Controller recovered intact. The platform hums on; the habitat keeps full power."
	return "Controller recovery %d/%d. The next step has to wait for next round." % [works["controller_steps"],works["controller_needed"]]

## Environment phase: the charge goes off, and the tunnel collapses on schedule.
static func act(works: Dictionary, board) -> String:
	var report: Array[String] = []
	if works["charge_set"] and not works["destroyed"]:
		works["destroyed"] = true
		works["log"].append("demolished")
		var hurt: Array[String] = []
		for direction in [Vector2i.ZERO,Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var cell: Vector2i = board.PLATFORM+direction
			if board.soldier_at(cell) >= 0 or board.cohort_at(cell) >= 0: hurt.append(board.apply_casualty_damage(cell,BLAST_DAMAGE))
		for cell in works["debris"].keys(): board.clear_debris(cell)
		works["debris"] = {}
		report.append("The platform goes up. The trunk blast blows the west tunnel mouth clear%s. Below the ridge, a habitat loses its power for good." % ("" if hurt.is_empty() else ": " + "; ".join(hurt)))
	if board.phase >= COLLAPSE_ROUND and not works["collapsed"]:
		works["collapsed"] = true
		var lost: Array[String] = []
		for cohort in board.cohorts:
			if cohort["status"] == "active" and board.in_tunnel(cohort["cell"]):
				cohort["status"] = "stranded"
				cohort["note"] = "Trapped when the tunnel came down"
				works["lost"].append(cohort["id"])
				lost.append("group " + cohort["id"])
		for index in range(board.soldiers.size()):
			var soldier: Dictionary = board.soldiers[index]
			if not soldier["extracted"] and soldier["condition"] != "dead" and board.in_tunnel(soldier["cell"]):
				lost.append(board.apply_casualty_damage(soldier["cell"],12))
		report.append("The haul tunnel comes down%s." % ("" if lost.is_empty() else ". Inside: " + ", ".join(lost)))
	return " ".join(report)
