extends "res://tests/test_support.gd"
## Mission 07 · Quarry: the three platform plans, debris and the live trunk, the tunnel collapse,
## elevation, the Drive Rig, carry-ins, record and the Act II close.
const Works = preload("res://systems/quarry_works.gd")
const Rig = preload("res://systems/drive_rig.gd")
const Record = preload("res://systems/campaign_record.gd")
const Arc = preload("res://data/campaign_arc.gd")

func quarry(label: String, record: String = ""):
	var board = load("res://quarry.tscn").instantiate()
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
	var board = quarry("q-load")
	expect(board.mission_definition().mission_id == "quarry" and not board.machine_present(),"Quarry loads without the Farm Road machine")
	expect(Arc.mission(7)["status"] == "playable" and Arc.mission(7)["briefing"]["intel"].contains("occupied Drover habitat"),"Mission 07 briefs the habitat as corroborated fact")
	expect(not board.rig["present"] and board.works["controller_needed"] == 3,"No record: no rig, 3 controller steps")
	expect(board.in_tunnel(board.cohorts[0]["cell"]) and board.in_tunnel(board.cohorts[1]["cell"]),"Groups A and B start in the haul tunnel")
	var long_way: Array = board.civilian_path(board.cohorts[0]["cell"],board.civilian_exit())
	expect(long_way.size() > 15 and long_way.has(board.AIRSHAFT),"With the mouth blocked, the only way out is the airshaft")
	var down: Dictionary = board.sight_preview(Vector2i(10,4),Vector2i(10,9))
	var up: Dictionary = board.sight_preview(Vector2i(10,9),Vector2i(10,4))
	expect(down["elevation"] == 10 and up["elevation"] == -10,"Elevation: +10 shooting down, −10 shooting up")
	board.free()

	board = quarry("q-demolish")
	board.soldiers[1]["cell"] = board.PLATFORM+Vector2i(-1,0)
	board.select_soldier(1)
	expect(board.set_charge() and board.set_charge() and board.works["charge_set"],"Setting the charge takes 2 AP")
	turn(board,1)
	expect(board.works["destroyed"] and board.works["debris"].is_empty() and not board.FIXTURES.has(board.DEBRIS[0]),"The blast clears the west mouth")
	expect(board.soldiers[1]["hp"] < 8,"Anyone next to the platform takes the blast")
	expect(Works.habitat(board.works) == "lost","Demolition loses the habitat for good")
	var short_way: Array = board.civilian_path(board.cohorts[0]["cell"],board.civilian_exit())
	expect(short_way.size() < 12,"The tunnel groups get the short way out")
	board.free()

	board = quarry("q-isolate")
	board.soldiers[2]["cell"] = board.DEBRIS[0]+Vector2i(0,-1)
	board.select_soldier(2)
	expect(not board.dig() and board.status_text.contains("live trunk"),"No digging into the live trunk")
	board.soldiers[1]["cell"] = board.JB_WEST+Vector2i(0,-1)
	board.select_soldier(1)
	expect(not board.confirm_safe_off(),"Safe-off needs both junction boxes")
	expect(board.kill_junction() and board.works["jb_west"],"Junction box West")
	board.soldiers[3]["cell"] = board.JB_EAST+Vector2i(0,-1)
	board.select_soldier(3)
	expect(board.kill_junction() and board.works["jb_east"],"Junction box East")
	board.soldiers[3]["cell"] = board.PLATFORM+Vector2i(1,0)
	expect(board.confirm_safe_off() and board.works["isolated"] and Works.habitat(board.works) == "strained","Safe-off isolates the platform; the habitat runs on reserve")
	board.select_soldier(2)
	expect(board.dig() and board.works["debris"][board.DEBRIS[0]] == 1,"Digging takes 2 AP a square")
	board.dig()
	expect(not board.FIXTURES.has(board.DEBRIS[0]),"And then the square is clear")
	board.free()

	board = quarry("q-controller")
	board.soldiers[1]["cell"] = board.PLATFORM+Vector2i(0,-1)
	board.select_soldier(1)
	expect(board.recover_controller() and not board.recover_controller(),"One controller step a round")
	board.phase = 2
	board.soldiers[1]["ap"] = 2
	board.recover_controller()
	board.phase = 3
	board.soldiers[1]["ap"] = 2
	expect(board.recover_controller() and board.works["controller"] and Works.habitat(board.works) == "powered","Three rounds: controller recovered, habitat keeps power")
	board.free()

	board = quarry("q-collapse")
	turn(board,Works.COLLAPSE_ROUND)
	expect(board.works["collapsed"] and board.cohorts[0]["status"] == "stranded" and board.works["lost"].has("A"),"Groups still in the tunnel are lost when it comes down")
	board.free()

	var record_file := test_path("q-carry-record.save")
	Record.save_record(record_file,{"version":1,"missions":{1:{"machine":"diverted"},4:{"cargo":"seized"},5:{"archive":"partial"},6:{"convoy":"monitored","squad":[{"name":"MSG","condition":"active"},{"name":"Ortiz","condition":"active"},{"name":"Bell","condition":"stable"},{"name":"Park","condition":"active"}]}}})
	board = quarry("q-carry",record_file)
	expect(board.rig["present"] and board.works["controller_needed"] == 4 and board.works["debris"][board.DEBRIS[0]] == 1,"Carry-ins: rig, missing part, surveyed debris")
	expect(board.hatch_open and not board.WALL_CELLS.has(board.HATCH),"The Drover hatch opens a shortcut")
	expect(board.soldiers[2]["hp"] == 4,"Hospital wounds carry in")
	board.select_soldier(0)
	board.soldiers[0]["cell"] = board.rig["cell"]+Vector2i(-2,0)
	expect(board.order_rig("brace") and board.sheltered_from_fallow(board.rig["cell"]+Vector2i(0,1)),"A braced rig shelters the squares next to it")
	expect(not board.order_rig("move"),"One rig order a turn")
	board.free()

	board = quarry("q-record")
	board.soldiers[0]["extracted"] = true
	board.request_close()
	board.request_close()
	for i in range(4): await process_frame
	var entry: Dictionary = Record.quarry_entry(board)
	expect(board.result_ready and entry["mission"] == 7 and entry["platform"] == "running" and entry["habitat"] == "powered","Quarry result records the platform and habitat")
	var carry: Array = Record.carry_forward_quarry(entry)
	expect(carry.back().begins_with("ACT II COMPLETE") and Record.act_two_complete({"missions":{7:entry}}),"Quarry closes Act II")
	expect(board.debrief_pages()[1]["speaker"].begins_with("MSG") and board.debrief_pages().back()["speaker"].begins_with("ACT II COMPLETE"),"Debrief: what MSG knew, recommended and saved; then the Act II close")
	expect(board.result_title().begins_with("QUARRY"),"Results are titled Quarry")
	board.free()
	print("QUARRY FAILURES: ",failures)
	quit(1 if failures else 0)
