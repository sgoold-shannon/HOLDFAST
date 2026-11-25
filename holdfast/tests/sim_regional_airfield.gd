extends "res://tests/test_support.gd"
## Balance runs for the Regional Airfield (isolated; nothing saved). Not part of the suite.
const Strip = preload("res://systems/grey_strippers.gd")
const FallowCutter = preload("res://systems/fallow_cutter.gd")

func fresh():
	var b = load("res://regional_airfield.tscn").instantiate()
	b.auto_resume = false
	root.add_child(b)
	b.command_model = "authority"
	b.finish_opening()
	return b

func step_toward(b, index: int, goal: Vector2i) -> void:
	if not b.soldier_can_act(index): return
	b.select_soldier(index)
	b.sight_mode = false
	var best: Vector2i = b.NONE
	var best_gap := absi(b.soldiers[index]["cell"].x-goal.x)+absi(b.soldiers[index]["cell"].y-goal.y)
	for x in range(1,b.GRID_SIZE.x+1):
		for y in range(1,b.GRID_SIZE.y+1):
			var cell := Vector2i(x,y)
			var cost: int = b.move_cost(cell)
			if cost < 1 or cost > b.soldiers[index]["ap"]: continue
			var gap: int = absi(cell.x-goal.x)+absi(cell.y-goal.y)
			if gap < best_gap:
				best_gap = gap
				best = cell
	if best != b.NONE: b.try_move(best)

func shoot(b, index: int, cell: Vector2i) -> void:
	if not b.soldier_can_act(index) or b.soldiers[index]["ap"] < 1: return
	b.select_soldier(index)
	if b.soldiers[index]["ammo"] < 1: b.try_reload()
	b.sight_mode = true
	b.pinned_target = cell
	b.try_fire()
	b.sight_mode = false
	b.pinned_target = b.NONE

## plan "plane": Bell and Park guard the plane; "data": Park downloads at the hatch.
func play(tag: String, plan: String) -> void:
	var b = fresh()
	var log := []
	for turn in range(11):
		# MSG: contact first, then herd the groups west.
		if not b.craft["contact"] and turn < 6:
			step_toward(b,0,b.CRAFT_DOOR)
			b.select_soldier(0)
			b.make_contact()
		else:
			step_toward(b,0,Vector2i(5,6))
		for i in range(3):
			var c = b.cohorts[i]
			if c["status"] != "active": continue
			b.select_soldier(0)
			if c.get("panic",0) > 0: b.calm_cohort(i)
			if c["order"] == "hold": b.order_exit(i)
			if not b.fallow["marked"].is_empty() and b.fallow["marked"].has(c["cell"]) and b.shield_reason() == "":
				b.cohort_selected = i
				b.request_shield()
		# Ortiz walks the groups out from the terminal door.
		step_toward(b,1,Vector2i(10,9))
		for i in range(3):
			b.cohort_selected = i
			b.select_soldier(1)
			if b.cohorts[i]["status"] == "active" and b.cohorts[i]["order"] == "hold": b.order_exit(i)
		var collector: Dictionary = Strip.unit(b.strip,"collector")
		if plan == "plane":
			for s in [2,3]:
				if not collector.is_empty() and b.strip["progress"] > 0: shoot(b,s,collector["cell"])
				else: step_toward(b,s,Vector2i(10,10))
		else:
			step_toward(b,3,b.CRAFT_DOOR+Vector2i(0,1) if b.soldier_at(b.CRAFT_DOOR) >= 0 else b.CRAFT_DOOR)
			b.select_soldier(3)
			while b.data_reason() == "": b.download_sensors()
		if FallowCutter.cutter_alive(b.fallow):
			for s in [2,3]: shoot(b,s,b.fallow["cutter"]["cell"])
		if turn >= 7 or b.remaining_civilians() == 0:
			for s in [0,1,2,3]: evacuate(b,s)
		var r: int = b.phase
		b.next_phase()
		var line := ""
		for c in b.cohorts: line += "%s%s%s " % [c["id"],c["cell"],{"active":"","extracted":"+","stranded":"x"}.get(c["status"],"?")]
		log.append("r%d %s | %s" % [r,line,b.enemy_message.left(130)])
		if b.ended: break
	print("%-6s out=%d/12 contact=%s data=%s plane=%s runway=%s charges=%d end=%s" % [tag,b.evacuated_people(),b.craft["contact"],b.craft["data"],b.aircraft_state(),"ruined" if b.runway_ruined() else "clear",b.craft["charges"],b.end_reason])
	for l in log: print("   ",l)
	b.free()

func run() -> void:
	play("plane","plane")
	play("data","data")
	quit(0)
