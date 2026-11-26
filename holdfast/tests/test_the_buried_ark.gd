extends "res://tests/test_support.gd"
## Mission 11 · The Buried Ark: the Warden (overwatch, cone marks, disable, negotiate, destroy),
## the parley and terms, the incursion's strips (table, life support, nursery), the nursery door,
## delegates, Aven's shield, the reserve connector, carry-ins and the record.
const Warden = preload("res://systems/ark_warden.gd")
const Parley = preload("res://systems/ark_parley.gd")
const FallowCutter = preload("res://systems/fallow_cutter.gd")
const Record = preload("res://systems/campaign_record.gd")
const Arc = preload("res://data/campaign_arc.gd")

func ark(label: String, record: String = ""):
	var board = load("res://the_buried_ark.tscn").instantiate()
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
	var board = ark("ba-load")
	expect(board.mission_definition().mission_id == "the_buried_ark" and not board.machine_present(),"The Buried Ark loads without the Farm Road machine")
	expect(Arc.mission(11)["status"] == "playable" and Arc.mission(11).has("briefing"),"Mission 11 is playable with a briefing")
	expect(board.warden["state"] == "hostile" and board.trunk == 1 and board.kesh and not board.aven,"Defaults: hostile Warden, trunk 1, Kesh present, no Aven")
	expect(board.cohorts[0]["cell"] == board.SEAT and board.cohorts[2]["penned"],"Delegates seated; nursery behind its door")
	board.select_soldier(0)
	expect(board.console_reason().contains("authenticated"),"Trunk 1 without an authenticated channel: no negotiation")
	board.free()

	board = ark("ba-cone")
	board.soldiers[1]["cell"] = Vector2i(10,9)
	turn(board,1)
	expect(board.warden["marked"].has(Vector2i(10,9)),"Standing in the cone gets you marked")
	var hp: int = board.soldiers[1]["hp"]
	turn(board,2)
	expect(board.soldiers[1]["hp"] == hp-Warden.DAMAGE,"Next phase it fires on the marked square")
	board.soldiers[1]["cell"] = Vector2i(14,13)
	turn(board,3)
	expect(board.warden["marked"].is_empty(),"Out of the cone: nothing marked")
	expect(Warden.crossing(board.warden,Vector2i(9,9),Vector2i(9,5)) and not Warden.crossing(board.warden,Vector2i(2,10),Vector2i(5,5)),"Crossing the gallery mouth counts; the crawl doesn't")
	board.free()

	board = ark("ba-disable")
	board.soldiers[2]["cell"] = board.COUPLING+Vector2i(-1,0)
	board.select_soldier(2)
	board.disable_warden()
	expect(board.disable_warden() and board.warden["state"] == "disabled","Bell disables the Warden in two steps")
	board.select_soldier(1)
	expect(board.disable_reason() != "","Only the engineer disables it")
	board.free()

	board = ark("ba-destroy")
	expect(Warden.take_hit(board.warden,4,false).contains("armored") and board.warden["hp"] == Warden.HP-2,"From the front the Warden takes half")
	board.warden["hp"] = 4
	Warden.take_hit(board.warden,4,true)
	expect(board.warden["state"] == "destroyed","Flanked hits can destroy it")
	board.free()

	var auth_file := test_path("ba-auth-record.save")
	Record.save_record(auth_file,{"version":1,"missions":{10:{"trunk":2,"channel":"authenticated","dependents":"stabilized","cargo":1},8:{"contact":true,"charges_left":1},9:{"records":true,"council_out":true},4:{"agreement":"honored"}}})
	board = ark("ba-auth",auth_file)
	expect(board.trunk == 2 and board.aven and board.aven_charge and board.council,"Carry-ins: trunk 2, Aven with a charge, the council")
	expect(board.start_terms == 5 and board.parley["terms"] == 5,"Starting terms: +2 habitat, +1 cargo, +1 records, +1 Interchange")
	expect(board.soldiers[0]["cell"].y == 13,"Trunk 2: the lift starts the squad further in")
	board.soldiers[0]["cell"] = board.CONSOLE+Vector2i(1,0)
	board.select_soldier(0)
	expect(board.negotiate_warden() and board.warden["state"] == "allied","Authenticated control: MSG negotiates; the Warden is allied")
	board.soldiers[0]["cell"] = board.TABLE+Vector2i(1,0)
	turn(board,2)
	expect(board.parley["terms"] == 8,"Seated parley with Kesh and Aven: +3 a round")
	turn(board,3)
	expect(board.fallow["stage"] == "active" and board.cohorts[0]["cell"] == board.ALCOVE,"Round 4: the incursion scatters the delegates to the alcove")
	var before: int = board.parley["terms"]
	turn(board,4)
	expect(board.parley["terms"] == before,"No parley while the delegates are away")
	expect(board.warden["ally_aim"],"The allied Warden turns on the cutter")
	var cutter_hp: int = board.fallow["cutter"]["hp"]
	turn(board,5)
	expect(board.fallow["cutter"]["hp"] == cutter_hp-Warden.ALLY_DAMAGE,"…and fires on it")
	board.select_soldier(0)
	expect(board.shield_strip() and board.fallow["marked"].is_empty() and not board.aven_charge,"Aven's shield takes one strip")
	board.free()

	board = ark("ba-strips")
	turn(board,3)
	expect(board.fallow.get("target",-1) == 0 and not board.fallow["marked"].is_empty(),"The first strip goes toward the table")
	turn(board,4)
	expect(not board.fallow["rifts"].is_empty() and board.fallow["target"] == 1,"It folds, then marks toward life support")
	turn(board,5)
	expect(board.fallow["target"] == 2,"…then toward the nursery")
	var nursery_hp: int = board.cohorts[2]["hp"]
	turn(board,6)
	expect(board.cohorts[2]["hp"] < nursery_hp,"A nursery left shut takes the fold")
	board.free()

	board = ark("ba-wave")
	turn(board,3)
	board.fallow["cutter"]["hp"] = 0
	turn(board,4)
	expect(not FallowCutter.cutter_alive(board.fallow),"A dead cutter stays down for now")
	turn(board,7)
	expect(FallowCutter.cutter_alive(board.fallow) and board.fallow["second_wave"] and not board.fallow["marked"].is_empty(),"Round 8: a second cutter comes through the rift")
	board.soldiers[1]["cell"] = board.FALLOW_NODE+Vector2i(0,-1)
	board.select_soldier(1)
	expect(board.interrupt_rift_node() and board.node_reason().contains("re-linking"),"After an interrupt the node re-links: no interrupt next round")
	board.phase += 2
	board.fallow["interrupted"] = false
	expect(board.node_reason() == "","…then, a round later, it can be interrupted again")
	board.free()

	board = ark("ba-plant")
	board.life = 1
	board.fallow["stage"] = "active"
	board.fallow["marked"] = [Vector2i(8,3)]
	board.fold_strip()
	expect(board.life == 0 and board.agreement() == "narrow","A fold next to the plant costs integrity; at 0 life support is lost")
	board.parley["terms"] = 8
	expect(board.agreement() == "working","Generous terms without life support count as working")
	board.free()

	board = ark("ba-nursery")
	board.soldiers[3]["cell"] = board.DOOR+Vector2i(-1,0)
	board.select_soldier(3)
	expect(board.open_nursery() and not board.cohorts[2]["penned"] and not board.FIXTURES.has(board.DOOR),"Opening the nursery frees the children toward the spur")
	board.free()

	board = ark("ba-recall")
	board.cohorts[0]["cell"] = board.ALCOVE
	board.fallow["stage"] = "active"
	board.fallow["cutter"]["hp"] = 0
	board.soldiers[0]["cell"] = board.TABLE+Vector2i(0,1)
	board.select_soldier(0)
	expect(board.recall_delegates() and board.cohorts[0]["cell"] == board.SEAT,"MSG calls the delegates back once the Fallow are off the table")
	board.free()

	board = ark("ba-connector")
	board.soldiers[2]["cell"] = board.BATTERY+Vector2i(-1,0)
	board.select_soldier(2)
	board.seat_connector()
	expect(board.seat_connector() and board.connector == board.CONNECTOR_STEPS,"Bell seats the reserve connector in two steps")
	board.free()

	var hard_file := test_path("ba-hard-record.save")
	Record.save_record(hard_file,{"version":1,"missions":{7:{"habitat":"lost"},10:{"trunk":0,"channel":"hardened","dependents":"left","cargo":0}}})
	board = ark("ba-hard",hard_file)
	expect(not board.kesh and board.trunk == 0 and board.start_terms == 0 and Parley.gain(board.parley) == 1,"Kesh absent, console dark, terms from zero")
	board.select_soldier(0)
	expect(board.console_reason().contains("dark"),"Trunk 0: the console is dark")
	board.free()

	board = ark("ba-record")
	board.soldiers[0]["extracted"] = true
	board.request_close()
	board.request_close()
	for i in range(4): await process_frame
	var entry: Dictionary = Record.ark_entry(board)
	expect(board.result_ready and entry["mission"] == 11 and entry["agreement"] == "narrow" and entry["delegates"] == "safe" and entry["nursery"] == "lost","The Buried Ark result records the agreement, delegates and nursery")
	expect(Record.carry_forward_ark(entry).size() >= 3 and Record.act_three_complete({"missions":{11:entry}}),"Carry-forward and Act III complete")
	expect(board.result_title().begins_with("THE BURIED ARK"),"Results are titled The Buried Ark")
	board.scene_view = "debrief"
	board.scene_page = board.debrief_pages().size()-1
	expect(board.scene_options().size() == 3,"The packing scene offers MSG three lines")
	board.choose_scene_option(2)
	expect(board.packing_line == "people" and board.debrief_pages()[-1]["text"].contains("Leave room"),"MSG's choice lands in the scene")
	board.free()
	print("BURIED ARK FAILURES: ",failures)
	quit(1 if failures else 0)
