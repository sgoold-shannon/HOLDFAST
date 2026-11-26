extends "res://tests/test_support.gd"
## Mission 09 · Civic Center: hidden troopers and Scout, the service door and hatch, the alarm
## and its triggers, the split, entrenched fire and cover destruction, extraction steps, the
## mortar and the convoy, records, carry-ins and the record.
const Garrison = preload("res://systems/reptilian_garrison.gd")
const Mortar = preload("res://systems/plasma_mortar.gd")
const Record = preload("res://systems/campaign_record.gd")
const Arc = preload("res://data/campaign_arc.gd")

func civic(label: String, record: String = ""):
	var board = load("res://civic_center.tscn").instantiate()
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
	var board = civic("cc-load")
	expect(board.mission_definition().mission_id == "civic_center" and not board.machine_present(),"Civic Center loads without the Farm Road machine")
	expect(Arc.mission(9)["status"] == "playable" and Arc.mission(9).has("briefing"),"Mission 09 is playable with a briefing")
	expect(not Garrison.visible(board.garrison["units"][0],board),"Troopers inside start hidden")
	expect(board.FIXTURES.has(board.SERVICE_DOOR) and board.FIXTURES.has(board.HATCH) and not board.hatch_found,"The service door is locked and the hatch concealed")
	expect(board.cohorts[2]["penned"] and board.garrison["alarm_round"] == 5,"Detainees penned; alarm at round 5 by default")
	board.soldiers[3]["cell"] = Vector2i(10,13)
	board.select_soldier(3)
	expect(board.scout() and board.garrison["units"][1]["seen"],"Park scouts and marks troopers within 6")
	board.soldiers[1]["cell"] = board.SERVICE_DOOR+Vector2i(-1,0)
	board.select_soldier(1)
	expect(board.force_door() and not board.FIXTURES.has(board.SERVICE_DOOR),"Forcing the service door opens the west corridor")
	board.free()

	board = civic("cc-alarm")
	turn(board,3)
	expect(not board.garrison["alarm"],"No alarm before round 5")
	turn(board,4)
	expect(board.garrison["alarm"] and board.garrison["alarm_cause"] == "schedule","Round 5: the alarm sounds on schedule")
	var factions := {"extraction":0,"territorial":0}
	for entry in board.garrison["units"]: factions[entry["faction"]] += 1
	expect(factions["extraction"] == 2 and factions["territorial"] == 2,"The garrison splits two and two")
	expect(board.mortar["mark"] != board.NONE,"After the alarm the mortar marks an impact")
	board.free()

	board = civic("cc-records")
	board.soldiers[2]["cell"] = board.TERMINAL+Vector2i(-1,0)
	board.select_soldier(2)
	expect(board.download_records() and board.garrison["alarm"] and board.garrison["alarm_cause"] == "records terminal","Touching the records terminal trips the alarm")
	expect(board.download_records() and board.records["done"],"Two steps: records copied")
	board.free()

	board = civic("cc-pen")
	board.reveal_hatch()
	board.soldiers[1]["cell"] = board.PEN+Vector2i(0,-1)
	board.select_soldier(1)
	board.cut_pen()
	expect(board.cut_pen() and board.pen["open"] and not board.cohorts[2]["penned"] and board.garrison["alarm"],"Cutting the pen frees the detainees and trips the alarm")
	board.free()

	board = civic("cc-extract")
	Garrison.raise_alarm(board.garrison,"test",board)
	var extractor: Dictionary = {}
	for entry in board.garrison["units"]:
		if entry["faction"] == "extraction" and entry["cell"] == Vector2i(15,9): extractor = entry
	expect(not extractor.is_empty(),"The facility guard joins the extraction faction")
	turn(board,5)
	expect(Garrison.distance(extractor["cell"],board.PEN) == 1 and board.garrison["load"] == 0,"It moves up to the pen first")
	turn(board,6)
	expect(board.garrison["load"] == 1,"Extraction step 1")
	Garrison.take_hit(board.garrison,board.garrison["units"].find(extractor))
	expect(board.garrison["load"] == 0,"Hitting an extraction trooper breaks the step")
	for r in range(7,10): turn(board,r)
	expect(board.cohorts[2]["status"] == "taken" and board.garrison["moved_out"].has("C"),"Three uninterrupted steps move the detainees out")
	board.free()

	board = civic("cc-cover")
	Garrison.raise_alarm(board.garrison,"test",board)
	var edges: int = board.mission_definition().cover_edges.size()
	board.mortar["mark"] = Vector2i(8,10)
	board.soldiers[1]["cell"] = Vector2i(8,10)
	var hp: int = board.soldiers[1]["hp"]
	turn(board,5)
	expect(board.soldiers[1]["hp"] == hp-Mortar.DAMAGE and not board.mission_definition().cover_edges.has(Vector2i(8,10)),"Mortar impact: 4 damage and the cover is gone")
	expect(board.mission_definition().cover_edges.size() < edges,"Cover was destroyed")
	board.free()

	var fresh = civic("cc-fresh")
	expect(fresh.mission_definition().cover_edges.has(Vector2i(8,10)),"Destroyed cover doesn't leak into the next attempt")
	fresh.free()

	board = civic("cc-convoy")
	Garrison.raise_alarm(board.garrison,"test",board)
	board.mortar["convoy"] = "departed"
	board.mortar["mark"] = board.NONE
	turn(board,5)
	expect(board.mortar["convoy_mark"],"Once the convoy leaves, the mortar walks onto its road")
	turn(board,6)
	expect(board.mortar["vehicles"] == 2,"Each convoy round costs a vehicle")
	board.convoy_shield = true
	turn(board,7)
	expect(board.mortar["vehicles"] == 2,"A Nordic shield over the convoy stops a round")
	expect(Mortar.take_hit(board.mortar,4).contains("hit") and Mortar.take_hit(board.mortar,4).contains("quiet") and Mortar.silenced(board.mortar),"Two hits silence the spotter")
	board.free()

	var carry_file := test_path("cc-carry-record.save")
	Record.save_record(carry_file,{"version":1,"missions":{6:{"infiltrator":"contained","taken":["C"]},8:{"contact":true,"charges_left":1}}})
	board = civic("cc-carry",carry_file)
	expect(board.files and board.door_open and board.hatch_found and not board.FIXTURES.has(board.HATCH),"Hospital files: door code and hatch known")
	expect(board.cohorts[2]["origin"].contains("County Hospital group C") and board.aven_charge,"Hospital's taken group is among the detainees; Aven can shield")
	board.free()
	var leak_file := test_path("cc-leak-record.save")
	Record.save_record(leak_file,{"version":1,"missions":{6:{"infiltrator":"reached_base"}}})
	board = civic("cc-leak",leak_file)
	expect(board.leaked and board.garrison["alarm_round"] == 3,"An infiltrator at the base means an early alarm")
	turn(board,2)
	expect(board.garrison["alarm"] and board.garrison["alarm_cause"] == "leak","The leak trips the alarm at round 3")
	board.free()

	board = civic("cc-record")
	board.soldiers[0]["extracted"] = true
	board.request_close()
	board.request_close()
	for i in range(4): await process_frame
	var entry: Dictionary = Record.civic_center_entry(board)
	expect(board.result_ready and entry["mission"] == 9 and not entry["records"] and entry["detainees"] == "left in the pen","Civic Center result records records and detainees")
	expect(Record.carry_forward_civic(entry).size() >= 3,"Civic Center explains what carries forward")
	expect(board.result_title().begins_with("CIVIC CENTER"),"Results are titled Civic Center")
	board.free()
	print("CIVIC CENTER FAILURES: ",failures)
	quit(1 if failures else 0)
