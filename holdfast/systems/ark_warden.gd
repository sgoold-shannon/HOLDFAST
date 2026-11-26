extends RefCounted
## The Warden (Mission 11): the ark's ancient defensive emplacement in the gallery. GDD v3.1 §11:
## bypassed, disabled or negotiated through authenticated control; never a mandatory boss.
## Hostile: it takes a shot at anyone crossing the gallery mouth, and marks whoever stands in
## its cone, firing on those squares next phase. Allied: it marks and fires on the Fallow.
## State: board.warden. States: hostile, allied, disabled, destroyed.
const FallowCutter = preload("res://systems/fallow_cutter.gd")
const HP := 16
const DAMAGE := 4
const ALLY_DAMAGE := 3
const OVERWATCH_CHANCE := 75
const DISABLE_STEPS := 2

static func initial(cell: Vector2i) -> Dictionary:
	return {"cell":cell,"state":"hostile","hp":HP,"marked":[],"disable":0,"ally_aim":false,"shots":{},"log":[]}

static func hostile(warden: Dictionary) -> bool:
	return warden["state"] == "hostile"

## The cone: three rows in front (south) of the Warden, widening by one each row.
static func in_cone(warden: Dictionary, cell: Vector2i) -> bool:
	var dy: int = cell.y-warden["cell"].y
	return dy >= 1 and dy <= 3 and absi(cell.x-warden["cell"].x) <= dy+1

static func cone_cells(warden: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dy in range(1,4):
		for dx in range(-dy-1,dy+2):
			cells.append(warden["cell"]+Vector2i(dx,dy))
	return cells

## A move that crosses the gallery mouth (not by the crawl) draws a shot, once per soldier per round.
static func crossing(warden: Dictionary, start: Vector2i, finish: Vector2i) -> bool:
	if start.x <= 2 or finish.x <= 2: return false
	var line: int = warden["cell"].y
	return (start.y > line and finish.y <= line) or (start.y <= line and finish.y > line)

static func overwatch(warden: Dictionary, index: int, board) -> String:
	if not hostile(warden): return ""
	var key := "%d:%d" % [index,board.phase]
	if warden["shots"].has(key): return ""
	warden["shots"][key] = true
	var soldier: Dictionary = board.soldiers[index]
	if board.shot_rng.randi_range(1,100) > OVERWATCH_CHANCE: return "The Warden fires on %s at the gallery mouth and misses." % soldier["name"]
	return "The Warden fires on %s at the gallery mouth: %s." % [soldier["name"],board.apply_casualty_damage(soldier["cell"],DAMAGE)]

## The Warden phase.
static func act(warden: Dictionary, fallow: Dictionary, board) -> String:
	match warden["state"]:
		"hostile":
			var hurt: Array[String] = []
			for cell in warden["marked"]:
				if board.soldier_at(cell) >= 0: hurt.append(board.apply_casualty_damage(cell,DAMAGE))
			var fired: bool = not warden["marked"].is_empty()
			warden["marked"] = []
			for index in range(board.soldiers.size()):
				if board.soldier_can_act(index) and in_cone(warden,board.soldiers[index]["cell"]): warden["marked"].append(board.soldiers[index]["cell"])
			var line := ""
			if fired: line = "The Warden fires on its marked squares%s." % (": " + "; ".join(hurt) if not hurt.is_empty() else ", hitting nobody")
			if not warden["marked"].is_empty(): line += (" " if line != "" else "") + "It marks %d square%s in its cone." % [warden["marked"].size(),"" if warden["marked"].size() == 1 else "s"]
			return line
		"allied":
			if not FallowCutter.cutter_alive(fallow): return ""
			if not warden["ally_aim"]:
				warden["ally_aim"] = true
				return "The Warden swings toward the rift and marks the cutter."
			return "The Warden fires on the cutter: " + FallowCutter.take_hit(fallow,0,ALLY_DAMAGE)
	return ""

static func take_hit(warden: Dictionary, damage: int, flanked: bool) -> String:
	var dealt := damage if flanked else maxi(1,damage/2)
	warden["hp"] = maxi(0,warden["hp"]-dealt)
	if warden["hp"] == 0:
		warden["state"] = "destroyed"
		warden["marked"] = []
		warden["log"].append("destroyed")
		return "The Warden takes %d and goes dark for good." % dealt
	return "The Warden takes %d%s (%d HP left)." % [dealt,"" if flanked else " (armored from the front; flank it from the sanctuary side)",warden["hp"]]
