extends "res://tests/test_support.gd"
func run() -> void:
	var preview = load("res://map_preview_3d.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	var reference = new_board("rescue-3d-reference")
	reference.finish_opening()
	for board in [reference,preview.session.encounter]:
		board.apply_casualty_damage(board.soldiers[0]["cell"],8)
		board.select_soldier(1)
	preview.select_actor(0)
	reference.rescue_target = 0
	expect(preview.display["active"]==1 and preview.display["rescue_target"]==0,"Casualty selection preserves rescuer")
	for action in ["stabilize","pickup","turn"]:
		preview.session.command(action)
		match action:
			"stabilize": reference.try_stabilize()
			"pickup": reference.try_pickup()
			"turn": reference.next_phase()
		await process_frame
		preview.refresh_movement()
		expect(preview.session.encounter.encounter_snapshot()==reference.encounter_snapshot(),"Rescue costs, records and turns match production")
	expect(preview.squad_models[0].position.y>0,"Carried casualty renders above carrier")
	preview.session.command("drop")
	reference.request_drop()
	preview.activate_cell(Vector2i(4,7))
	reference.try_drop(Vector2i(4,7))
	expect(preview.session.encounter.encounter_snapshot()==reference.encounter_snapshot(),"Put down delegates to production")
	expect(preview.squad_models[0].position==preview.world(Vector2i(4,7)),"Dropped casualty appears at resolved cell")
	preview.session.command("pickup")
	reference.try_pickup()
	for board in [reference,preview.session.encounter]:
		board.soldiers[1]["cell"] = Vector2i(19,6)
		board.soldiers[0]["cell"] = Vector2i(19,6)
		board.soldiers[1]["ap"] = 2
		board.rebuild_movement()
	preview.session.command("extract")
	reference.try_extract()
	preview.refresh_movement()
	expect(preview.session.encounter.encounter_snapshot()==reference.encounter_snapshot(),"Carried extraction matches production")
	expect(not preview.squad_models[0].visible and not preview.squad_models[1].visible,"Carrier and casualty disappear together on extraction")
	preview.free()
	reference.free()
	print("3D RESCUE FAILURES: ",failures)
	quit(1 if failures else 0)
