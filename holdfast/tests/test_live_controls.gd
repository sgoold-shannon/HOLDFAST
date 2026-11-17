extends "res://tests/test_support.gd"
func mouse(button: int, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = point
		event.pressed = down
		root.push_input(event,true)
	await process_frame
func run() -> void:
	var board = new_board("live-controls")
	current_scene = board
	await process_frame
	var ui = root.get_node("Readability")
	var fit: Button = ui.toolbar.get_child(0).get_child(1)
	await mouse(MOUSE_BUTTON_LEFT,fit.get_global_rect().get_center())
	expect(ui.fit_enabled and ui.magnification<1.0,"Mouse click reaches Fit through GUI input")
	var zoom: Button = ui.toolbar.get_child(0).get_child(3)
	await mouse(MOUSE_BUTTON_LEFT,zoom.get_global_rect().get_center())
	expect(ui.magnification==3.0,"Mouse click restores 3x")
	await mouse(MOUSE_BUTTON_WHEEL_DOWN,Vector2(400,400))
	expect(ui.origin.y>0,"Scroll input pans the map")
	var launch: Button = ui.get_child(0).get_child(0)
	await mouse(MOUSE_BUTTON_LEFT,launch.get_global_rect().get_center())
	expect(ui.preview_open,"Mouse click opens preview")
	var preview = root.get_child(root.get_child_count()-1)
	if preview is Node3D:
		var back: Button = preview.get_child(preview.get_child_count()-1).get_child(0)
		await mouse(MOUSE_BUTTON_LEFT,back.get_global_rect().get_center())
		await process_frame
		expect(not ui.preview_open and board.visible,"Mouse click returns from preview")
	await mouse(MOUSE_BUTTON_LEFT,fit.get_global_rect().get_center())
	expect(ui.fit_enabled,"Fit still responds after preview return")
	current_scene = null
	board.free()
	print("LIVE CONTROL FAILURES: ",failures)
	quit(1 if failures else 0)
