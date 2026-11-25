extends "res://tests/test_support.gd"
## Balance runs for County Hospital (isolated; nothing saved). Not part of the suite.
const Power = preload("res://systems/hospital_power.gd")
const Screening = preload("res://systems/screening.gd")
const Reptilians = preload("res://systems/reptilian_team.gd")

func fresh(infiltrator: int):
	var b = load("res://county_hospital.tscn").instantiate()
	b.auto_resume = false
	root.add_child(b)
	b.command_model = "authority"
	b.screening = Screening.initial(infiltrator)
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

func shoot_troopers(b, index: int) -> void:
	for entry in b.reptilian_targets():
		if not b.soldier_can_act(index) or b.soldiers[index]["ap"] < 1: return
		b.select_soldier(index)
		if b.soldiers[index]["ammo"] < 1: b.try_reload()
		b.sight_mode = true
		b.pinned_target = entry["cell"]
		b.try_fire()
		b.sight_mode = false
		b.pinned_target = b.NONE

## plan "c_by_ambulance": power the ambulance, ship C first, screen at triage, watch the gate.
## plan "walkers_first": ambulance takes A then B; C walks with the team protecting it.
func play(tag: String, plan: String, infiltrator: int) -> void:
	var b = fresh(infiltrator)
	var log := []
	for turn in range(11):
		# MSG: power first, then herd from the doorway.
		if turn == 0:
			b.soldiers[0]["cell"] = b.GENERATOR+Vector2i(1,0)
			b.select_soldier(0)
			b.toggle_power("ambulance")
		else:
			step_toward(b,0,Vector2i(8,8) if turn < 5 else Vector2i(18,8))
		for i in range(3):
			var c = b.cohorts[i]
			if c["status"] != "active": continue
			b.select_soldier(0)
			if c.get("panic",0) > 0: b.calm_cohort(i)
			var target_order := "hold" if (plan == "c_by_ambulance" and i == 2 and b.ambulance["trips"].is_empty()) or (plan == "walkers_first" and i < 2 and b.ambulance["trips"].size() <= i) else "north"
			if c["order"] != target_order: b.order_cohort(i,target_order)
		# Ortiz works the ambulance bay.
		var ambulance_group := 2 if plan == "c_by_ambulance" else (0 if b.ambulance["trips"].is_empty() else 1)
		var rider = b.cohorts[ambulance_group]
		if rider["status"] == "active":
			if b.soldiers[1]["cell"] != b.BAY+Vector2i(0,-1): step_toward(b,1,b.BAY+Vector2i(0,-1))
			if Reptilians.distance(rider["cell"],b.BAY) > 1 and b.cohort_at(b.BAY+Vector2i(-1,0)) < 0:
				rider["cell"] = rider["cell"] # walking there is the group's job
				b.select_soldier(0)
				b.order_cohort(ambulance_group,"south")
			b.cohort_selected = ambulance_group
			b.select_soldier(1)
			b.load_ambulance()
		# Bell screens at the triage tent; Park watches the gate in round 3.
		step_toward(b,2,b.CHECKPOINT+Vector2i(0,1))
		for i in range(3):
			b.cohort_selected = i
			b.select_soldier(2)
			if b.screen_reason("credentials") == "": b.check_credentials()
		step_toward(b,3,Vector2i(12,5))
		for i in range(3):
			if Screening.confirmed(b.screening,i) and b.screening["people"][i]["status"] == "with group":
				for s in [3,2,1,0]:
					b.cohort_selected = i
					b.select_soldier(s)
					if b.detain_reason() == "":
						b.detain_person()
						break
		for s in [2,3,1]: shoot_troopers(b,s)
		if b.team_reason() == "":
			b.cohort_selected = 2
			b.select_soldier(0)
			b.order_team("protect")
		if turn >= 8 or b.remaining_civilians() == 0:
			for s in [0,1,2,3]: evacuate(b,s)
		var r: int = b.phase
		b.next_phase()
		var line := ""
		for c in b.cohorts: line += "%s%s%s " % [c["id"],c["cell"],{"active":"","extracted":"+","stranded":"x","taken":"T","riding":"~"}.get(c["status"],"?")]
		log.append("r%d %s | %s" % [r,line,b.enemy_message.left(130)])
		if b.ended: break
	print("%-16s inf=%d out=%d/12 amb=%s infiltrator=%s taken=%s team=%d end=%s" % [tag,infiltrator,b.evacuated_people(),b.ambulance["trips"],Screening.result(b.screening,b),b.reptilians["taken"],load("res://systems/fire_team.gd").standing(b.team),b.end_reason])
	for l in log: print("   ",l)
	b.free()

func run() -> void:
	play("c_by_ambulance","c_by_ambulance",1)
	play("walkers_first","walkers_first",1)
	play("c_by_ambulance","c_by_ambulance",2)
	quit(0)
