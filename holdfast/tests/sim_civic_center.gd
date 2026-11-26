extends "res://tests/test_support.gd"
## Balance runs for the Civic Center (isolated; nothing saved). Not part of the suite.
const Garrison = preload("res://systems/reptilian_garrison.gd")
const Mortar = preload("res://systems/plasma_mortar.gd")

func fresh():
	var b = load("res://civic_center.tscn").instantiate()
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

func shoot_visible(b, index: int) -> void:
	for entry in b.garrison["units"]:
		if not b.soldier_can_act(index) or b.soldiers[index]["ap"] < 1 or b.soldiers[index]["attacked"]: return
		if not Garrison.visible(entry,b): continue
		b.select_soldier(index)
		if b.soldiers[index]["ammo"] < 1: b.try_reload()
		b.sight_mode = true
		b.pinned_target = entry["cell"]
		b.try_fire()
		b.sight_mode = false
		b.pinned_target = b.NONE

## plan "people": council and atrium first, then the pen. "records": Bell goes for the terminal.
func play(tag: String, plan: String) -> void:
	var b = fresh()
	var log := []
	for turn in range(11):
		step_toward(b,0,Vector2i(10,13) if turn < 2 else Vector2i(10,10))
		for i in range(3):
			var c = b.cohorts[i]
			if c["status"] != "active" or c.get("penned",false): continue
			b.select_soldier(0)
			if c.get("panic",0) > 0: b.calm_cohort(i)
			if c["order"] == "hold": b.order_exit(i)
		step_toward(b,3,Vector2i(12,9))
		b.select_soldier(3)
		if b.scout_reason() == "" and not b.hatch_found: b.scout()
		if plan == "records" and not b.records["done"]:
			step_toward(b,2,b.TERMINAL+Vector2i(-1,0))
			b.select_soldier(2)
			while b.records_reason() == "": b.download_records()
		elif b.hatch_found and not b.pen["open"]:
			step_toward(b,2,b.PEN+Vector2i(-1,0))
			b.select_soldier(2)
			if b.bypass_reason() == "": b.bypass_pen()
		if b.garrison["alarm"]:
			for s in [1,3]: shoot_visible(b,s)
		if turn >= 7 or b.remaining_civilians() == 0:
			for s in [0,1,2,3]: evacuate(b,s)
		var r: int = b.phase
		b.next_phase()
		var line := ""
		for c in b.cohorts: line += "%s%s%s " % [c["id"],c["cell"],("P" if c.get("penned",false) else "")+{"active":"","extracted":"+","stranded":"x","taken":"T"}.get(c["status"],"?")]
		log.append("r%d %s | %s" % [r,line,b.enemy_message.left(130)])
		if b.ended: break
	print("%-8s out=%d/12 records=%s detainees=%s vehicles=%d alarm=%s end=%s" % [tag,b.evacuated_people(),b.records["done"],b.detainee_state(),b.mortar["vehicles"],b.garrison["alarm_cause"],b.end_reason])
	for l in log: print("   ",l)
	b.free()

func run() -> void:
	play("people","people")
	play("records","records")
	quit(0)
