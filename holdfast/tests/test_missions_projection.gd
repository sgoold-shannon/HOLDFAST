extends "res://tests/test_support.gd"
const Objectives = preload("res://systems/mission_objectives.gd")
const BoardProjection = preload("res://presentation/grid_projection.gd")
const Origin = preload("res://missions/farm_road.tres")
const ReturnMap = preload("res://missions/northbound_return.tres")
const Sandbox = preload("res://missions/tactical_sandbox.tres")
const Sight = preload("res://tactical_rules.gd")
func in_bounds(mission: Resource, cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= mission.grid_size.x and cell.y >= 1 and cell.y <= mission.grid_size.y
func run() -> void:
	for mission in [Origin,ReturnMap,Sandbox]:
		expect(mission.squad_spawns.size()==4 and mission.civilian_spawns.size()==3,"Expected initial roster for " + mission.mission_id)
		var cells: Array = []
		for field in [mission.walls,mission.fixtures,mission.squad_spawns,mission.civilian_spawns,mission.squad_exits,mission.gates,mission.machine_patrol,mission.diversion,mission.cover_edges.keys(),mission.civilian_routes.values(),mission.disabled_routes.values()]:
			cells.append_array(field)
		cells.append(mission.machine_spawn)
		cells.append(mission.civilian_exit)
		for cell in cells: expect(in_bounds(mission,cell),"Authored cell lies inside mission grid")
	expect(Objectives.deadline(Origin,0)==10 and Objectives.deadline(Origin,4)==5,"Origin deadline reflects collection")
	expect(Objectives.deadline(ReturnMap,4)==10,"Return ignores old collection deadline")
	expect(Objectives.completion_reason(Origin,5,4,true,0)=="Road closed","Deadline retains priority over completed evacuation")
	expect(Objectives.completion_reason(Origin,4,4,true,0)=="Evacuation resolved","All evacuated closes early")
	expect(Objectives.completion_reason(Origin,4,4,true,4)=="","Civilian rescue continues after squad extraction")
	expect(Objectives.squad_exit(ReturnMap,Vector2i(9,1)) and not Objectives.squad_exit(ReturnMap,Vector2i(19,8)),"Return uses authored north exits")
	var custom: Resource = Sandbox.duplicate(true)
	custom.grid_size = Vector2i(8,8)
	custom.walls.assign([Vector2i(4,3)])
	custom.cover_edges = {Vector2i(2,2):"north"}
	custom.squad_spawns.assign([Vector2i(1,2),Vector2i(1,3),Vector2i(1,4),Vector2i(1,5)])
	custom.squad_exits.assign([Vector2i(8,8)])
	custom.machine_spawn = Vector2i(6,6)
	custom.closing_round = 6
	custom.closure_reason = "Tunnel sealed"
	custom.evacuation_reason = "Everyone safe"
	expect(Objectives.completion_reason(custom,6,0,true,0)=="Tunnel sealed","Custom objective data changes outcome without controller edits")
	expect(Objectives.completion_reason(custom,5,0,true,0)=="Everyone safe","Custom success reason is data")
	var board = load("res://battlefield.tscn").instantiate()
	board.mission_override = custom
	root.add_child(board)
	expect(board.soldiers[0]["cell"]==Vector2i(1,2) and board.enemies[0]["cell"]==Vector2i(6,6),"Controller reads spawns from custom map")
	expect(board.GRID_SIZE==Vector2i(8,8) and not board.cell_is_in_bounds(Vector2i(9,1)),"Bounds come from map definition")
	expect(not board.is_walkable(Vector2i(4,3)) and board.extraction_cell(Vector2i(8,8)),"Movement and extraction read custom layout")
	expect(not board.sight_preview(Vector2i(2,3),Vector2i(6,3))["clear"],"Sight uses custom wall instead of global Farm Road walls")
	expect(board.sight_preview(Vector2i(2,1),Vector2i(2,2))["cover_modifier"]==-25,"Cover uses custom mission data")
	expect(Sandbox.grid_size==Vector2i(20,16) and not Sandbox.walls.has(Vector2i(4,3)),"Custom definitions do not mutate shared baseline")
	board.queue_free()
	var checked := 0
	for axes in [[Vector2(36,0),Vector2(0,36)],[Vector2(36,18),Vector2(-36,18)]]:
		var projection = BoardProjection.new(Vector2(72,96),axes[0],axes[1])
		for y in range(1,17):
			for x in range(1,21):
				var cell := Vector2i(x,y)
				var center: Vector2 = projection.cell_anchor(cell)+(axes[0]+axes[1])*0.5
				expect(projection.point_to_cell(center)==cell,"Projection inverse finds original logical cell")
				expect(projection.point_to_cell(projection.cell_anchor(cell))==cell,"Exact tile boundary is stable")
				checked += 1
		var before_origin: Vector2 = projection.cell_anchor(Vector2i.ONE)-axes[0]*0.01
		expect(projection.point_to_cell(before_origin).x==0,"Out-of-grid clicks stay outside")
	expect(Sight.preview(Vector2i(2,3),Vector2i(6,3),custom)["distance"]==4,"Tactical distance remains four logical cells irrespective of projection")
	print("MISSION / PROJECTION CHECKS: ",checked," square/diamond cell round trips; failures ",failures)
	quit(1 if failures else 0)
