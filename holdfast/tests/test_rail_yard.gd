extends "res://tests/test_support.gd"
## Mission 05 · Rail Yard: pens and locks, the Collector's loading schedule, Sentry provocation,
## blackout, archive, handcar, the Grey trade, departure, record and carry-ins.
const Yard = preload("res://systems/grey_yard.gd")
const Record = preload("res://systems/campaign_record.gd")
const Arc = preload("res://data/campaign_arc.gd")

func rail(label: String, record: String = ""):
	var board = load("res://rail_yard.tscn").instantiate()
	board.auto_resume = false
	board.record_path = record
	root.add_child(board)
	board.report_path = test_path(label+"-report.save")
	board.completion_path = test_path(label+"-complete.save")
	board.campaign_path = test_path(label+"-campaign.save")
	board.command_model = "authority"
	board.finish_opening()
	return board

func grey_turn(board, round_number: int) -> void:
	board.phase = round_number
	board.last_enemy_phase = round_number-1
	board.resolve_enemy_turn()

func run() -> void:
	var board = rail("ry-load")
	expect(board.mission_definition().mission_id == "rail_yard" and not board.machine_present(),"Rail Yard loads without the Farm Road machine")
	expect(Arc.mission(5)["status"] == "playable" and Arc.mission(5).has("briefing"),"Mission 05 is playable with a briefing")
	expect(board.cohorts[0]["penned"] and board.cohorts[1]["penned"] and board.cohorts[2]["penned"],"All three groups start in pens")
	var start: Vector2i = board.cohorts[0]["cell"]
	board.order_exit(0)
	board.resolve_civilian_phase()
	expect(board.cohorts[0]["cell"] == start and board.cohorts[0]["status"] == "active","Penned groups don't move, whatever their orders")
	expect(board.archive["needed"] == 2,"Archive is a 2-step download by default")
	board.free()

	board = rail("ry-locks")
	board.soldiers[1]["cell"] = board.pens[0]["cell"]+Vector2i(1,0)
	board.select_soldier(1)
	expect(not board.bypass_lock(),"Only Bell bypasses a lock")
	expect(board.cut_lock() and not board.pens[0]["open"],"Cutting takes 2 AP: first cut")
	expect(board.cut_lock() and board.pens[0]["open"] and not board.cohorts[0]["penned"],"Second cut opens the pen")
	expect(board.cohorts[0]["panic"] >= 1 and board.yard["hostile"],"Freed groups come out shaken; opening a pen provokes the Sentries")
	board.soldiers[2]["cell"] = board.pens[1]["cell"]+Vector2i(-1,0)
	board.select_soldier(2)
	board.yard["dark"] = board.soldiers[2]["cell"]
	expect(not board.bypass_lock() and board.status_text.contains("Blackout"),"No lock bypass in a blackout")
	board.yard["dark"] = Yard.NONE
	expect(board.bypass_lock() and board.pens[1]["open"],"Bell bypasses a lock for 1 AP")
	board.free()

	board = rail("ry-collector")
	grey_turn(board,2)
	expect(board.yard["load"].is_empty(),"No loading before round 3")
	grey_turn(board,3)
	var marked: int = board.yard["load"]["group"]
	expect(not board.yard["load"].is_empty(),"Round 3: the Collector marks a pen")
	grey_turn(board,4)
	expect(board.cohorts[marked]["status"] == "taken" and board.yard["aboard"].has(board.cohorts[marked]["id"]),"Round 4: that group is walked aboard")
	expect(board.remaining_civilians() == 8,"Groups aboard no longer count as waiting")
	grey_turn(board,5)
	var collector: int = 0
	Yard.take_hit(board.yard,collector,4)
	expect(board.yard["load"].is_empty(),"Hitting the Collector breaks the load")
	grey_turn(board,6)
	expect(board.yard["aboard"].size() == 1,"A broken load takes nobody")
	grey_turn(board,Yard.DEPART_ROUND)
	expect(board.yard["withdrawn"] and board.target_at(Vector2i(15,5)) < 0,"The transport lifts off on schedule and the Greys go with it")
	board.free()

	board = rail("ry-beam")
	board.soldiers[3]["cell"] = Vector2i(14,8)
	grey_turn(board,1)
	expect(board.yard["hostile"],"A soldier within 3 of the transport provokes the Sentries")
	var aims := 0
	for entry in board.yard["units"]: aims += 0 if entry["aim"].is_empty() else 1
	expect(aims >= 1,"Hostile Sentries aim a turn ahead")
	expect(board.yard["mark"] != Yard.NONE,"The Disruptor marks a blackout for next round")
	var mark: Vector2i = board.yard["mark"]
	grey_turn(board,2)
	expect(board.yard["dark"] == mark,"The marked area goes dark the round after")
	board.free()

	board = rail("ry-archive")
	board.soldiers[1]["cell"] = board.TERMINAL+Vector2i(-1,0)
	board.select_soldier(1)
	expect(board.download_archive() and board.archive["state"] == "none" and board.yard["hostile"],"First download step; touching the terminal provokes")
	board.soldiers[1]["ap"] = 2
	expect(board.download_archive() and board.archive["state"] == "full","Second step: the full archive")
	board.soldiers[2]["cell"] = board.handcar["cell"]+Vector2i(0,-1)
	board.select_soldier(2)
	expect(board.release_brake() and board.handcar["released"],"Releasing the brake sets the handcar rolling")
	var before: Vector2i = board.handcar["cell"]
	board.roll_handcar()
	expect(board.handcar["cell"] == before+Vector2i(-3,0),"It rolls 3 squares west a round")
	board.soldiers[3]["cell"] = board.handcar["cell"]+Vector2i(-1,0)
	board.roll_handcar()
	expect(board.handcar["cell"] == before+Vector2i(-3,0),"Something on the track stops it")
	board.soldiers[3]["cell"] = Vector2i(2,2)
	for i in range(5): board.roll_handcar()
	expect(board.handcar["out"],"It rolls out of the yard with the supplies")
	board.free()

	board = rail("ry-trade")
	board.phase = 2
	board.soldiers[0]["cell"] = Vector2i(5,8)
	board.select_soldier(0)
	expect(board.trade_offered() and board.accept_trade() and board.archive["state"] == "partial","MSG accepts the round-2 trade: survey records")
	expect(Yard.trade_active(board.yard) and not Yard.firing(board.yard),"Sentries hold fire under the trade")
	board.soldiers[1]["cell"] = board.pens[0]["cell"]+Vector2i(1,0)
	board.select_soldier(1)
	board.cut_lock()
	board.cut_lock()
	expect(Yard.trade_active(board.yard),"Opening a pen isn't covered by the trade")
	board.soldiers[2]["cell"] = Vector2i(15,8)+Vector2i(-1,0)
	grey_turn(board,3)
	expect(board.yard["trade"]["state"] == "broken" and board.yard["trade"]["broken_by"] == "transport" and Yard.firing(board.yard),"A soldier at the transport breaks it, and the record says how")
	board.free()

	board = rail("ry-trade-kept")
	board.phase = 2
	board.select_soldier(0)
	board.accept_trade()
	for r in range(3,6): grey_turn(board,r)
	expect(board.yard["trade"]["state"] == "honored","Kept terms: the trade is honored")
	board.free()

	var carry_file := test_path("ry-carry-record.save")
	Record.save_record(carry_file,{"version":1,"missions":{2:{"taken":["B"]},4:{"drone":"observed","squad":[{"name":"MSG","condition":"active"},{"name":"Reyes","condition":"stable"},{"name":"Bell","condition":"active"},{"name":"Park","condition":"active"}]}}})
	board = rail("ry-carry",carry_file)
	expect(board.cohorts[0]["origin"] == "River Bridge group B" and board.cohorts[0]["manifest"][0] == "RB-B-01","River Bridge's taken group is in the pens, by name")
	expect(board.archive["needed"] == 1,"Interchange drone evidence: a 1-step archive")
	expect(board.soldiers[1]["name"] == "Reyes" and board.soldiers[1]["hp"] == 4,"Interchange squad carries in")
	board.free()

	board = rail("ry-record")
	board.soldiers[0]["extracted"] = true
	board.request_close()
	board.request_close()
	for i in range(4): await process_frame
	var entry: Dictionary = Record.rail_yard_entry(board)
	expect(board.result_ready and entry["mission"] == 5 and entry["archive"] == "none" and entry["groups"].size() == 3,"Rail Yard result records groups and archive")
	expect(Record.carry_forward_rail(entry).size() >= 1,"Rail Yard explains what carries forward")
	expect(board.result_title().begins_with("RAIL YARD"),"Results are titled Rail Yard")
	board.free()
	print("RAIL YARD FAILURES: ",failures)
	quit(1 if failures else 0)
