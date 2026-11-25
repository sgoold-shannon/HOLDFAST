extends "res://tests/test_support.gd"
## Mission 06 · County Hospital: power and ambulance, screening and detention, the
## infiltrator's act and the breach clock, Reptilian harvest and sonic cone, the Drover
## convoy, Guard Team Marsh, record and carry-ins.
const Power = preload("res://systems/hospital_power.gd")
const Screening = preload("res://systems/screening.gd")
const Reptilians = preload("res://systems/reptilian_team.gd")
const Convoy = preload("res://systems/drover_convoy.gd")
const FireTeam = preload("res://systems/fire_team.gd")
const Record = preload("res://systems/campaign_record.gd")
const Arc = preload("res://data/campaign_arc.gd")

func hospital(label: String, record: String = "", infiltrator: int = 1):
	var board = load("res://county_hospital.tscn").instantiate()
	board.auto_resume = false
	board.record_path = record
	root.add_child(board)
	board.report_path = test_path(label+"-report.save")
	board.completion_path = test_path(label+"-complete.save")
	board.campaign_path = test_path(label+"-campaign.save")
	board.command_model = "authority"
	board.screening = Screening.initial(infiltrator)
	board.finish_opening()
	return board

func turn(board, round_number: int) -> void:
	board.phase = round_number
	board.last_enemy_phase = round_number-1
	board.resolve_enemy_turn()

func run() -> void:
	var board = hospital("ch-load")
	expect(board.mission_definition().mission_id == "county_hospital" and not board.machine_present(),"County Hospital loads without the Farm Road machine")
	expect(Arc.mission(6)["status"] == "playable" and Arc.mission(6).has("briefing"),"Mission 06 is playable with a briefing")
	expect(Power.capacity(board.power) == 1 and board.cohorts[2]["gurneys"],"One power system by default; group C is on gurneys")
	board.free()

	board = hospital("ch-power")
	board.soldiers[0]["cell"] = board.GENERATOR+Vector2i(1,0)
	board.select_soldier(0)
	expect(board.toggle_power("ambulance") and Power.powered(board.power,"ambulance"),"MSG powers the ambulance charger")
	expect(not board.toggle_power("scanner") and board.status_text.contains("maxed"),"Power is capped")
	board.soldiers[1]["cell"] = board.BAY+Vector2i(0,-1)
	board.cohorts[0]["cell"] = board.BAY+Vector2i(-1,0)
	board.cohort_selected = 0
	board.select_soldier(1)
	expect(board.load_ambulance() and board.cohorts[0]["status"] == "riding","A soldier at the bay loads the selected group")
	board.convoy["stage"] = "diverted"
	board.soldiers[2]["cell"] = Vector2i(12,8)
	turn(board,1)
	turn(board,2)
	expect(board.cohorts[0]["status"] == "extracted" and board.ambulance["trips"] == ["A"],"The ambulance drives the group out, past a soldier on the road")
	turn(board,3)
	turn(board,4)
	expect(board.ambulance["state"] == "parked","And comes back to the bay")
	var walker: Vector2i = board.cohorts[2]["cell"]
	board.cohorts[2]["order"] = "north"
	board.move_cohort(board.cohorts[2],3)
	expect(Reptilians.distance(walker,board.cohorts[2]["cell"]) <= 1,"Gurneys move one square a turn on foot")
	board.free()

	var rail_file := test_path("ch-rail-record.save")
	Record.save_record(rail_file,{"version":1,"missions":{4:{"retry_required":false,"agreement":"honored"},5:{"supplies":"generator cells"}}})
	board = hospital("ch-carry",rail_file)
	expect(board.rail_cells and board.field_contact and Power.capacity(board.power) == 2,"Rail Yard cells add a system; Interchange contact is read")
	turn(board,3)
	expect(board.convoy["stage"] == "arrived","The convoy arrives for round 4")
	board.soldiers[0]["cell"] = Vector2i(16,11)
	board.select_soldier(0)
	expect(board.answer_convoy("monitored") and board.convoy["choice"] == "monitored","With field contact MSG agrees a monitored passage")
	turn(board,4)
	expect(Convoy.passing(board.convoy) and board.road_closed(Vector2i(12,8)),"The convoy closes the road for rounds 5–6")
	turn(board,5)
	turn(board,6)
	expect(board.convoy["stage"] == "gone" and Power.capacity(board.power) == 3,"Afterwards their coupling adds a system")
	board.free()

	board = hospital("ch-contested")
	turn(board,3)
	board.soldiers[2]["cell"] = Vector2i(13,8)
	var hp: int = board.soldiers[2]["hp"]
	turn(board,4)
	expect(board.convoy["choice"] == "contested" and board.soldiers[2]["hp"] == hp-Convoy.SHOVE_DAMAGE and board.soldiers[2]["cell"] != Vector2i(13,8),"Without contact the convoy forces the road and shoves people off it")
	board.free()

	board = hospital("ch-screen","",1)
	board.soldiers[1]["cell"] = board.CHECKPOINT+Vector2i(0,1)
	board.cohorts[0]["cell"] = Vector2i(11,9)
	board.cohorts[1]["cell"] = Vector2i(13,9)
	board.select_soldier(1)
	board.cohort_selected = 0
	expect(board.check_credentials() and board.screening["people"][2]["credentials"] == "unchecked","Credentials are checked one person at a time")
	expect(board.screening["people"][0]["credentials"] == "consistent","Group A's person checks out (the innocent badge is group C's)")
	board.cohort_selected = 1
	expect(board.check_credentials() and Screening.discrepancies(board.screening,1) == 1,"The infiltrator's badge is a discrepancy")
	board.soldiers[1]["ap"] = 2
	expect(not board.scan_person() and board.status_text.contains("no power"),"No scan without power")
	# The infiltrator acts in round 3 with a soldier watching the gate.
	board.soldiers[3]["cell"] = Vector2i(12,5)
	turn(board,3)
	expect(board.screening["acted"] and board.screening["witnessed"] and Screening.confirmed(board.screening,1),"Witnessed at the gate: two discrepancies confirm")
	expect(board.reptilians["arrival"] == Reptilians.EARLY_BREACH,"The open gate brings the breach to round 5")
	board.soldiers[2]["cell"] = board.cohorts[1]["cell"]+Vector2i(1,0)
	board.select_soldier(2)
	expect(board.detain_person() and board.screening["people"][1]["status"] == "contained","Confirmed and contained alive")
	board.free()

	board = hospital("ch-false","",0)
	board.soldiers[1]["cell"] = board.cohorts[1]["cell"]+Vector2i(1,0)
	board.select_soldier(1)
	board.cohort_selected = 1
	expect(board.detain_person() and board.screening["false_detentions"] == ["Dr. E. Hale"] and board.cohorts[1]["panic"] == 2,"Detaining the wrong person is a recorded false detention, and the group panics")
	board.free()

	board = hospital("ch-early","",2)
	board.cohorts[2]["cell"] = Vector2i(10,12)
	board.soldiers[0]["cell"] = board.cohorts[2]["cell"]+Vector2i(1,0)
	board.select_soldier(0)
	board.cohort_selected = 2
	board.detain_person()
	turn(board,3)
	expect(not board.screening["acted"] and board.reptilians["arrival"] == Reptilians.LATE_BREACH,"Contained before round 3: no gate, a late breach")
	board.free()

	board = hospital("ch-breach")
	board.reptilians["arrival"] = Reptilians.EARLY_BREACH
	turn(board,4)
	expect(board.reptilians["arrived"] and board.reptilians["units"].size() == 2,"Two troopers arrive for round 5")
	board.cohorts[2]["cell"] = board.reptilians["units"][0]["cell"]+Vector2i(0,1)
	turn(board,5)
	expect(board.cohorts[2]["status"] == "taken" and board.reptilians["taken"] == ["C"],"A trooper next to a group takes it")
	board.reptilians["cone"] = [board.soldiers[1]["cell"]]
	turn(board,6)
	expect(board.reptilians["stunned"].has(1),"Standing in the sonic cone stuns")
	board.begin_player_phase()
	expect(board.soldiers[1]["ap"] == 1,"A stunned soldier starts with 1 AP less")
	var line: String = Reptilians.take_hit(board.reptilians,0)
	expect(board.reptilians["units"][0]["hp"] == Reptilians.TROOPER_HP-Reptilians.ARMOR_DAMAGE and line.contains("armor"),"Armor: rifle hits deal 3")
	board.free()

	board = hospital("ch-team")
	board.select_soldier(0)
	board.cohort_selected = 2
	expect(board.order_team("protect") and not board.order_team("withdraw"),"One team order a turn")
	board.cohorts[2]["cell"] = Vector2i(12,11)
	turn(board,1)
	expect(Reptilians.distance(board.team["cell"],board.cohorts[2]["cell"]) <= Reptilians.distance(board.TEAM_START,board.cohorts[2]["cell"]),"Protect: the team closes on its group")
	var hit: String = FireTeam.damage(board.team,8)
	expect(hit.contains("Marsh") and FireTeam.standing(board.team) == 3 and board.team_dead() == ["Sgt. Marsh"],"Team casualties are individual and named")
	board.free()

	board = hospital("ch-record")
	board.soldiers[0]["extracted"] = true
	board.request_close()
	board.request_close()
	for i in range(4): await process_frame
	var entry: Dictionary = Record.county_hospital_entry(board)
	expect(board.result_ready and entry["mission"] == 6 and entry["infiltrator"] == "at_large" and not entry["critical_out"],"County Hospital result records the infiltrator and critical patients")
	expect(Record.carry_forward_hospital(entry).size() >= 3,"County Hospital explains what carries forward")
	expect(board.result_title().begins_with("COUNTY HOSPITAL"),"Results are titled County Hospital")
	board.free()
	print("COUNTY HOSPITAL FAILURES: ",failures)
	quit(1 if failures else 0)
