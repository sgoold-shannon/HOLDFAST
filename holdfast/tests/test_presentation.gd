extends "res://tests/test_support.gd"
const InputMapView = preload("res://presentation/tactical_input.gd")
const BoardView = preload("res://presentation/board_view.gd")
class RecordingCanvas extends RefCounted:
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
	board.free()
	print("PRESENTATION BOUNDARY FAILURES: ",failures)
	quit(1 if failures else 0)
