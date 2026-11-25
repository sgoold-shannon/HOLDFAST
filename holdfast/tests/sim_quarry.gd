extends "res://tests/test_support.gd"
## Balance runs for the Quarry (isolated; nothing saved). Not part of the suite.
const Works = preload("res://systems/quarry_works.gd")
const FallowCutter = preload("res://systems/fallow_cutter.gd")

func fresh():
	var b = load("res://quarry.tscn").instantiate()
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

func play(tag: String, plan: String) -> void:
	var b = fresh()
	var log := []
	for turn in range(11):
		match plan:
			"demolish":
				step_toward(b,1,b.PLATFORM+Vector2i(-1,0))
				b.select_soldier(1)
				while b.charge_reason() == "": b.set_charge()
				if b.works["charge_set"] and not b.works["destroyed"]: step_toward(b,1,Vector2i(8,9))
			"isolate":
				step_toward(b,1,b.JB_WEST+Vector2i(0,-1))
				b.select_soldier(1)
				if b.junction_reason() == "": b.kill_junction()
				step_toward(b,3,b.JB_EAST+Vector2i(0,-1))
				b.select_soldier(3)
				if b.junction_reason() == "": b.kill_junction()
				if b.works["jb_west"] and b.works["jb_east"]:
					step_toward(b,3,b.PLATFORM+Vector2i(1,0))
					b.select_soldier(3)
					if b.safe_off_reason() == "": b.confirm_safe_off()
				step_toward(b,2,b.DEBRIS[1]+Vector2i(0,-1))
				b.select_soldier(2)
				while b.dig_reason() == "": b.dig()
			"controller":
				step_toward(b,1,b.PLATFORM+Vector2i(0,-1))
				b.select_soldier(1)
				if b.controller_reason() == "": b.recover_controller()
		# Park fetches the bench crew down the ramp.
		if plan != "isolate" and b.cohorts[2]["status"] == "active":
			step_toward(b,3,b.cohorts[2]["cell"]+Vector2i(-1,0))
			b.select_soldier(3)
			if b.cohorts[2]["order"] == "hold": b.order_exit(2)
		# MSG herds from the floor near the tunnel and the bench ramp.
		step_toward(b,0,Vector2i(4,10))
		for i in range(3):
			var c = b.cohorts[i]
			if c["status"] != "active": continue
			b.select_soldier(0)
			if c.get("panic",0) > 0: b.calm_cohort(i)
			if c["order"] == "hold": b.order_exit(i)
		if turn >= 7 or b.remaining_civilians() == 0:
			for s in [0,1,2,3]: evacuate(b,s)
		var r: int = b.phase
		b.next_phase()
		var line := ""
		for c in b.cohorts: line += "%s%s%s " % [c["id"],c["cell"],{"active":"","extracted":"+","stranded":"x"}.get(c["status"],"?")]
		log.append("r%d %s | %s" % [r,line,b.enemy_message.left(120)])
		if b.ended: break
	print("%-10s out=%d/12 platform=%s habitat=%s controller=%s lost=%s end=%s" % [tag,b.evacuated_people(),Works.platform_state(b.works),Works.habitat(b.works),b.works["controller"],b.works["lost"],b.end_reason])
	for l in log: print("   ",l)
	b.free()

func run() -> void:
	play("demolish","demolish")
	play("isolate","isolate")
	play("controller","controller")
	quit(0)
