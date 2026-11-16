extends RefCounted
## Stable breadth-first movement search. Caller supplies terrain/occupancy policy.
static func reachable(origin: Vector2i, budget: int, directions: Array, walkable: Callable) -> Dictionary:
	var distances := {origin:0}
	var parents := {}
	var frontier: Array[Vector2i] = [origin]
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		if distances[cell] >= budget: continue
		for direction in directions:
			var neighbor: Vector2i = cell + direction
			if not walkable.call(neighbor) or distances.has(neighbor): continue
			distances[neighbor] = distances[cell]+1
			parents[neighbor] = cell
			frontier.append(neighbor)
	return {"distances":distances,"parents":parents}
