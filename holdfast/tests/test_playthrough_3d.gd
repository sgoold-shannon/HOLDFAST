extends "res://tests/test_support.gd"
var preview
var reference
func choose(index: int) -> void:
	preview.select_actor(index)
	reference.select_soldier(index)
func move_to(cell: Vector2i) -> void:
	expect(preview.session.move(cell)==reference.try_move(cell),"Legal move results match")
	expect(preview.session.encounter.encounter_snapshot()==reference.encounter_snapshot(),"Move snapshot matches")
func command(action: String, group: int = 0) -> void:
	preview.session.command(action,group)
	match action:
		"exit": reference.order_exit(group)
		"follow": reference.order_cohort(group,"follow")
		"target":
			reference.sight_mode = true
			reference.pinned_target = reference.enemies[0]["cell"] if reference.machine_present() else reference.NONE
		"fire": reference.try_fire()
		"turn": reference.next_phase()
		"extract": reference.try_extract()
	expect(preview.session.encounter.encounter_snapshot()==reference.encounter_snapshot(),"Command %s exact production parity" % action)
func exit_soldier(index: int) -> void:
	if not reference.soldier_can_act(index): return
	choose(index)
	for step in range(3):
		if reference.soldiers[index]["ap"]<1 or reference.soldiers[index]["extracted"]: return
		var start: Vector2i = reference.soldiers[index]["cell"]
		if reference.extraction_cell(start):
			command("extract")
			return
		var path := path_to_exit(reference,start)
		var limit: int = 8 if reference.soldiers[index]["ap"]==2 else 4
		var destination: Vector2i = reference.NONE
		for distance in range(mini(limit,path.size()),0,-1):
			var cell: Vector2i = path[distance-1]
			if reference.soldier_at(cell)<0 and cell!=reference.next_machine_cell() and cell!=reference.machine["pending_shot"] and reference.move_cost(cell)>0:
				destination = cell
				break
		if destination==reference.NONE: return
		move_to(destination)
func scenario(fight: bool) -> void:
	preview = load("res://map_preview_3d.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	reference = new_board("3d-full-"+str(fight))
	reference.finish_opening()
	for turn in range(12):
		if reference.ended: break
		if reference.phase<=3:
			choose(0)
			command("follow" if fight else "exit",reference.phase-1)
		if fight and reference.phase==1:
			for index in range(4):
				choose(index)
				move_to(Vector2i(7,[6,7,9,10][index]))
				command("target")
				command("fire")
		else:
			for index in range(4):
				if not fight or index!=0 or reference.phase>=3: exit_soldier(index)
		command("turn")
		await process_frame
		preview.refresh_movement()
		expect(preview.session.encounter.encounter_snapshot()==reference.encounter_snapshot(),"Deferred completion parity")
	expect(reference.ended and preview.results_panel.visible,"Complete route opens results")
	expect(preview.display["results"]["dispositions"]==reference.results_panel_snapshot()["dispositions"],"Results display production dispositions")
	expect(str(reference.evacuated_people())+" / 12" in preview.results_text.text,"Report shows actual civilian total")
	if fight: expect(reference.evacuated_people()==12 and reference.all_extracted(),"Combat/follow route rescues all civilians and squad")
	print("3D COMPLETE ROUTE fight=",fight," round=",reference.phase," civilians=",reference.evacuated_people()," squad=",reference.all_extracted())
	preview.results_panel.hide()
	preview.refresh_movement()
	expect(not preview.results_panel.visible,"Review map remains open without forced results reopening")
	preview.reset_practice()
	expect(not preview.results_panel.visible and preview.results_button.disabled and not preview.results_shown,"Reset clears completion UI")
	preview.free()
	reference.free()
func run() -> void:
	await scenario(false)
	await scenario(true)
	print("3D PLAYTHROUGH FAILURES: ",failures)
	quit(1 if failures else 0)
