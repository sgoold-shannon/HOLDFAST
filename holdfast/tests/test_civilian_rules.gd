extends SceneTree
## The civilian component runs on a different map without any Farm Road scene.
const Evacuation = preload("res://systems/civilian_evacuation.gd")
var failures := 0
var blocked: Array[Vector2i] = []
var upper_open := true
var leader_active := true
var exit_cell := Vector2i(6,3)
var steps: Array[Vector2i] = []
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func safe(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= 6 and cell.y >= 1 and cell.y <= 5 and not blocked.has(cell)
func waypoint(order: String) -> Vector2i:
	return Vector2i(4,1) if order == "north" else Vector2i(4,5)
func destination() -> Vector2i: return exit_cell
func available(order: String) -> bool: return upper_open or order != "north"
func actor_available(_index: int) -> bool: return leader_active
func stepped(_cohort: Dictionary, cell: Vector2i) -> void: steps.append(cell)
func group(order: String = "hold") -> Dictionary:
	return {"cell":Vector2i(1,3),"order":order,"passed":false,"status":"active","note":"","leader":0}
func run() -> void:
	var rules = Evacuation.new(safe,waypoint,destination,available,actor_available,stepped)
	var actors: Array = [{"cell":Vector2i(4,3),"extracted":false}]
	var cohort := group()
	var before := cohort.duplicate(true)
	expect(rules.best_exit_route(cohort,actors)=="north", "Stable upper-route tie on independent 6x5 map")
	expect(cohort == before, "Route inspection has no side effects")
	upper_open = false
	expect(rules.best_exit_route(cohort,actors)=="south", "Mission route availability evaluated dynamically")
	blocked.assign([Vector2i(4,5)])
	expect(rules.best_exit_route(cohort,actors)=="", "No complete legal route is reported honestly")
	blocked.clear()
	cohort["order"] = "south"
	for turn in range(4): rules.move_cohort(cohort,3,actors)
	expect(cohort["status"]=="extracted" and cohort["cell"]==exit_cell, "Custom-map exit reached with bounded moves")
	expect(steps.size()==9, "Mission receives exactly one event per actual step")
	var extracted := cohort.duplicate(true)
	rules.move_cohort(cohort,3,actors)
	expect(cohort==extracted and steps.size()==9, "Completed cohort cannot move or duplicate events")
	cohort = group("follow")
	blocked.assign([Vector2i(2,3)])
	var route = rules.follow_path(cohort,actors)
	expect(not route.has(Vector2i(2,3)) and not route.is_empty(), "Follow avoids dynamic hazard")
	leader_active = false
	before = cohort.duplicate(true)
	rules.move_cohort(cohort,3,actors)
	expect(cohort["cell"]==before["cell"] and "Leader down" in cohort["note"], "Unavailable leader halts movement")
	leader_active = true
	actors = [{"cell":Vector2i(4,3),"extracted":true}]
	exit_cell = Vector2i(1,1)
	rules.move_cohort(cohort,3,actors)
	expect(cohort["status"]=="extracted" and cohort["cell"]==exit_cell, "New soldier array and changed exit are read fresh")
	cohort = group("hold")
	before = cohort.duplicate(true)
	rules.move_cohort(cohort,3,actors)
	expect(cohort["cell"]==before["cell"] and cohort["status"]=="active", "Hold leaves group in place")
	cohort = group("south")
	cohort["status"] = "stranded"
	before = cohort.duplicate(true)
	rules.move_cohort(cohort,3,actors)
	expect(cohort==before, "Stranded groups remain untouched")
	print("INDEPENDENT CIVILIAN RULES FAILURES: ",failures)
	quit(1 if failures else 0)
