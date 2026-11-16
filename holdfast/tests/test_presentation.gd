extends "res://tests/test_support.gd"
const InputMapView = preload("res://presentation/tactical_input.gd")
const ActorView = preload("res://presentation/actor_view.gd")
const OverlayView = preload("res://presentation/tactical_overlay.gd")
const BoardView = preload("res://presentation/board_view.gd")
class RecordingCanvas extends RefCounted:
	func draw_multiline_string(_font, point, value, alignment, width, size, _max_lines, color): strings.append([point,value,alignment,width,size,color])
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

	for panel_name in ["story_panel","roster_panel","results_panel","rescue_panel","breaker_panel","protocol_panel"]:
		var panel_data_new: Dictionary = farm.call(panel_name+"_snapshot")
		var data_before := panel_data_new.duplicate(true)
		var encounter_before: Dictionary = farm.encounter_snapshot()
		var recorder := RecordingCanvas.new()
		load("res://presentation/"+panel_name+".gd").render(recorder,farm.font,farm.board_projection,panel_data_new)
		expect(not recorder.strings.is_empty(),panel_name+" renders content")
		expect(panel_data_new==data_before,panel_name+" leaves input untouched")
		expect(farm.encounter_snapshot()==encounter_before,panel_name+" cannot alter encounter")
	farm.scene_view = "opening"
	farm.scene_page = 0
	var opening := RecordingCanvas.new()
	preload("res://presentation/story_panel.gd").render(opening,farm.font,farm.board_projection,farm.story_panel_snapshot())
	labels_found.clear()
	for label in opening.strings: labels_found.append(label[1])
	expect(labels_found.has("Choose 1–3 above"),"Opening choice prompt preserved")
	farm.history_page = 999
	var roster_data: Dictionary = farm.roster_panel_snapshot()
	expect(roster_data["history_page"]==maxi(1,ceili(roster_data["details"].size()/9.0))-1,"Roster page is clamped before rendering")
	var breaker_data: Dictionary = farm.breaker_panel_snapshot()
	breaker_data["isolate_pending"] = true
	var confirmation := RecordingCanvas.new()
	preload("res://presentation/breaker_panel.gd").render(confirmation,farm.font,farm.board_projection,breaker_data)
	labels_found.clear()
	for label in confirmation.strings: labels_found.append(label[1])
	expect(labels_found.has("Confirm isolate [I]") and labels_found.has("Cancel [Esc]"),"Breaker confirmation controls preserved")

	for overlay_name in ["return_overlay","ending_overlay"]:
		var data: Dictionary = farm.call(overlay_name+"_snapshot")
		var before_data := data.duplicate(true)
		var recorder := RecordingCanvas.new()
		load("res://presentation/"+overlay_name+".gd").render(recorder,farm.font,farm.board_projection,data)
		expect(data==before_data,"Mission overlay preserves display data")
	var decoder = preload("res://presentation/modal_input.gd")
	var mouse := InputEventMouseButton.new()
	mouse.pressed = true
	mouse.button_index = MOUSE_BUTTON_LEFT
	var rect := Rect2(10,10,100,40)
	expect(decoder.command(mouse,Vector2(20,20),{},{"button":rect},[rect])=="button","Modal buttons take precedence over rows")
	expect(decoder.command(mouse,Vector2(20,20),{},{},[rect])=="row:0","Modal row selection")
	mouse.button_index = MOUSE_BUTTON_RIGHT
	expect(decoder.command(mouse,Vector2(20,20),{},{"button":rect})=="","Right clicks ignored")
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	key.echo = true
	expect(decoder.command(key,Vector2.ZERO,{KEY_ENTER:"next"},{})=="","Modal key repeats ignored")
	key.echo = false
	key.pressed = false
	expect(decoder.command(key,Vector2.ZERO,{KEY_ENTER:"next"},{})=="","Modal key releases ignored")
	var prior_phase: int = farm.phase
	farm.scene_view = "opening"
	farm.roster_open = false
	press(farm,KEY_N)
	expect(farm.phase==prior_phase,"Opening consumes gameplay keys")
	farm.roster_open = true
	farm.roster_index = 0
	farm.history_page = 3
	press(farm,KEY_DOWN)
	expect(farm.roster_index==1 and farm.history_page==0,"Roster selection resets history page")
	press(farm,KEY_N)
	expect(farm.phase==prior_phase,"Roster consumes gameplay keys")
	press(farm,KEY_ESCAPE)
	expect(not farm.roster_open and farm.scene_view=="opening","Closing roster preserves underlying dialogue")
	farm.free()
	print("PRESENTATION BOUNDARY FAILURES: ",failures)
	quit(1 if failures else 0)
