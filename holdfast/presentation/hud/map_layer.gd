extends RefCounted
## Map-only drawing for the desktop HUD. Panels, buttons and text live in game_shell.gd;
## this draws only what belongs on the board, using the same renderers as the legacy view.
const BoardView = preload("res://presentation/board_view.gd")
const OverlayView = preload("res://presentation/tactical_overlay.gd")
const MachineView = preload("res://presentation/machine_view.gd")
const CivilianView = preload("res://presentation/civilian_view.gd")
const Command = preload("res://systems/civilian_command.gd")

## Region of the legacy page that holds the board and its coordinate labels.
const CROP := Rect2(24, 68, 776, 608)

static func render(board) -> void:
	var font: Font = board.font
	var projection = board.board_projection
	board.draw_rect(CROP, Color("0e1412"))
	BoardView.render(board,font,projection,board.board_view_snapshot())
	var custom: bool = board.has_method("draw_mission_layer")
	if custom: board.draw_mission_layer(projection,font)
	var path: Array[Vector2i] = []
	if not board.sight_mode and not board.drop_mode:
		path = board.path_to(board.hovered_cell)
	var target: Vector2i = board.sight_target()
	OverlayView.render(board,projection,board.tactical_overlay_snapshot(path,target))
	board.draw_targets()
	for index in range(board.soldiers.size()):
		if board.soldier_visible(index):
			board.draw_soldier_marker(index,board.cell_to_local(board.soldiers[index]["cell"])+Vector2(18,18))
	if not custom: MachineView.render(board,font,projection,board.machine_view_snapshot())
	CivilianView.render(board,font,projection,board.civilian_view_snapshot())
	# Label the machine (the only enemy on Farm Road) so it reads as a target.
	if board.machine_present():
		var at: Vector2 = projection.cell_anchor(board.enemies[0]["cell"])
		board.draw_rect(Rect2(at+Vector2(-37,-15),Vector2(110,14)),Color(0.05,0.08,0.07,0.85))
		board.draw_string(font,at+Vector2(-37,-4),"MACHINE %d/16" % board.enemies[0]["hp"],HORIZONTAL_ALIGNMENT_CENTER,110,11,Color("ff8a80") if board.machine["hostile"] else Color("e6a2c7"))
	# Name the civilian exit so it isn't confused with the squad's EXIT squares.
	var civ_exit: Vector2 = projection.cell_anchor(board.civilian_exit())
	board.draw_rect(Rect2(civ_exit+Vector2(-22,-15),Vector2(80,14)),Color(0.05,0.08,0.07,0.85))
	board.draw_string(font,civ_exit+Vector2(-22,-4),"CIVILIANS",HORIZONTAL_ALIGNMENT_CENTER,80,11,Color("8be6de"))
	# Civilian command: MSG's voice range and each group's fear level.
	if board.command_model == "authority" and not board.ended:
		var msg: int = Command.msg_index(board.soldiers)
		if Command.standing(board.soldiers,msg):
			var origin: Vector2i = board.soldiers[msg]["cell"]
			var gold := Color(0.95,0.8,0.42,0.55)
			for x in range(origin.x-Command.VOICE_RANGE,origin.x+Command.VOICE_RANGE+1):
				for y in range(origin.y-Command.VOICE_RANGE,origin.y+Command.VOICE_RANGE+1):
					var cell := Vector2i(x,y)
					if Command.distance(origin,cell) > Command.VOICE_RANGE or not board.cell_is_in_bounds(cell): continue
					var at: Vector2 = projection.cell_anchor(cell)
					for direction in Command.DIRECTIONS:
						var outside: Vector2i = cell+direction
						if Command.distance(origin,outside) <= Command.VOICE_RANGE and board.cell_is_in_bounds(outside): continue
						var size: float = board.CELL_SIZE
						var a := at
						var b := at+Vector2(size,0)
						if direction == Vector2i.RIGHT:
							a = at+Vector2(size,0)
							b = at+Vector2(size,size)
						elif direction == Vector2i.LEFT:
							b = at+Vector2(0,size)
						elif direction == Vector2i.DOWN:
							a = at+Vector2(0,size)
							b = at+Vector2(size,size)
						board.draw_line(a,b,gold,2)
		for cohort in board.cohorts:
			if cohort["status"] != "active": continue
			var fear: int = Command.level(cohort)
			if fear == 0: continue
			var spot: Vector2 = projection.cell_anchor(cohort["cell"])+Vector2(22,-2)
			var tint := Color("ffb75a") if fear == 1 else Color("ff5c4d")
			board.draw_rect(Rect2(spot,Vector2(18,14)),Color(0.05,0.05,0.05,0.85))
			board.draw_string(font,spot+Vector2(0,12),"!" if fear == 1 else "!!",HORIZONTAL_ALIGNMENT_CENTER,18,12,tint)
	# Breaker: locked civilian gates after isolation.
	if board.disabled():
		for gate in board.GATES:
			var origin: Vector2 = projection.cell_anchor(gate)
			board.draw_rect(Rect2(origin+Vector2(2,2),Vector2(32,32)),Color("ea9670"),false,2)
			board.draw_string(font,origin+Vector2(0,24),"LOCK",HORIZONTAL_ALIGNMENT_CENTER,36,10,Color("ea9670"))
	# Protocol: agreed diversion waypoints.
	if board.protocol["route_set"] and not board.protocol["betrayed"]:
		for waypoint in board.DIVERSION:
			board.draw_rect(Rect2(projection.cell_anchor(waypoint)+Vector2(1,1),Vector2(34,34)),Color("8be6de"),false,2)
	# Rescue: casualty condition markers.
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		if not board.soldier_visible(index): continue
		var center: Vector2 = projection.cell_anchor(soldier["cell"])+Vector2(18,18)
		var condition: String = soldier.get("condition","active")
		if condition == "dead":
			board.draw_line(center-Vector2(11,11),center+Vector2(11,11),Color("f07878"),3)
		elif condition == "critical":
			board.draw_string(font,center+Vector2(7,-6),str(soldier.get("bleed",0)),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ffb75a"))
		elif condition == "stable":
			board.draw_string(font,center+Vector2(7,-6),"+",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("8be6de"))
		if soldier.get("carrying",-1) >= 0:
			board.draw_string(font,center+Vector2(-15,22),"+"+board.soldiers[soldier["carrying"]]["mark"],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8be6de"))
		if index == board.rescue_target and board.casualty_available(index):
			board.draw_arc(center,20,0,TAU,24,Color("ffb75a"),2)
	# Hover highlight so the player always knows which square the mouse is on.
	if board.cell_is_in_bounds(board.hovered_cell):
		var hover := Rect2(projection.cell_anchor(board.hovered_cell),Vector2.ONE*board.CELL_SIZE)
		board.draw_rect(hover.grow(-1),Color(1,1,1,0.55),false,2)
		if board.drop_mode:
			board.draw_rect(hover.grow(-4),Color(0.55,0.9,0.87,0.25))
