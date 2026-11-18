extends "res://tests/test_support.gd"
## Repeatable art review, not an assertion that the visuals pass acceptance.
func run() -> void:
	var destination := OS.get_environment("HOLDFAST_ART_REVIEW")
	if destination.is_empty():
		push_error("Set HOLDFAST_ART_REVIEW to a writable output directory; run with graphics enabled.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	var scene = load("res://visual_benchmark.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.focus_index = 2
	scene.apply_focus()
	# Fixed capture viewport; camera orientation and scene lighting stay as authored.
	var report := {"renderer":"gl_compatibility", "sizes":[2.5,8.0,16.0],"captures":108,"samples":[],"note":"Close/normal/wide are provisional art-review sizes, not approved gameplay zoom bounds. Frame intervals include presentation/vsync and are not GPU timings."}
	var crop_size := Vector2i(600,600)
	for lighting in [false,true]:
		scene.night = lighting
		scene.apply_light()
		for distance in range(3):
			scene.camera.size = report.sizes[distance]
			var sheet := Image.create(600*6,600*3,false,Image.FORMAT_RGB8)
			for cargo_choice in range(3):
				# Set cargo through its public review control while the intact state is active.
				scene.machine_states.apply(0)
				while scene.cargo_mode!=cargo_choice: scene.toggle_cargo()
				for state in range(6):
					scene.machine_states.apply(state)
					scene.refresh_machine_cues()
					await process_frame
					await RenderingServer.frame_post_draw
					var capture := root.get_texture().get_image()
					capture.convert(Image.FORMAT_RGB8)
					var crop := Rect2i((capture.get_size()-crop_size)/2,crop_size)
					sheet.blit_rect(capture,crop,Vector2i(state*600,cargo_choice*600))
			var filename := "%s-%s.png" % ["night" if lighting else "day",["close","normal","wide"][distance]]
			sheet.save_png(destination.path_join(filename))
	# Small, explicitly bounded timing sample, same scene and camera, all six states.
	scene.night = false
	scene.apply_light()
	scene.camera.size = 8
	for state in range(6):
		scene.machine_states.apply(state)
		for warmup in range(20): await process_frame
		var intervals: Array[float] = []
		var previous := Time.get_ticks_usec()
		for frame in range(120):
			await process_frame
			var now := Time.get_ticks_usec()
			intervals.append((now-previous)/1000.0)
			previous = now
		intervals.sort()
		report.samples.append({"state":scene.machine_states.NAMES[state],"median_frame_interval_ms":intervals[60],"p95_frame_interval_ms":intervals[113],"draw_calls_whole_scene":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
	var file := FileAccess.open(destination.path_join("measurements.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	scene.queue_free()
	await process_frame
	print("MACHINE ART MATRIX: 108 views captured; six timing samples recorded.")
	quit()
