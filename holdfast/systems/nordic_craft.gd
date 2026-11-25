extends RefCounted
## The damaged Nordic craft (Regional Airfield). GDD v3.1 §05/§26: a small custodial mission
## with finite protection charges and light transport; exhausted protection forces departure.
## Contact has a window; each shield visibly spends a charge. State: board.craft.
const WINDOW_ROUND := 6          # contact must happen by the end of this round
const SHIELD_RADIUS := 1         # 3×3
const DATA_STEPS := 2
const LEAVE_ROUND := 9           # leaves after this round at the latest
const NONE := Vector2i(-1,-1)

static func initial(cell: Vector2i, river_shield: bool, river_group: String) -> Dictionary:
	return {"cell":cell,"contact":false,"charges":1 if river_shield else 2,"river_shield":river_shield,"river_group":river_group,
		"shields":[],"data_steps":0,"data":false,"left":false,"leave_reason":"","log":[]}

static func window_open(craft: Dictionary, phase: int) -> bool:
	return not craft["left"] and phase <= WINDOW_ROUND

static func shielded(craft: Dictionary, cell: Vector2i, phase: int) -> bool:
	for shield in craft["shields"]:
		if phase <= shield["until"] and absi(cell.x-shield["center"].x) <= SHIELD_RADIUS and absi(cell.y-shield["center"].y) <= SHIELD_RADIUS: return true
	return false

static func contact(craft: Dictionary) -> String:
	craft["contact"] = true
	craft["log"].append("contact")
	var line := "The hatch opens a hand's width. ‘I am Aven. Custodian. We have twelve seats, and a sister craft that did not arrive.’"
	if craft["river_shield"]:
		line += " Scorch marks along the hull match River Bridge: this is the craft that covered group %s. Verified." % craft["river_group"]
	return line

static func shield(craft: Dictionary, center: Vector2i, phase: int) -> String:
	craft["charges"] -= 1
	craft["shields"].append({"center":center,"until":phase+1})
	craft["log"].append("shield:%d" % phase)
	return "Aven spends a protection charge over (%d,%d) until your next turn. %d left." % [center.x,center.y,craft["charges"]]

static func download(craft: Dictionary) -> String:
	craft["data_steps"] += 1
	if craft["data_steps"] >= DATA_STEPS:
		craft["data"] = true
		craft["log"].append("data")
		return "Sensor data copied: the incoming Fallow mass, and a count of rescue ships that fits on one hand."
	return "Sensor download %d/%d." % [craft["data_steps"],DATA_STEPS]

## Environment phase: expire shields; leave when protection is exhausted or time is up.
static func act(craft: Dictionary, phase: int) -> String:
	if craft["left"]: return ""
	craft["shields"] = craft["shields"].filter(func(entry): return phase < entry["until"])
	if craft["charges"] <= 0 and craft["shields"].is_empty():
		craft["left"] = true
		craft["leave_reason"] = "protection exhausted"
		return "The Nordic craft lifts out, its last protection spent."
	if phase >= LEAVE_ROUND:
		craft["left"] = true
		craft["leave_reason"] = "window closed"
		return "The Nordic craft lifts out on its own schedule."
	if phase == WINDOW_ROUND and not craft["contact"]: return "The craft's hatch seals. The contact window has closed."
	return ""
