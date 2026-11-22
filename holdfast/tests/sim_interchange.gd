extends "res://tests/test_support.gd"
## Balance runs for the Interchange (isolated; nothing saved). Not part of the suite.
const Crew = preload("res://systems/drover_crew.gd")
const Drone = preload("res://systems/grey_drone.gd")

func fresh():
	var b = load("res://interchange.tscn").instantiate()
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
			if cost != 1: continue
			var gap: int = absi(cell.x-goal.x)+absi(cell.y-goal.y)
			if gap < best_gap:
				best_gap = gap
				best = cell
	if best != b.NONE: b.try_move(best)

func shoot(b, index: int, cell: Vector2i) -> void:
	if not b.soldier_can_act(index): return
	b.select_soldier(index)
	if b.soldiers[index]["ammo"] < 1: b.try_reload()
	b.sight_mode = true
	b.pinned_target = cell
	b.try_fire()
	b.sight_mode = false
	b.pinned_target = b.NONE

func play(tag: String, plan: String) -> void:
	var b = fresh()
	var log := []
	for turn in range(12):
		# MSG herds from (7,6): within voice of group C on the overpass and of the hauler.
		if plan == "pause" or plan == "assault":
			if b.soldiers[0]["cell"] != Vector2i(7,6) and b.cohorts[2]["status"] == "active": step_toward(b,0,Vector2i(7,6))
			b.select_soldier(0)
			if plan == "pause" and b.crew["pause"]["state"] == "none":
				if not b.crew["observed"]: b.observe_hauler()
				b.transmit_pause(false)
		else:
			if turn == 0:
				for i in range(3): b.order_exit(i)
			step_toward(b,0,b.cohorts[2]["cell"] if b.cohorts[2]["status"] == "active" else Vector2i(18,8))
		# A soldier walks the frontage road to watch the south.
		if plan != "assault": step_toward(b,3,Vector2i(15,11))
		if b.cohorts[2]["status"] != "active" and b.cohorts[0]["status"] != "active" and b.cohorts[1]["status"] != "active": evacuate(b,0)
		for i in range(3):
			var c = b.cohorts[i]
			if c["status"] != "active": continue
			if c.get("panic",0) > 0: b.calm_cohort(i)
			if c["order"] == "hold": b.order_exit(i)
		if b.drone_visible() and not b.drone["observed"]:
			for s in [3,2,1]:
				if b.soldier_can_act(s):
					b.select_soldier(s)
					if b.observe_drone(): break
		match plan:
			"assault":
				for s in [1,2,3]:
					var done := false
					for entry in b.crew["units"]:
						if Crew.unit_fighting(entry) and not done:
							shoot(b,s,entry["cell"])
							done = true
			_:
				if turn >= 6:
					for s in [1,2,3]: evacuate(b,s)
		if plan == "assault" and turn >= 5:
			for s in [1,2,3]: evacuate(b,s)
		var r: int = b.phase
		b.next_phase()
		var line := ""
		for c in b.cohorts: line += "%s%s%s " % [c["id"],c["cell"],{"active":"","extracted":"+","stranded":"x"}.get(c["status"],"?")]
		log.append("r%d %s | s3=%s drone=%s %s vis=%s | %s" % [r,line,b.soldiers[3]["cell"],b.drone["stage"],b.drone["cell"],b.drone_visible(),b.enemy_message.left(100)])
		if b.ended: break
	var hurt := 0
	for s in b.soldiers: hurt += 0 if s["condition"] == "active" else 1
	print("%-10s out=%d/12 agreement=%s drone=%s cargo=%s hurt=%d end=%s" % [tag,b.evacuated_people(),b.agreement(),b.drone["outcome"],b.crew["cargo"],hurt,b.end_reason])
	for l in log: print("   ",l)
	b.free()

func run() -> void:
	play("pause","pause")
	play("frontage","frontage")
	play("assault","assault")
	quit(0)
