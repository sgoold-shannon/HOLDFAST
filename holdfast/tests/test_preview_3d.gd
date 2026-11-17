extends "res://tests/test_support.gd"
func run() -> void:
	var preview = load("res://map_preview_3d.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	for y in range(1,17):
		for x in range(1,21):
			var cell := Vector2i(x,y)
			expect(preview.cell_at(preview.camera.unproject_position(preview.world(cell)))==cell,"3D picking round trip")
	preview.select_cell(Vector2i(3,6))
	expect(preview.detail.text.contains("MSG") and preview.selected==Vector2i(3,6),"Selecting squad identifies the role")
	preview.select_cell(Vector2i(9,8))
	expect(preview.detail.text.contains("4 damage"),"Next-step selection explains danger")
	expect(preview.Mission.squad_spawns[0]==Vector2i(3,6),"Inspecting cells does not move actors")
	preview.free()
	print("3D PREVIEW FAILURES: ",failures)
	quit(1 if failures else 0)
