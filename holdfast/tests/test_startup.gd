extends "res://tests/test_support.gd"

func run() -> void:
	var fresh = new_board("startup")
	var legacy = load("res://farm_return.tscn").instantiate()
	legacy.auto_resume = false
	legacy.campaign_path = test_path("legacy-campaign.save")
	root.add_child(legacy)
	expect(var_to_bytes(fresh.encounter_snapshot())==var_to_bytes(legacy.encounter_snapshot()),"Explicit startup matches inherited fixture initialization exactly")
	expect(fresh.status_text==legacy.status_text and fresh.save_feedback==legacy.save_feedback,"Startup instructions remain unchanged")
	expect(fresh.machine_behavior!=null and fresh.evacuation_rules!=null and fresh.board_projection!=null,"Runtime services are initialized")
	expect(not fresh.auto_resume and not legacy.auto_resume,"Disabled auto-resume remains disabled")
	fresh.next_phase()
	fresh.next_phase()
	var slot := test_path("resume.save")
	expect(fresh.save_encounter(slot),"Progress saves before startup resume")
	var saved: Dictionary = fresh.encounter_snapshot()
	var resumed = load("res://farm_final.tscn").instantiate()
	resumed.auto_resume = true
	resumed.campaign_path = slot
	root.add_child(resumed)
	expect(resumed.auto_resume,"Startup preserves enabled auto-resume preference")
	expect(var_to_bytes(resumed.encounter_snapshot())==var_to_bytes(saved),"Automatic resume runs after initialization and preserves saved progress")
	expect(resumed.report_path=="user://holdfast_d1_result.save" and resumed.completion_path=="user://holdfast_d1_completed.save","Return report paths are configured before resume")
	var disabled = load("res://farm_final.tscn").instantiate()
	disabled.auto_resume = false
	disabled.campaign_path = slot
	root.add_child(disabled)
	expect(disabled.phase==1,"Disabled resume ignores an existing campaign save")
	var corrupt_path := test_path("corrupt-startup.save")
	var file := FileAccess.open(corrupt_path,FileAccess.WRITE)
	file.store_string("invalid save")
	file.close()
	var corrupt = load("res://farm_final.tscn").instantiate()
	corrupt.auto_resume = true
	corrupt.campaign_path = corrupt_path
	root.add_child(corrupt)
	expect(var_to_bytes(corrupt.encounter_snapshot())==var_to_bytes(disabled.encounter_snapshot()),"Rejected startup save leaves fresh encounter state intact")
	for board in [fresh,legacy,resumed,disabled,corrupt]: board.free()
	print("STARTUP FAILURES: ",failures)
	quit(1 if failures else 0)
