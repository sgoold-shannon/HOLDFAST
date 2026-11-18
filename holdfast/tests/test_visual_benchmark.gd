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
	scene.close()
	await process_frame
	await process_frame
	expect(board.visible and not launcher.preview_open,"Back restores demo")
	expect(board.encounter_snapshot()==original,"Benchmark never alters encounter state")
	current_scene = null
	board.free()
	print("VISUAL BENCHMARK FAILURES: ",failures)
	quit(1 if failures else 0)
