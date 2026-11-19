extends "res://tests/test_support.gd"
## Mission 02 · River Bridge: lanes, Grey lift and beam, craft shield, sensor, record, carry-over.
const GreyTeam = preload("res://systems/grey_team.gd")
const Record = preload("res://systems/campaign_record.gd")

func river(label: String, record: String = ""):
	var board = load("res://river_bridge.tscn").instantiate()
	board.auto_resume = false
	board.record_path = record
	root.add_child(board)
	board.report_path = test_path(label+"-report.save")
	board.completion_path = test_path(label+"-complete.save")
	board.campaign_path = test_path(label+"-campaign.save")
	board.command_model = "authority"
	board.finish_opening()
	return board

func run() -> void:
	var board = river("rb-lanes")
	expect(board.mission_definition().mission_id == "river_bridge" and not board.machine_present(),"River Bridge loads without the Farm Road machine")
	expect(board.opening_pages().size() == 3 and board.scene_options().is_empty(),"River Bridge has its own opening, no forced choice")
	expect(not board.civilian_safe(Vector2i(9,8)) and not board.route_available("north"),"Nobody crosses before the lanes are set")
	board.select_soldier(0)
	expect(not board.set_lanes("people"),"Lanes need a soldier at the checkpoint")
	board.soldiers[0]["cell"] = Vector2i(7,8)
	var ap: int = board.soldiers[0]["ap"]
	expect(board.set_lanes("heavy") and board.soldiers[0]["ap"] == ap-1,"Heavy lane set for 1 AP")
	expect(not board.set_lanes("people"),"Lanes are set once")
	expect(board.civilian_safe(Vector2i(9,7)) and not board.civilian_safe(Vector2i(9,8)) and not board.route_available("south"),"Heavy lane leaves civilians row 7 only")
	board.free()

	board = river("rb-greys")
	var greys: Dictionary = board.greys
	var collector: Dictionary = GreyTeam.unit(greys,"collector")
	board.cohorts[1]["cell"] = collector["cell"]+Vector2i(-3,1)
	board.phase = 2
	GreyTeam.act(greys,board)
	expect(not greys["lift"].is_empty() and greys["lift"]["group"] == 1 and greys["lift"]["count"] == 2,"Collector marks the nearest group with LIFT 2")
	GreyTeam.act(greys,board)
	expect(greys["lift"]["count"] == 1,"Lift counts down each Grey phase")
	GreyTeam.act(greys,board)
	expect(greys["shield_used"] and board.cohorts[1]["status"] == "active","The unidentified craft spends its shield once and the group stays")
	GreyTeam.act(greys,board)
	expect(greys["lift"].is_empty() or greys["lift"]["group"] != 1,"A shielded group isn't re-marked the same round")
	greys["lift"] = {"group":1,"count":1}
	GreyTeam.act(greys,board)
	expect(board.cohorts[1]["status"] == "taken" and greys["taken"].has("B"),"Without a shield the group is taken and named")
	expect(board.remaining_civilians() == 8,"Taken groups no longer count as waiting")
	board.free()

	board = river("rb-break")
	greys = board.greys
	collector = GreyTeam.unit(greys,"collector")
	board.cohorts[0]["cell"] = collector["cell"]+Vector2i(-2,2)
	GreyTeam.act(greys,board)
	expect(not greys["lift"].is_empty(),"Lift started")
	var line := GreyTeam.take_hit(greys,0,GreyTeam.SHOT_DAMAGE)
	expect(greys["lift"].is_empty() and greys["hostile"] and line.contains("breaks"),"Hitting the Collector breaks the lift and provokes the Sentry")
	board.cohorts[0]["cell"] = Vector2i(14,11)
	expect(board.sheltered(board.cohorts[0]["cell"]),"The barn is shelter")
	GreyTeam.take_hit(greys,0,GreyTeam.SHOT_DAMAGE)
	expect(greys["withdrawn"] and greys["withdraw_reason"].begins_with("Collector"),"Collector down: the team abandons the site")
	board.free()

	board = river("rb-beam")
	greys = board.greys
	greys["hostile"] = true
	greys["units"][0]["hp"] = 0
	var sentry: Dictionary = GreyTeam.unit(greys,"sentry")
	board.soldiers[2]["cell"] = sentry["cell"]+Vector2i(-4,0)
	GreyTeam.act(greys,board)
	expect(not greys["aim"].is_empty() and greys["aim"]["soldier"] == 2,"Hostile Sentry aims at a soldier in sight")
	var hp: int = board.soldiers[2]["hp"]
	board.soldiers[2]["cell"] = board.soldiers[2]["cell"]+Vector2i(0,3)
	GreyTeam.act(greys,board)
	expect(board.soldiers[2]["hp"] == hp,"Stepping off the line dodges the beam")
	board.phase = GreyTeam.WITHDRAW_ROUND
	GreyTeam.act(greys,board)
	expect(greys["withdrawn"],"Greys withdraw on their clock")
	board.free()

	board = river("rb-sensor")
	board.select_soldier(3)
	board.soldiers[3]["cell"] = Vector2i(6,13)
	expect(board.recover_sensor() and board.sensor_recovered,"A soldier next to the reeds recovers the sensor")
	board.soldiers[0]["extracted"] = true
	board.request_close()
	board.request_close()
	for i in range(4): await process_frame
	var entry: Dictionary = Record.river_bridge_entry(board)
	expect(board.result_ready and entry["mission"] == 2 and entry["sensor"] and entry["supplies"] == "lost","River Bridge result records sensor and supplies")
	expect(Record.carry_forward_river(entry).size() >= 3,"River Bridge explains what carries forward")
	expect(board.result_title().begins_with("RIVER BRIDGE"),"Results are titled River Bridge")
	board.free()

	var record_file := test_path("rb-carry-record.save")
	Record.save_record(record_file,{"version":1,"missions":{1:{"squad":[{"name":"MSG","condition":"active"},{"name":"Ortiz","condition":"dead"},{"name":"Bell","condition":"stable"},{"name":"Park","condition":"active"}]}}})
	board = river("rb-carry",record_file)
	expect(board.soldiers[1]["name"] == "Reyes" and board.soldiers[1]["replacement_for"] == "Ortiz","A soldier lost at Farm Road is replaced")
	expect(board.soldiers[2]["hp"] == 4,"Farm Road wounds carry into River Bridge")
	board.free()
	print("RIVER BRIDGE FAILURES: ",failures)
	quit(1 if failures else 0)
