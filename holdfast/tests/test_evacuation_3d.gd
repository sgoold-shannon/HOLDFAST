extends "res://tests/test_support.gd"
func run() -> void:
	var preview = load("res://map_preview_3d.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	for field in ["report_path","completion_path","campaign_path"]:
		preview.session.encounter.set(field,test_path(field))
	var reference = new_board("evacuation-reference")
	reference.finish_opening()
	preview.select_actor(0)
	reference.select_soldier(0)
	for round_index in range(10):
		if reference.ended: break
		var group := round_index % 3
		preview.session.command("exit",group)
		reference.order_exit(group)
		expect(preview.session.encounter.encounter_snapshot()==reference.encounter_snapshot(),"Civilian orders match production")
		preview.session.command("turn")
		reference.next_phase()
		await process_frame
		preview.refresh_movement()
		expect(preview.session.encounter.encounter_snapshot()==reference.encounter_snapshot(),"Turn resolution matches production through closure")
		expect(preview.machine_model.visible==reference.machine_present(),"Machine visibility follows departure")
		for i in range(3):
			expect(preview.civilian_models[i].position==preview.world(reference.cohorts[i]["cell"]),"Civilian model follows resolved position")
			expect(preview.civilian_models[i].visible==(reference.cohorts[i]["status"]=="active"),"Evacuated civilian figures disappear")
	expect(preview.display["ended"] and preview.turn_button.disabled,"Closure disables End turn")
	for field in ["report_path","completion_path","campaign_path"]:
		expect(not FileAccess.file_exists(test_path(field)),"Closure never writes practice reports or campaign saves")
	preview.reset_practice()
	expect(not preview.display["ended"] and preview.display["phase"]==1,"Reset restores a fresh encounter after closure")
	preview.select_actor(0)
	preview.session.command("follow",0)
	expect(preview.session.encounter.cohorts[0]["leader"]==0,"Follow binds the selected soldier")
	preview.session.command("hold",0)
	expect(preview.session.encounter.cohorts[0]["order"]=="follow","Second order in the same turn is rejected")
	preview.session.command("turn")
	preview.session.command("hold",0)
	expect(preview.session.encounter.cohorts[0]["order"]=="hold","Hold is available next turn")
	preview.session.encounter.soldiers[0]["cell"] = Vector2i(19,6)
	preview.session.encounter.rebuild_movement()
	preview.session.command("extract")
	preview.refresh_movement()
	expect(preview.session.encounter.soldiers[0]["extracted"] and not preview.squad_models[0].visible,"Extraction hides the resolved soldier")
	expect(not preview.session.encounter.save_encounter(test_path("forbidden.json")),"Practice blocks explicit saves")
	expect(not FileAccess.file_exists(test_path("forbidden.json")),"Practice creates no save file")
	preview.free()
	reference.free()
	print("3D EVACUATION FAILURES: ",failures)
	quit(1 if failures else 0)
