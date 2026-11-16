extends "res://tests/test_support.gd"
const InputMapView = preload("res://presentation/tactical_input.gd")
const ActorView = preload("res://presentation/actor_view.gd")
const OverlayView = preload("res://presentation/tactical_overlay.gd")
const BoardView = preload("res://presentation/board_view.gd")
class RecordingCanvas extends RefCounted:
	var circles: Array = []
	func draw_circle(center, radius, color): circles.append([center,radius,color])
	var polygons: Array = []
	var arcs: Array = []
	func draw_colored_polygon(points, color): polygons.append([points,color])
	func draw_arc(center, radius, start, finish, count, color, width): arcs.append([center,radius,start,finish,count,color,width])
	var rectangles: Array = []
	var strings: Array = []
	var lines: Array = []
	func draw_rect(rect, color, filled = true, width = -1): rectangles.append([rect,color,filled,width])
	func draw_string(_font, point, value, alignment, width, size, color): strings.append([point,value,alignment,width,size,color])
	func draw_line(start, finish, color, width): lines.append([start,finish,color,width])
func run() -> void:
	var keys := {KEY_K:"save",KEY_L:"load",KEY_E:"extract",KEY_F:"fire",KEY_R:"reload",KEY_T:"mode",KEY_N:"next",KEY_ESCAPE:"clear"}
	for key in keys:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = true
		expect(InputMapView.key_command(event)==keys[key],"Key maps to intended action")
		event.echo = true
		expect(InputMapView.key_command(event)=="","Repeats ignored")
		event.echo = false
		event.pressed = false
		expect(InputMapView.key_command(event)=="","Releases ignored")
	expect(InputMapView.key_command(InputEventMouseMotion.new())=="","Mouse is not a key command")
	var board = load("res://battlefield.tscn").instantiate()
	root.add_child(board)
	for command in board.tactical_buttons():
		var rect: Rect2 = board.tactical_buttons()[command]
		expect(InputMapView.button_command(rect.get_center(),board.tactical_buttons())==command,"Button maps to intended action")
	expect(InputMapView.button_command(Vector2(-100,-100),board.tactical_buttons())=="","Outside buttons ignored")
	board.select_soldier(0)
	var before: Dictionary = board.encounter_snapshot()
	var view: Dictionary = board.board_view_snapshot()
	var canvas := RecordingCanvas.new()
	BoardView.render(canvas,board.font,board.board_projection,view)
	expect(board.encounter_snapshot()==before,"Drawing leaves encounter unchanged")
	expect(canvas.lines.size()==8,"Four walls keep crossed markers")
	var exit_labels := 0
	for item in canvas.strings:
		if item[1]=="EXIT": exit_labels += 1
	expect(exit_labels==5,"All squad exits are labeled")
	view["walls"].clear()
	view["exits"].clear()
	view["costs"].clear()
	expect(board.WALL_CELLS.size()==4 and board.mission_definition().squad_exits.size()==5,"Display snapshot cannot mutate mission geometry")
	press(board,KEY_T)
	expect(board.sight_mode and board.board_view_snapshot()["costs"].is_empty(),"Aim hides movement costs")
	click(board,board.MODE_RECT.get_center())
	expect(not board.sight_mode,"Mode button returns to movement")
	press(board,KEY_ESCAPE)
	expect(board.active_soldier==-1 and board.pinned_target==board.NONE,"Clear action retains behavior")

	board.select_soldier(0)
	before = board.encounter_snapshot()
	for index in range(4):
		var actor_canvas := RecordingCanvas.new()
		ActorView.soldier(actor_canvas,board.font,Vector2(100,100),board.soldier_marker_snapshot(index))
		expect(actor_canvas.strings[0][1]==board.soldiers[index]["mark"],"Soldier label preserved")
		expect(actor_canvas.arcs.size()==(1 if index==0 else 0),"Selection ring only on active soldier")
		expect(actor_canvas.polygons.size()==(1 if index in [0,3] else 0),"Distinct soldier shapes preserved")
	var route: Array[Vector2i] = [Vector2i(3,6),Vector2i(4,6),Vector2i(5,6)]
	var overlay: Dictionary = board.tactical_overlay_snapshot(route,board.NONE)
	var route_canvas := RecordingCanvas.new()
	OverlayView.render(route_canvas,board.board_projection,overlay)
	expect(route_canvas.lines.size()==6,"Two route segments plus four cover edges")
	expect(route_canvas.lines[0][0]==board.cell_to_local(route[0])+Vector2(18,18),"Route begins at cell center")
	overlay["path"].clear()
	overlay["cover"].clear()
	expect(route.size()==3 and board.mission_definition().cover_edges.size()==4,"Overlay data detached")
	expect(board.encounter_snapshot()==before,"Markers and route display cannot mutate gameplay")
	board.sight_mode = true
	var target := Vector2i(14,6)
	var empty_path: Array[Vector2i] = []
	overlay = board.tactical_overlay_snapshot(empty_path,target)
	var aim_canvas := RecordingCanvas.new()
	OverlayView.render(aim_canvas,board.board_projection,overlay)
	expect(not overlay["aim"]["clear"] and not overlay["aim"]["blockers"].is_empty(),"Wall blocker supplied by tactical rules")
	expect(aim_canvas.lines[0][2]==Color("f27b79"),"Blocked aim uses warning color")
	expect(aim_canvas.rectangles.size()==overlay["aim"]["cells"].size()+overlay["aim"]["blockers"].size()+1,"Aim cells, blockers and target outline drawn")
	overlay = board.tactical_overlay_snapshot(empty_path,Vector2i(-1,-1))
	expect(overlay["aim"].is_empty(),"Out-of-bounds target has no aim overlay")

	board.free()
	var farm = new_board("panels")
	var unchanged: Dictionary = farm.encounter_snapshot()
	var renderer_cases := [
		[preload("res://presentation/machine_view.gd"),farm.machine_view_snapshot()],
		[preload("res://presentation/civilian_view.gd"),farm.civilian_view_snapshot()],
		[preload("res://presentation/civilian_panel.gd"),farm.civilian_panel_snapshot()],
		[preload("res://presentation/tactical_panel.gd"),farm.tactical_panel_snapshot(empty_path,farm.NONE)]]
	for entry in renderer_cases:
		var recorder := RecordingCanvas.new()
		var data: Dictionary = entry[1]
		var copy := data.duplicate(true)
		entry[0].render(recorder,farm.font,farm.board_projection,data)
		expect(data==copy,"Renderer preserves its snapshot")
		expect(not recorder.strings.is_empty(),"Renderer produces labels")
	expect(farm.encounter_snapshot()==unchanged,"All four renderers leave encounter unchanged")
	var machine_data: Dictionary = farm.machine_view_snapshot()
	machine_data["machine"]["hostile"] = true
	machine_data["machine"]["pending_shot"] = Vector2i(4,4)
	var hostile := RecordingCanvas.new()
	preload("res://presentation/machine_view.gd").render(hostile,farm.font,farm.board_projection,machine_data)
	expect(hostile.polygons[0][1]==Color("b34b42"),"Hostile machine hull is red")
	expect(not farm.machine["hostile"],"Machine display is detached")
	machine_data["present"] = false
	var absent := RecordingCanvas.new()
	preload("res://presentation/machine_view.gd").render(absent,farm.font,farm.board_projection,machine_data)
	expect(absent.polygons.is_empty(),"Absent machine has no hull")
	var civilian_data: Dictionary = farm.civilian_view_snapshot()
	civilian_data["cohorts"][0]["status"] = "extracted"
	var civilians := RecordingCanvas.new()
	preload("res://presentation/civilian_view.gd").render(civilians,farm.font,farm.board_projection,civilian_data)
	var labels_found := []
	for label in civilians.strings: labels_found.append(label[1])
	expect(not labels_found.has("A") and labels_found.has("B") and labels_found.has("C"),"Only active civilian badges are drawn")
	expect(farm.cohorts[0]["status"]=="active","Civilian display is detached")
	var panel_data: Dictionary = farm.civilian_panel_snapshot()
	panel_data["close_pending"] = true
	var close_canvas := RecordingCanvas.new()
	preload("res://presentation/civilian_panel.gd").render(close_canvas,farm.font,farm.board_projection,panel_data)
	labels_found.clear()
	for label in close_canvas.strings: labels_found.append(label[1])
	expect(labels_found.has("Confirm: leave them behind") and labels_found.has("Cancel"),"Early-close confirmation controls preserved")
	farm.free()
	print("PRESENTATION BOUNDARY FAILURES: ",failures)
	quit(1 if failures else 0)
