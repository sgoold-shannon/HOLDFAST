extends "res://tests/test_support.gd"
## Balance runs for the Rail Yard (isolated; nothing saved). Not part of the suite.
const Yard = preload("res://systems/grey_yard.gd")

func fresh():
	var b = load("res://rail_yard.tscn").instantiate()
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
			if b.move_cost(cell) != 1: continue
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

## Each pen has a worker: Bell takes the middle, Ortiz and Park the outer two.
func play(tag: String, plan: String) -> void:
	var b = fresh()
	var log := []
	var workers := {1:0,2:1,3:2}
	for turn in range(12):
		if plan == "trade" and b.trade_offered():
			b.select_soldier(0)
			b.accept_trade()
		for s in [1,2,3]:
			var pen: int = workers[s]
			if plan == "archive" and s == 3: pen = -1
			if pen >= 0 and not b.pens[pen]["open"] and b.cohorts[pen]["status"] == "active":
				var cell: Vector2i = b.pens[pen]["cell"]+Vector2i(-1,0)
				if b.soldiers[s]["cell"] != cell: step_toward(b,s,cell)
				b.select_soldier(s)
				if s == 2 and b.bypass_reason() == "": b.bypass_lock()
				else:
					while b.cut_reason() == "": b.cut_lock()
			elif pen < 0 and b.archive["state"] != "full" and not b.yard["withdrawn"]:
				var spot: Vector2i = b.TERMINAL+Vector2i(-1,0)
				if b.soldiers[s]["cell"] != spot: step_toward(b,s,spot)
				b.select_soldier(s)
				b.download_archive()
			else:
				var col: Dictionary = Yard.unit(b.yard,"collector")
				if not col.is_empty() and not b.yard["load"].is_empty(): shoot(b,s,col["cell"])
				evacuate(b,s)
		# MSG follows the freed groups and keeps them moving.
		step_toward(b,0,Vector2i(5,9))
		for i in range(3):
			var c = b.cohorts[i]
			if c["status"] != "active" or c.get("penned",false): continue
			b.select_soldier(0)
			if c.get("panic",0) > 0: b.calm_cohort(i)
			if c["order"] == "hold": b.order_exit(i)
		if turn >= 7 or b.remaining_civilians() == 0: evacuate(b,0)
		var r: int = b.phase
		b.next_phase()
		var line := ""
		for c in b.cohorts: line += "%s%s%s " % [c["id"],c["cell"],("P" if c.get("penned",false) else "")+{"active":"","extracted":"+","stranded":"x","taken":"T"}.get(c["status"],"?")]
		log.append("r%d %s | %s" % [r,line,b.enemy_message.left(120)])
		if b.ended: break
	var hurt := 0
	for s in b.soldiers: hurt += 0 if s["condition"] == "active" else 1
	print("%-8s out=%d/12 aboard=%s archive=%s trade=%s hurt=%d end=%s" % [tag,b.evacuated_people(),b.yard["aboard"],b.archive["state"],b.trade_result(),hurt,b.end_reason])
	for l in log: print("   ",l)
	b.free()

func run() -> void:
	play("people","people")
	play("archive","archive")
	play("trade","trade")
	quit(0)
