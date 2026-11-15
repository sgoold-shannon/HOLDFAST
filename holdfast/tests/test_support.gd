extends SceneTree
## Isolated legal-action test helpers. Never resume or write the player's campaign.
var failures := 0
var logs: Array = []
var cost := 0
var output_dir := ""
func _initialize() -> void:
	call_deferred("setup_test")
func setup_test() -> void:
	var cache := OS.get_environment("HOLDFAST_TEST_OUTPUT")
	if cache == "": cache = OS.get_cache_dir()
	output_dir = cache.path_join("holdfast-tests-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()])
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		push_error("Cannot create isolated test output directory")
		quit(1)
		return
	call_deferred("run")
func test_path(name: String) -> String:
	return output_dir.path_join(name)
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	push_error("Run a test script, not test_support.gd directly")
	quit(1)
func invoke(board, action: String, args: Array = []):
	var before := 0
	for soldier in board.soldiers: before += soldier["ap"]
	var actor: String = board.soldiers[board.active_soldier]["name"] if board.active_soldier >= 0 else "none"
	var result = board.callv(action,args)
	var after := 0
	for soldier in board.soldiers: after += soldier["ap"]
	cost += maxi(0,before-after)
	logs.append({"round":board.phase,"actor":actor,"action":action,"args":str(args),"result":result,"ap":maxi(0,before-after),"message":board.status_text})
	return result
func select(board,index: int) -> void:
	board.select_soldier(index)
func path_to_exit(board, start: Vector2i) -> Array:
	var frontier: Array = [start]
	var previous := {start:Vector2i(-1,-1)}
	var cursor := 0
	while cursor < frontier.size():
		var cell: Vector2i = frontier[cursor]
		cursor += 1
		if board.extraction_cell(cell) and (board.soldier_at(cell) < 0 or cell == start):
			var route: Array = []
			while cell != start:
				route.push_front(cell)
				cell = previous[cell]
			return route
		for direction in board.DIRECTIONS:
			var next: Vector2i = cell+direction
			if not previous.has(next) and board.is_walkable(next):
				previous[next] = cell
				frontier.append(next)
	return []
func evacuate(board,index: int) -> void:
	if not board.soldier_can_act(index): return
	select(board,index)
	for step in range(3):
		if board.soldiers[index]["ap"] < 1 or board.soldiers[index]["extracted"]: return
		var start: Vector2i = board.soldiers[index]["cell"]
		if board.extraction_cell(start):
			invoke(board,"try_extract")
			return
		var path := path_to_exit(board,start)
		if path.is_empty(): return
		var limit: int = 8 if board.soldiers[index]["ap"] == 2 else 4
		if board.soldiers[index]["carrying"] >= 0: limit = 2
		var destination := Vector2i(-1,-1)
		for distance in range(mini(limit,path.size()),0,-1):
			var cell: Vector2i = path[distance-1]
			if board.soldier_at(cell) < 0 and cell != board.next_machine_cell() and cell != board.machine["pending_shot"] and board.move_cost(cell) > 0:
				destination = cell
				break
		if destination == Vector2i(-1,-1): return
		if not invoke(board,"try_move",[destination]):
			failures += 1
			return
func press(board,key: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	board._unhandled_input(event)
func click(board,point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = board.get_global_transform_with_canvas()*point
	board._unhandled_input(event)
func new_board(label: String):
	var board = load("res://farm_final.tscn").instantiate()
	board.auto_resume = false
	board.campaign_path = test_path(label + "-campaign.save")
	root.add_child(board)
	board.report_path = test_path(label + "-report.save")
	board.completion_path = test_path(label + "-complete.save")
	return board
