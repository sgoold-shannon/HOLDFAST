extends "res://tests/test_support.gd"
## Mission 10 · The Dam: pressure and breach, valves and floods, power and the footbridge,
## the habitat (repair, stabilize), cargo by hand and by transport, the Fallow on the crest,
## Kesh's channel carry-ins and the record.
const Dam = preload("res://systems/dam_works.gd")
const FallowCutter = preload("res://systems/fallow_cutter.gd")
const Record = preload("res://systems/campaign_record.gd")
const Arc = preload("res://data/campaign_arc.gd")

func dam_board(label: String, record: String = ""):
	var board = load("res://the_dam.tscn").instantiate()
	board.auto_resume = false
	board.record_path = record
	root.add_child(board)
	board.report_path = test_path(label+"-report.save")
	board.completion_path = test_path(label+"-complete.save")
	board.campaign_path = test_path(label+"-campaign.save")
	board.command_model = "authority"
	board.finish_opening()
	return board

func turn(board, round_number: int) -> void:
	board.phase = round_number
	board.last_enemy_phase = round_number-1
	board.resolve_enemy_turn()

func run() -> void:
	var board = dam_board("dm-load")
	expect(board.mission_definition().mission_id == "the_dam" and not board.machine_present(),"The Dam loads without the Farm Road machine")
	expect(Arc.mission(10)["status"] == "playable" and Arc.mission(10).has("briefing"),"Mission 10 is playable with a briefing")
	expect(board.dam["pressure"] == Dam.START_PRESSURE and board.dam["channel"] == "partial" and not board.transport["present"],"Defaults: pressure 2, partial channel, no transport")
	expect(board.cohorts[2]["penned"] and board.mission_definition().walls.has(board.BRIDGE[0]),"Dependents penned; footbridge down without power")
	board.free()

	board = dam_board("dm-pressure")
	for r in range(1,3): turn(board,r)
	expect(board.dam["pressure"] == 4 and not board.dam["breached"],"Pressure climbs one a round")
	board.free()

	board = dam_board("dm-breach")
	board.dam["pressure"] = Dam.BREACH-1
	board.soldiers[0]["cell"] = Vector2i(8,2)
	turn(board,4)
	expect(board.dam["breached"] and board.cohorts[0]["status"] == "stranded" and board.cohorts[2]["status"] == "stranded","Breach at 8 sweeps the lowland and floods the habitat")
	for i in range(3): await process_frame
	expect(board.ended and board.end_reason == "Dam breached","A breach ends the operation (%s, %s)" % [board.ended,board.end_reason])
	board.free()

	board = dam_board("dm-valve")
	board.select_soldier(1)
	board.soldiers[1]["cell"] = board.WEST_VALVE+Vector2i(0,1)
	board.dam["pressure"] = 5
	expect(board.open_valve("west") and board.dam["pressure"] == 2 and Dam.flooding(board.dam,"west",board.phase),"West valve: pressure -3, the lowland floods")
	expect(board.valve_reason("west").contains("already"),"One release per side while it runs")
	expect(not board.is_walkable(Vector2i(4,11)),"Flooded ground is impassable")
	board.free()

	board = dam_board("dm-flood-hurts")
	board.soldiers[2]["cell"] = Vector2i(4,12)
	var shp: int = board.soldiers[2]["hp"]
	board.soldiers[1]["cell"] = board.EAST_VALVE+Vector2i(0,1)
	board.select_soldier(1)
	board.flood_zone("west")
	expect(board.soldiers[2]["hp"] < shp,"Anyone in the flooded channel takes damage")
	board.free()

	board = dam_board("dm-power")
	board.soldiers[0]["cell"] = board.TURBINE+Vector2i(1,0)
	board.select_soldier(0)
	expect(board.assign_power("bridge") and not board.mission_definition().walls.has(board.BRIDGE[0]),"Footbridge power raises the bridge")
	board.soldiers[0]["ap"] = 4
	board.assign_power("trunk")
	board.assign_power("trunk")
	expect(Dam.power_used(board.dam) == 3 and board.power_reason("life").contains("All 3"),"Three units: a fourth is refused")
	board.soldiers[0]["ap"] = 4
	board.assign_power("trunk")
	expect(board.dam["power"]["trunk"] == 0,"The trunk steps back to 0 when full")
	board.select_soldier(1)
	expect(board.power_reason("life").contains("MSG"),"Only MSG assigns power")
	board.free()

	board = dam_board("dm-stabilize")
	board.soldiers[1]["cell"] = board.CONSOLE+Vector2i(-1,0)
	board.select_soldier(1)
	expect(board.stabilize_reason().contains("life support"),"Stabilizing needs life support power")
	board.dam["power"]["life"] = true
	board.stabilize_habitat()
	expect(board.stabilize_habitat() and board.dam["stabilized"] and board.cohorts[2]["status"] == "extracted","Two steps: the dependents are safe")
	board.free()

	board = dam_board("dm-crates")
	board.soldiers[3]["cell"] = board.CRATES[0]+Vector2i(1,0)
	board.select_soldier(3)
	expect(board.handle_crate() and board.carried_by(3) == 0,"A soldier shoulders a crate")
	expect(board.fire_block_reason().contains("carrying"),"No firing while carrying")
	board.soldiers[3]["cell"] = board.TRUNK+Vector2i(-1,0)
	board.soldiers[3]["ap"] = 2
	expect(board.handle_crate() and board.dam["delivered"] == 1,"Set it down at the trunk tunnel")
	board.free()

	board = dam_board("dm-fallow")
	turn(board,2)
	expect(board.fallow["stage"] == "waiting","No Fallow before round 3")
	turn(board,3)
	expect(board.fallow["stage"] == "active" and not board.fallow["marked"].is_empty(),"Round 3: the cutter climbs on and marks the crest")
	var marks: int = board.fallow["marked"].size()
	var before: int = board.dam["pressure"]
	turn(board,4)
	expect(marks > 0 and board.dam["pressure"] == before+2,"A crest fold adds pressure on top of the round")
	board.soldiers[1]["cell"] = board.FALLOW_NODE+Vector2i(0,1)
	board.select_soldier(1)
	expect(board.interrupt_crest_node(),"The node can be interrupted")
	before = board.dam["pressure"]
	turn(board,5)
	expect(board.dam["pressure"] == before+1,"Interrupted: the marks hold, only the round's +1")
	board.free()

	var auth_file := test_path("dm-auth-record.save")
	Record.save_record(auth_file,{"version":1,"missions":{7:{"controller":true,"habitat":"strained","rig":"present"},4:{"security":{"killed":0}}}})
	board = dam_board("dm-auth",auth_file)
	expect(board.dam["channel"] == "authenticated" and board.dam["needs_repair"] and board.transport["kind"] == "rig","Quarry controller, strained habitat, rig: authenticated, repair, rig")
	board.soldiers[0]["cell"] = Vector2i(8,2)
	board.select_soldier(0)
	expect(board.valve_reason("east") == "","Authenticated: MSG opens valves from anywhere on the crest")
	board.dam["power"]["life"] = true
	board.soldiers[1]["cell"] = board.CONSOLE+Vector2i(-1,0)
	board.select_soldier(1)
	expect(board.stabilize_reason().contains("junction"),"Strained habitat: repair the junction first")
	board.free()
	var hard_file := test_path("dm-hard-record.save")
	Record.save_record(hard_file,{"version":1,"missions":{7:{"habitat":"lost"},4:{"security":{"killed":0}}}})
	board = dam_board("dm-hard",hard_file)
	expect(board.dam["channel"] == "hardened" and board.transport["kind"] == "cart","Lost habitat: hardened channel; Interchange security alive: cart")
	expect(Dam.guidance(board.dam,board).contains("Stabilize"),"Hardened: no guidance until the families are stable")
	board.free()

	board = dam_board("dm-record")
	board.soldiers[0]["extracted"] = true
	board.request_close()
	board.request_close()
	for i in range(4): await process_frame
	var entry: Dictionary = Record.dam_entry(board)
	expect(board.result_ready and entry["mission"] == 10 and entry["dependents"] == "left" and not entry["breached"],"The Dam result records the habitat and the dam")
	expect(Record.carry_forward_dam(entry).size() >= 3,"The Dam explains what carries forward")
	expect(board.result_title().begins_with("THE DAM"),"Results are titled The Dam")
	board.free()
	print("THE DAM FAILURES: ",failures)
	quit(1 if failures else 0)
