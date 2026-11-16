extends RefCounted
## Civilian simulation independent of scene inheritance, input, drawing, and saves.
## Mission callbacks are evaluated on every query: hazards, gates and exits can change.
## Caller owns cohort/soldier dictionaries; only move_cohort mutates its cohort.
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]
const NONE := Vector2i(-1, -1)
var _safe: Callable
var _waypoint: Callable
var _exit: Callable
var _route_available: Callable
var _actor_available: Callable
var _stepped: Callable

func _init(safe: Callable, waypoint: Callable, exit_cell: Callable,
		route_available: Callable, actor_available: Callable, stepped: Callable) -> void:
	_safe = safe
	_waypoint = waypoint
	_exit = exit_cell
	_route_available = route_available
	_actor_available = actor_available
	_stepped = stepped

func civilian_safe(cell: Vector2i) -> bool:
	return _safe.call(cell)

func civilian_waypoint(order: String) -> Vector2i:
	return _waypoint.call(order)

func civilian_exit() -> Vector2i:
	return _exit.call()

func route_available(order: String) -> bool:
	return _route_available.call(order)

func soldier_can_act(index: int) -> bool:
	return _actor_available.call(index)

func on_civilian_step(cohort: Dictionary, cell: Vector2i) -> void:
	_stepped.call(cohort, cell)

func civilian_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not civilian_safe(goal):
		return result
	var frontier: Array[Vector2i] = [start]
	var previous: Dictionary = {start: NONE}
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == goal:
			while current != start:
				result.push_front(current)
				current = previous[current]
			return result
		for direction in DIRECTIONS: # Stable tie order: east, north, south, west.
			var next := current + direction
			if not previous.has(next) and civilian_safe(next):
				previous[next] = current
				frontier.append(next)
	return result

func route_preview(cohort: Dictionary, order: String, soldiers: Array) -> Array[Vector2i]:
	var start: Vector2i = cohort["cell"]
	if order == "hold": return []
	if order == "follow": return follow_path(cohort, soldiers)
	if not route_available(order): return []
	var waypoint := civilian_waypoint(order)
	if cohort.get("passed", false): return civilian_path(start, civilian_exit())
	var first := civilian_path(start, waypoint)
	var last := civilian_path(waypoint, civilian_exit())
	if (first.is_empty() and start != waypoint) or (last.is_empty() and waypoint != civilian_exit()): return []
	first.append_array(last)
	return first

func follow_path(cohort: Dictionary, soldiers: Array) -> Array[Vector2i]:
	var leader: int = cohort.get("leader", -1)
	if leader < 0 or leader >= soldiers.size(): return []
	if soldiers[leader]["extracted"]:
		return civilian_path(cohort["cell"], civilian_exit())
	if not soldier_can_act(leader): return []
	var cell: Vector2i = soldiers[leader]["cell"]
	var delta: Vector2i = cohort["cell"] - cell
	if absi(delta.x) + absi(delta.y) <= 1: return []
	var best: Array[Vector2i] = []
	for direction in DIRECTIONS:
		var path := civilian_path(cohort["cell"], cell + direction)
		if not path.is_empty() and (best.is_empty() or path.size() < best.size()): best = path
	return best

func follow_wait_reason(cohort: Dictionary, soldiers: Array) -> String:
	var leader: int = cohort.get("leader", -1)
	if leader < 0 or leader >= soldiers.size(): return "No leader — choose a new order"
	if not soldiers[leader]["extracted"] and not soldier_can_act(leader): return "Leader down — choose a new order"
	var delta: Vector2i = cohort["cell"] - soldiers[leader]["cell"]
	if not soldiers[leader]["extracted"] and absi(delta.x) + absi(delta.y) <= 1: return "With leader; ready to follow"
	return "Blocked: no safe path to leader"

func move_cohort(cohort: Dictionary, budget: int, soldiers: Array) -> void:
	if cohort["status"] != "active":
		return
	if cohort["cell"] == civilian_exit():
		cohort["status"] = "extracted"
		cohort["note"] = "All four evacuated"
		return
	if cohort["order"] == "hold":
		cohort["note"] = "Waiting for your order"
		return
	if cohort["order"] == "follow":
		for step in range(budget):
			var path := follow_path(cohort, soldiers)
			if path.is_empty():
				cohort["note"] = follow_wait_reason(cohort, soldiers)
				break
			cohort["cell"] = path[0]
			on_civilian_step(cohort, path[0])
			cohort["note"] = "Following; moves after End turn"
			if cohort["cell"] == civilian_exit():
				cohort["status"] = "extracted"
				cohort["note"] = "All four evacuated"
				break
		return
	var waypoint := civilian_waypoint(cohort["order"])
	var moved := 0
	for step in range(budget):
		if cohort["cell"] == waypoint:
			cohort["passed"] = true
		var goal: Vector2i = civilian_exit() if cohort["passed"] else waypoint
		var path := civilian_path(cohort["cell"], goal)
		if path.is_empty():
			cohort["note"] = "Blocked: no safe chosen route"
			break
		cohort["cell"] = path[0]
		on_civilian_step(cohort,path[0])
		moved += 1
		if cohort["cell"] == waypoint:
			cohort["passed"] = true
		if cohort["cell"] == civilian_exit():
			cohort["status"] = "extracted"
			cohort["note"] = "All four evacuated"
			break
		cohort["note"] = "Moved %d/%d squares" % [moved,budget]

func best_exit_route(cohort: Dictionary, soldiers: Array) -> String:
	var best := ""
	var distance := 100000
	for route in ["north", "south"]:
		var preview: Dictionary = cohort.duplicate(true)
		preview["passed"] = false
		var path := route_preview(preview, route, soldiers)
		if not path.is_empty() and path.size() < distance:
			best = route
			distance = path.size()
	return best
