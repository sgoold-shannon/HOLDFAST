extends "res://tests/test_support.gd"

func run() -> void:
	var fresh = new_board("startup")
	var controller: Script = fresh.get_script().get_base_script()
	expect(controller.resource_path=="res://encounter_controller.gd" and controller.get_base_script()==null,"Active encounter extends Node2D directly without prototype script ancestry")
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
	disabled.resolve_enemy_turn()
	var activated: Dictionary = disabled.encounter_snapshot()
	disabled.resolve_enemy_turn()
	expect(disabled.encounter_snapshot()==activated,"Repeated enemy resolution cannot activate the machine twice in one phase")
	var ap_before: int = disabled.soldiers[0]["ap"]
	expect(not disabled.protocol_action("invalid") and disabled.soldiers[0]["ap"]==ap_before,"Rejected protocol command consumes no AP")
	disabled.return_state["active"] = true
	var machine_before: Dictionary = disabled.machine.duplicate(true)
	var enemies_before: Array = disabled.enemies.duplicate(true)
	disabled.phase += 1
	disabled.resolve_enemy_turn()
	expect(disabled.machine==machine_before and disabled.enemies==enemies_before,"Return phase does not activate hostile machinery")
	expect(disabled.last_enemy_phase==disabled.phase,"Return phase still records resolution")
	var protocol_before: Dictionary = disabled.protocol.duplicate(true)
	expect(not disabled.protocol_action("observe") and disabled.protocol==protocol_before and disabled.soldiers[0]["ap"]==ap_before,"Return map rejects protocol actions without changing state or AP")
	for board in [fresh,legacy,resumed,disabled,corrupt]: board.free()
	print("STARTUP FAILURES: ",failures)
	quit(1 if failures else 0)
