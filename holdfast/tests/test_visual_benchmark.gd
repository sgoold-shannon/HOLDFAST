extends "res://tests/test_support.gd"
func run() -> void:
	var board = new_board("visual-benchmark")
	current_scene = board
	var original: Dictionary = board.encounter_snapshot()
	var launcher = root.get_node("Readability")
	launcher.open_benchmark()
	var scene = root.get_child(root.get_child_count()-1)
	expect(not board.visible and launcher.preview_open,"Benchmark pauses original encounter")
	var position: Vector3 = scene.camera.position
	scene.toggle_light()
	expect(scene.night and scene.camera.position==position,"Night changes lighting without camera movement")
	scene.toggle_headgear()
	expect(scene.cap.visible and not scene.helmet.visible,"Scenario headgear swap works")
	scene.toggle_cargo()
	expect(scene.cargo.visible,"Cargo can be compared without collection rules")
	if OS.get_environment("HOLDFAST_CAPTURE_BENCHMARK")=="1":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/holdfast-benchmark-night.png")
		scene.toggle_light()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/holdfast-benchmark-day.png")
	var shell_material = scene.machine_lamp.material_override
	scene.cycle_focus()
	expect(scene.focus_index==1 and scene.camera.size==4,"Soldier close-up focuses without moving actors")
	scene.cycle_focus()
	expect(scene.focus_index==2,"Machine inspection available")
	scene.toggle_silhouettes()
	expect(scene.silhouettes and scene.machine_lamp.material_override!=shell_material,"Silhouette mode replaces surface detail")
	if OS.get_environment("HOLDFAST_CAPTURE_BENCHMARK")=="1":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/holdfast-inspection-machine.png")
	scene.toggle_silhouettes()
	expect(scene.machine_lamp.material_override==shell_material,"Inspection restores original materials exactly")
	scene.cycle_focus()
	var original_positions: Array[Vector3] = []
	for civilian in scene.civilians: original_positions.append(civilian.position)
	scene.toggle_overlap()
	expect(scene.overlap and scene.soldier.position==Vector3(-0.46,0,1.94),"Overlap test places soldier in cohort space")
	if OS.get_environment("HOLDFAST_CAPTURE_BENCHMARK")=="1":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/holdfast-inspection-overlap.png")
	scene.toggle_overlap()
	expect(scene.soldier.position==Vector3(-3,0,1),"Leaving overlap restores original placement")
	for i in range(scene.civilians.size()):
		expect(scene.civilians[i].position.is_equal_approx(original_positions[i]),"Formation inspection restores every civilian position")
	scene.cycle_stress()
	expect(scene.stress_mode==1 and scene.stress_wall.visible,"Wall stress scenario available")
	for civilian in scene.civilians:
		expect(civilian.position.x+0.24<scene.stress_wall.position.x-0.125,"Civilian body envelope does not enter wall")
	if OS.get_environment("HOLDFAST_CAPTURE_BENCHMARK")=="1":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/holdfast-stress-wall.png")
	scene.cycle_stress()
	expect(scene.stress_mode==2 and not scene.stress_wall.visible,"Crowd test replaces wall test")
	for extra in scene.extra_civilians: expect(extra.visible,"Second cohort has four visible figures")
	scene.select_group(1)
	expect(scene.selected_group==1 and not scene.group_buttons[1].disabled,"Overlapping cohort selectable by fixed-screen control")
	for i in range(8):
		expect(scene.group_markers[i].visible==(i>=4),"Only selected cohort member markers are visible")
	if OS.get_environment("HOLDFAST_CAPTURE_BENCHMARK")=="1":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/holdfast-stress-crowd.png")
	scene.cycle_stress()
	expect(scene.selected_group==0 and scene.group_buttons[1].disabled,"Removing second group resets selection")
	expect(scene.stress_mode==0 and not scene.stress_wall.visible,"Stress cycle clears temporary scenery")
	for extra in scene.extra_civilians: expect(not extra.visible,"Stress cycle hides second group")
	scene.close()
	await process_frame
	await process_frame
	expect(board.visible and not launcher.preview_open,"Back restores demo")
	expect(board.encounter_snapshot()==original,"Benchmark never alters encounter state")
	current_scene = null
	board.free()
	print("VISUAL BENCHMARK FAILURES: ",failures)
	quit(1 if failures else 0)
