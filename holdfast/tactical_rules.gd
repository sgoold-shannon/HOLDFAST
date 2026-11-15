extends RefCounted
## GDD v3.1: center-to-center supercover, including both sides of corner ties.
const WALLS: Array[Vector2i] = [Vector2i(12, 5), Vector2i(12, 6), Vector2i(12, 8), Vector2i(12, 9)]
const COVER := {Vector2i(5, 5): "north", Vector2i(8, 5): "north", Vector2i(5, 11): "south", Vector2i(8, 11): "south"}

static func supercover(start: Vector2i, finish: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [start]
	var delta := finish - start
	var nx := absi(delta.x)
	var ny := absi(delta.y)
	var sx := signi(delta.x)
	var sy := signi(delta.y)
	var ix := 0
	var iy := 0
	var current := start
	while ix < nx or iy < ny:
		var decision := (1 + 2 * ix) * ny - (1 + 2 * iy) * nx
		if decision == 0:
			cells.append(current + Vector2i(sx, 0))
			cells.append(current + Vector2i(0, sy))
			current += Vector2i(sx, sy)
			ix += 1
			iy += 1
		elif decision < 0:
			current.x += sx
			ix += 1
		else:
			current.y += sy
			iy += 1
		cells.append(current)
	return cells

static func preview(shooter: Vector2i, target: Vector2i) -> Dictionary:
	var cells := supercover(shooter, target)
	var blockers: Array[Vector2i] = []
	for cell in cells:
		if WALLS.has(cell):
			blockers.append(cell)
	var distance := absi(target.x - shooter.x) + absi(target.y - shooter.y)
	var edge: String = COVER.get(target, "none")
	var protected := (edge == "north" and shooter.y < target.y) or (edge == "south" and shooter.y > target.y)
	var cover_modifier := -25 if protected else 0
	var range_modifier := 10 if distance <= 4 else (0 if distance <= 8 else -15)
	return {"cells": cells, "blockers": blockers, "clear": blockers.is_empty(),
		"distance": distance, "edge": edge, "protected": protected,
		"cover_modifier": cover_modifier, "range_modifier": range_modifier,
		"chance": clampi(75 + range_modifier + cover_modifier, 5, 95),
		"can_fire": blockers.is_empty() and distance >= 1 and distance <= 12}
