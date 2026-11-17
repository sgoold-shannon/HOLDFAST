extends "res://tests/test_support.gd"
func run() -> void:
	var board = new_board("preview-launch")
	current_scene = board
	var before: Dictionary = board.encounter_snapshot()
	var readability = root.get_node("Readability")
	readability.open_preview()
	expect(readability.preview_open and not board.visible and board.process_mode==Node.PROCESS_MODE_DISABLED,"Preview pauses and hides the existing demo")
	var preview = root.get_child(root.get_child_count()-1)
	expect(preview is Node3D,"Preview opens without a keyboard shortcut")
	var count := root.get_child_count()
	readability.open_preview()
	expect(root.get_child_count()==count,"Repeated launch does not create duplicate previews")
	preview.select_actor(0)
	preview.activate_cell(Vector2i(7,6))
	expect(preview.session.encounter.soldiers[0]["cell"]==Vector2i(7,6),"Practice movement resolves before returning")
	preview.session.command("exit",0)
	await preview.run_command("turn")
	expect(preview.session.encounter.phase==2,"Practice resolves a civilian and machine turn before returning")
	preview.close_preview()
	await process_frame
	await process_frame
	expect(not readability.preview_open and board.visible and board.process_mode==Node.PROCESS_MODE_INHERIT,"Back restores the original demo")
	expect(board.encounter_snapshot()==before,"Round trip preserves unsaved encounter state exactly")
	expect(readability.is_processing() and readability.is_processing_input(),"Magnifier input resumes")
	current_scene = null
	board.free()
	print("PREVIEW LAUNCH FAILURES: ",failures)
	quit(1 if failures else 0)
