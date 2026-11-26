extends RefCounted
## Reptilian plasma mortar (Civic Center). GDD v3.1 §20: the impact area is marked before it
## detonates; it destroys cover. Once the convoy leaves, its next two shots go at the convoy.
## Silenced by killing the spotter on the annex roof. State: board.mortar.
const SPOTTER_HP := 6
const RADIUS := 1                # 3×3
const DAMAGE := 4
const CROWD_DAMAGE := 2
const CONVOY_SHOTS := 2
const VEHICLES := 3
const NONE := Vector2i(-1,-1)

static func initial(spotter: Vector2i) -> Dictionary:
	return {"spotter":{"cell":spotter,"hp":SPOTTER_HP},"mark":NONE,"convoy_mark":false,"convoy_shots":0,
		"vehicles":VEHICLES,"convoy":"waiting","log":[]}

static func silenced(mortar: Dictionary) -> bool:
	return mortar["spotter"]["hp"] <= 0

static func in_area(center: Vector2i, cell: Vector2i) -> bool:
	return center != NONE and absi(cell.x-center.x) <= RADIUS and absi(cell.y-center.y) <= RADIUS

static func take_hit(mortar: Dictionary, damage: int) -> String:
	mortar["spotter"]["hp"] = maxi(0,mortar["spotter"]["hp"]-damage)
	if silenced(mortar):
		mortar["mark"] = NONE
		mortar["convoy_mark"] = false
		mortar["log"].append("spotter_down")
		return "Mortar spotter down. The mortar goes quiet."
	return "Mortar spotter hit (%d HP left)." % mortar["spotter"]["hp"]

## Reptilian phase, after the alarm: fire the marked shot, then mark the next.
static func act(mortar: Dictionary, board) -> String:
	if silenced(mortar): return ""
	var report: Array[String] = []
	if mortar["convoy_mark"]:
		mortar["convoy_mark"] = false
		mortar["convoy_shots"] += 1
		if board.convoy_shielded():
			report.append("A mortar round bursts on a Nordic shield over the convoy.")
		else:
			mortar["vehicles"] = maxi(0,mortar["vehicles"]-1)
			mortar["log"].append("vehicle_lost")
			report.append("A mortar round hits the convoy: %d of %d vehicles left." % [mortar["vehicles"],VEHICLES])
	elif mortar["mark"] != NONE:
		var hurt: Array[String] = []
		for dx in range(-RADIUS,RADIUS+1):
			for dy in range(-RADIUS,RADIUS+1):
				var cell: Vector2i = mortar["mark"]+Vector2i(dx,dy)
				if board.soldier_at(cell) >= 0: hurt.append(board.apply_casualty_damage(cell,DAMAGE))
				elif board.cohort_at(cell) >= 0: hurt.append(board.apply_casualty_damage(cell,CROWD_DAMAGE))
				board.destroy_cover(cell)
		report.append("Mortar impact at (%d,%d)%s; the cover there is gone." % [mortar["mark"].x,mortar["mark"].y,"" if hurt.is_empty() else ": " + "; ".join(hurt)])
	mortar["mark"] = NONE
	if mortar["convoy"] == "departed" and mortar["convoy_shots"] < CONVOY_SHOTS:
		mortar["convoy_mark"] = true
		report.append("The mortar walks its next round onto the convoy's road.")
	else:
		mortar["mark"] = board.mortar_target()
		if mortar["mark"] != NONE: report.append("Orange marks a mortar impact at (%d,%d) for next phase." % [mortar["mark"].x,mortar["mark"].y])
	return " ".join(report)
