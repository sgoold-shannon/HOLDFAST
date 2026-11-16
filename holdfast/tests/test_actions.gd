extends "res://tests/test_support.gd"

func run() -> void:
	var blast = new_board("blast")
	blast.soldiers[0]["cell"] = Vector2i(10,7)
	blast.soldiers[3]["cell"] = Vector2i(10,9)
	blast.damage_cell(Vector2i(10,7),8)
	blast.damage_cell(Vector2i(10,9),8)
	blast.cohorts[0]["cell"] = Vector2i(10,9)
	blast.soldiers[2]["cell"] = Vector2i(10,4)
	blast.enemies[0]["hp"] = 4
	blast.select_soldier(2)
	blast.sight_mode = true
	blast.pinned_target = Vector2i(10,8)
	for seed_value in range(100):
		blast.shot_rng.seed = seed_value
		if blast.shot_rng.randi_range(1,100) <= 85:
			blast.shot_rng.seed = seed_value
			break
	expect(blast.try_fire(),"Real destruction shot resolves")
	expect(blast.result_ready and blast.soldiers[0]["condition"] == "dead" and blast.soldiers[3]["condition"] == "dead" and blast.cohorts[0]["hp"] == 0,"Full blast after MSG death precedes terminal record")
	expect(blast.SaveStore.load_snapshot(blast.report_path)["error"] == "","Final shot and blast result save is valid")
	var rescue = new_board("rescue")
	rescue.damage_cell(Vector2i(3,6),8)
	rescue.select_soldier(1)
	rescue.rescue_target = 0
	expect(rescue.try_stabilize() and rescue.try_pickup(),"Treat and pick up MSG")
	rescue.soldiers[1]["ap"] = 1
	rescue.soldiers[1]["cell"] = Vector2i(19,8)
	rescue.soldiers[0]["cell"] = Vector2i(19,8)
	expect(rescue.try_extract(),"Carried MSG extraction")

	expect(rescue.rescue_events.size()==3,"Treatment, pickup and extraction each record once")
	expect(rescue.soldiers[1]["ap"]==0 and rescue.soldiers[1]["carrying"]==-1 and rescue.soldiers[0]["carried_by"]==-1,"Carrier extraction costs one AP and clears both links")
	expect(rescue.knowledge[1].size()==3 and rescue.knowledge[0].is_empty(),"Rescuer knows the three actions; unconscious casualty does not")
	var recorded: Array = rescue.rescue_events.duplicate(true)
	expect(not rescue.try_extract() and not rescue.try_stabilize() and not rescue.try_pickup(),"No active rescuer cannot repeat successful actions")
	expect(rescue.rescue_events==recorded,"Rejected rescue actions create no records")
	blast.free()
	rescue.free()
	print("ACTION ORCHESTRATION FAILURES: ",failures)
	quit(1 if failures else 0)
