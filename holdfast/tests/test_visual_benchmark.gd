extends "res://tests/test_support.gd"
func run() -> void:
	var board = new_board("visual-benchmark")
	current_scene = board
	var original: Dictionary = board.encounter_snapshot()
	var launcher = root.get_node("Readability")
	launcher.open_benchmark()
	var scene = root.get_child(root.get_child_count()-1)
	expect(not board.visible and launcher.preview_open,"Benchmark pauses original encounter")
	expect(scene.machine.scene_file_path=="res://assets/machine_a/machine_a_01.glb","Benchmark uses baked imported candidate")
	var bounds := AABB()
	var first_mesh := true
	for mesh in scene.machine.find_children("*","MeshInstance3D",true,false):
		var local: Transform3D = scene.machine.global_transform.affine_inverse()*mesh.global_transform
		var part_bounds: AABB = local*mesh.get_aabb()
		bounds = part_bounds if first_mesh else bounds.merge(part_bounds)
		first_mesh = false
	expect(not first_mesh and bounds.size.x<=0.95 and bounds.size.z<=0.95,"Imported asset fits one-cell resting envelope")
	expect(absf(bounds.position.y)<0.001,"Imported root remains at ground contact")
	expect(scene.machine.find_children("*","CollisionObject3D",true,false).is_empty(),"Art import adds no collision behavior")
	var elbow = scene.machine.find_child("ToolElbow",true,false)
	var wrist = scene.machine.find_child("ToolWrist",true,false)
	expect(elbow!=null and wrist!=null and elbow.is_ancestor_of(wrist),"Tool export preserves articulated hierarchy")
	expect(not scene.cargo.visible,"Cargo starts empty after import")
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
	if OS.get_environment("HOLDFAST_CAPTURE_BENCHMARK")=="1":
		# Review-only framing and rotation: restore both before continuing tests.
		var angle: float = scene.machine.rotation.y
		var was_night: bool = scene.night
		scene.camera.size = 2.5
		for review in ["front-day","rear-day","front-night"]:
			scene.machine.rotation.y = angle+PI if review=="rear-day" else angle
			scene.night = review=="front-night"
			scene.apply_light()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/private/tmp/machine-a-"+review+".png")
		scene.machine.rotation.y = angle
		scene.night = was_night
		scene.apply_light()
		scene.apply_focus()
	scene.toggle_silhouettes()
	expect(scene.silhouettes and scene.machine_lamp.material_override!=shell_material,"Silhouette mode replaces surface detail")
	if OS.get_environment("HOLDFAST_CAPTURE_BENCHMARK")=="1":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/holdfast-inspection-machine.png")
	scene.toggle_silhouettes()
	expect(scene.machine_lamp.material_override==shell_material,"Inspection restores original materials exactly")
	var tool_rest: Transform3D = scene.machine_states.shoulder.transform
	var emitter_rest: Transform3D = scene.machine_states.emitter.transform
	var cargo_before: bool = scene.cargo.visible
	for state in range(1,6):
		scene.cycle_machine_state()
		expect(scene.machine_states.index==state,"Machine review cycles in order")
		expect(scene.cargo.visible==cargo_before,"Pose changes preserve independent cargo visibility")
		for material in scene.machine_states.lamps:
			expect(material.emission_enabled==(state<4),"All work lamps power down when disabled or destroyed")
		expect(scene.machine_states.emitter_material.emission_enabled==(state==3),"Hostile alone never charges emitter")
		for mesh in scene.machine.find_children("*","MeshInstance3D",true,false):
			var local: Transform3D = scene.machine.global_transform.affine_inverse()*mesh.global_transform
			var part: AABB = local*mesh.get_aabb()
			expect(part.position.x>=-0.475 and part.end.x<=0.475 and part.position.z>=-0.48 and part.end.z<=0.48,"Review poses stay within documented resting footprint")
		if state==3:
			expect(scene.machine_states.emitter.transform!=emitter_rest,"Charge has a geometric cue")
		expect(scene.machine_states.wreck.visible==(state==5),"Only destroyed shows collapsed asset")
		for child in scene.machine_states.intact_roots:
			expect(child.visible==(state!=5),"Destroyed hides intact root; other states restore it")
		if state==5:
			expect(scene.cargo_label.disabled and not scene.cargo.is_visible_in_tree(),"Wreck hides cargo and disables its review control")
			scene.toggle_cargo()
			expect(scene.cargo.visible==cargo_before,"Wreck does not discard remembered cargo choice")
		if state==4:
			expect(scene.machine_states.shoulder.transform!=tool_rest,"Disabled has a distinct static tool pose")
		if OS.get_environment("HOLDFAST_CAPTURE_BENCHMARK")=="1" and state>=3:
			scene.camera.size = 2.5
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/private/tmp/machine-a-state-%d.png" % state)
	if OS.get_environment("HOLDFAST_CAPTURE_BENCHMARK")=="1":
		var was_night: bool = scene.night
		scene.night = true
		scene.apply_light()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/machine-a-wreck-night.png")
		scene.night = was_night
		scene.apply_light()
	# State changes while inspecting silhouettes must not reveal emissive materials.
	scene.toggle_silhouettes()
	scene.cycle_machine_state()
	expect(scene.machine_lamp.material_override.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED,"State changes retain silhouette view")
	scene.toggle_silhouettes()
	expect(not scene.cargo_label.disabled and scene.cargo.is_visible_in_tree()==cargo_before,"Returning from wreck restores cargo control and choice")
	expect(scene.machine_states.index==0 and scene.machine_states.shoulder.transform==tool_rest,"Full cycle restores working pose exactly")
	expect(scene.machine_states.emitter.transform==emitter_rest,"Full cycle resets charge geometry")
	expect(scene.machine_lamp.material_override.emission_enabled,"Silhouette exit restores updated powered material")
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
