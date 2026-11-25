extends "res://tests/test_support.gd"
## Mission 08 · Regional Airfield: Nordic contact window and charges, shields, sensor data,
## Grey stripping and the bargain, the pod, Fallow on the runway, the team, record and carry-ins.
const Craft = preload("res://systems/nordic_craft.gd")
const Strip = preload("res://systems/grey_strippers.gd")
const FallowCutter = preload("res://systems/fallow_cutter.gd")
const FireTeam = preload("res://systems/fire_team.gd")
const Record = preload("res://systems/campaign_record.gd")
const Arc = preload("res://data/campaign_arc.gd")

func field(label: String, record: String = ""):
	var board = load("res://regional_airfield.tscn").instantiate()
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
	var board = field("af-load")
	expect(board.mission_definition().mission_id == "regional_airfield" and not board.machine_present(),"Airfield loads without the Farm Road machine")
	expect(Arc.mission(8)["status"] == "playable" and Arc.mission(8).has("briefing"),"Mission 08 is playable with a briefing")
	expect(board.craft["charges"] == 2 and not board.pod["active"] and board.team["name"] == "Guard Team Marsh" and FireTeam.standing(board.team) == 4,"Defaults: 2 charges, no pod, full Guard Team Marsh")
	board.select_soldier(0)
	expect(not board.make_contact() and board.status_text.contains("hatch"),"Contact needs MSG at the hatch")
	board.soldiers[0]["cell"] = board.CRAFT_DOOR
	expect(board.make_contact() and board.craft["contact"],"MSG makes contact")
	board.cohort_selected = 0
	board.soldiers[0]["ap"] = 2
	expect(board.request_shield() and board.craft["charges"] == 1 and board.protected_cell(board.cohorts[0]["cell"]),"A shield spends a charge and covers the selected group")
	board.soldiers[1]["cell"] = board.CRAFT_DOOR+Vector2i(0,1)
	board.select_soldier(1)
	expect(not board.download_sensors() and board.status_text.contains("hatch"),"Sensor data is downloaded at the hatch")
	board.soldiers[0]["cell"] = Vector2i(12,4)
	board.soldiers[1]["cell"] = board.CRAFT_DOOR
	board.select_soldier(1)
	board.download_sensors()
	expect(board.download_sensors() and board.craft["data"],"Two steps copy the sensor data")
	board.soldiers[0]["ap"] = 2
	board.select_soldier(0)
	board.request_shield()
	expect(board.craft["charges"] == 0 and not board.request_shield(),"Charges run out")
	turn(board,1)
	turn(board,2)
	expect(board.craft["left"] and board.craft["leave_reason"] == "protection exhausted","Exhausted protection forces departure")
	board.free()

	board = field("af-window")
	for r in range(1,Craft.WINDOW_ROUND+1): turn(board,r)
	board.phase = Craft.WINDOW_ROUND+1
	board.soldiers[0]["cell"] = board.CRAFT_DOOR
	board.select_soldier(0)
	expect(not board.make_contact() and board.status_text.contains("closed"),"The contact window closes after round 6")
	board.free()

	board = field("af-strip")
	var collector: Dictionary = Strip.unit(board.strip,"collector")
	collector["cell"] = board.PLANE+Vector2i(1,1)
	turn(board,1)
	expect(board.strip["progress"] == 1,"The Collector starts unbolting an engine")
	Strip.take_hit(board.strip,0,4)
	expect(board.strip["progress"] == 0 and board.strip["hostile"],"Hitting it breaks the strip and turns the Sentries")
	board.strip["hostile"] = false
	turn(board,2)
	turn(board,3)
	expect(board.strip["engines"] == 1 and board.aircraft_state() == "one engine","Two Grey phases take an engine")
	board.soldiers[2]["cell"] = collector["cell"]+Vector2i(0,2)
	turn(board,4)
	expect(board.strip["hostile"],"A soldier on the shipment provokes the Sentries")
	turn(board,Strip.DEPART_ROUND)
	expect(board.strip["withdrawn"],"The Greys leave on schedule")
	board.free()

	board = field("af-fallow")
	board.fallow["stage"] = "active"
	board.fallow["marked"] = [Vector2i(6,8),Vector2i(7,8)]
	board.phase = 5
	FallowCutter.act(board.fallow,board)
	expect(board.runway_ruined(),"Two rift squares on the runway ruin it")
	var grey: Dictionary = Strip.unit(board.strip,"collector")
	board.fallow["marked"] = [grey["cell"]]
	var before: Vector2i = grey["cell"]
	turn(board,6)
	expect(grey["cell"] != before,"Greys step off Fallow-marked ground")
	board.free()

	var carry_file := test_path("af-carry-record.save")
	Record.save_record(carry_file,{"version":1,"missions":{2:{"craft_shield":true},5:{"archive":"full","aboard":["B"]},6:{"team_dead":["Sgt. Marsh","Cpl. Ruiz"]}}})
	board = field("af-carry",carry_file)
	expect(board.craft["charges"] == 1 and board.intel_line and board.pod["active"],"Carry-ins: River Bridge shield, intel line, Rail Yard captives")
	expect(board.cohorts[2]["penned"] and board.cohorts[2]["cell"] == board.POD and board.cohorts[2]["origin"].begins_with("Rail Yard group B"),"The Rail Yard group is in the pod, by name")
	expect(FireTeam.standing(board.team) == 2 and board.team["name"] == "Guard Team Marsh","Marsh's Hospital dead stay dead")
	board.soldiers[3]["cell"] = board.POD+Vector2i(-1,0)
	board.select_soldier(3)
	board.pod_cut()
	expect(board.pod_cut() and board.pod["open"] and not board.cohorts[2]["penned"],"Cutting the pod frees them")
	board.phase = Strip.BARGAIN_ROUND
	board.soldiers[0]["cell"] = Vector2i(4,12)
	board.select_soldier(0)
	expect(board.bargain_offered() and board.accept_bargain() and Strip.bargain_active(board.strip),"The intel line offers a stated bargain in round 3")
	board.soldiers[0]["cell"] = board.CRAFT_DOOR
	board.soldiers[0]["ap"] = 2
	expect(board.make_contact() and board.status_text.contains("Verified"),"Contact verifies the River Bridge craft")
	board.free()

	var holt_file := test_path("af-holt-record.save")
	Record.save_record(holt_file,{"version":1,"missions":{6:{"team_dead":["Sgt. Marsh","Cpl. Ruiz","Spc. Daniels","Pfc. Kowalski"]}}})
	board = field("af-holt",holt_file)
	expect(board.team["name"] == "Guard Team Holt" and FireTeam.standing(board.team) == 4,"If Marsh's team was lost, Guard Team Holt holds the terminal")
	board.free()

	board = field("af-record")
	board.soldiers[0]["extracted"] = true
	board.request_close()
	board.request_close()
	for i in range(4): await process_frame
	var entry: Dictionary = Record.airfield_entry(board)
	expect(board.result_ready and entry["mission"] == 8 and not entry["contact"] and entry["aircraft"] == "intact","Airfield result records contact and the aircraft")
	expect(Record.carry_forward_airfield(entry).size() >= 3,"Airfield explains what carries forward")
	expect(board.result_title().begins_with("REGIONAL AIRFIELD"),"Results are titled Regional Airfield")
	board.free()
	print("REGIONAL AIRFIELD FAILURES: ",failures)
	quit(1 if failures else 0)
