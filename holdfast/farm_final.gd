extends "res://farm_return.gd"
const ENDING_RECT := Rect2(60,945,320,40)

func return_scene_path() -> String:
	return "res://farm_final.tscn"

func ending_available() -> bool:
	return result_ready and return_state["active"] and not retry_required() and campaign["committed"]

func open_ending_test() -> bool:
	if not ending_available(): return false
	var test = load("res://ending_test.tscn").instantiate()
	test.source_snapshot = encounter_snapshot()
	test.return_board = self
	get_parent().add_child(test)
	hide()
	set_process_unhandled_input(false)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if ending_available():
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_Z or (roster_open and event.keycode == KEY_ENTER)):
			open_ending_test()
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
			if (roster_open and DEPLOY_RECT.has_point(point)) or (not roster_open and scene_view == "" and ENDING_RECT.has_point(point)):
				open_ending_test()
				return
	super._unhandled_input(event)

func _draw() -> void:
	super._draw()
	if not ending_available() or scene_view != "": return
	var rect := DEPLOY_RECT if roster_open else ENDING_RECT
	draw_rect(rect,Color("344f46"))
	draw_string(font,rect.position+Vector2(10,29),"Ending logic test [Z]",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-20,19,Color.WHITE)
