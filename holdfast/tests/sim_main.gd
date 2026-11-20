extends SceneTree
## Balance runs for Main Street (isolated; nothing saved). Not part of the suite.
const Fallow = preload("res://systems/fallow_cutter.gd")
func _initialize() -> void:
	call_deferred("go")
func fresh():
	var b = load("res://main_street.tscn").instantiate()
	b.auto_resume = false
	root.add_child(b)
	b.command_model = "authority"
	b.finish_opening()
	return b
func step_toward(b, index: int, goal: Vector2i) -> void:
	if not b.soldier_can_act(index): return
	b.select_soldier(index)
	for reach in range(8,0,-1):
		var best: Vector2i = b.NONE
		var best_gap := 999
		for x in range(1,b.GRID_SIZE.x+1):
			for y in range(1,b.GRID_SIZE.y+1):
				var cell := Vector2i(x,y)
				var cost: int = b.move_cost(cell)
				if cost <= 0 or cost > b.soldiers[index]["ap"]: continue
				var gap: int = absi(cell.x-goal.x)+absi(cell.y-goal.y)
				if gap < best_gap:
					best_gap = gap
					best = cell
		if best != b.NONE:
			b.try_move(best)
		return
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
		for i in range(3):
			var c = b.cohorts[i]
			if c["status"] != "active": continue
			if Fallow.cutter_alive(b.fallow) and b.fallow["marked"].has(c["cell"]): b.order_cohort(i,"north")
			if c.get("panic",0) > 0: b.calm_cohort(i)
			if c["order"] == "hold": b.order_exit(i)
		step_toward(b,0,b.cohorts[0]["cell"]+Vector2i(1,0))
		match plan:
			"demolish":
				for s in [1,2,3]:
					if b.machine_present(): shoot(b,s,b.enemies[0]["cell"])
					elif Fallow.cutter_alive(b.fallow): shoot(b,s,b.fallow["cutter"]["cell"])
			"breaker":
				step_toward(b,2,b.BREAKER_CELL+Vector2i(0,-1))
				b.select_soldier(2)
				b.try_breaker()
				b.try_breaker()
				for s in [1,3]:
					if Fallow.cutter_alive(b.fallow): shoot(b,s,b.fallow["cutter"]["cell"])
			"ignore":
				pass
		var r: int = b.phase
		b.next_phase()
		var line := ""
		for c in b.cohorts: line += "%s%s%s " % [c["id"],c["cell"],{"active":"","extracted":"+","stranded":"x"}.get(c["status"],"?")]
		log.append("r%d %s | %s" % [r,line,b.enemy_message.left(110)])
		if b.ended: break
		if b.phase > b.deadline(): break
	print("%-10s out=%d/12 platform=%s rifts=%d end=%s" % [tag,b.evacuated_people(),b.platform_state(),b.fallow["rifts"].size(),b.end_reason])
	for l in log: print("   ",l)
	b.free()
func go() -> void:
	play("ignore","ignore")
	play("demolish","demolish")
	play("breaker","breaker")
	quit(0)
