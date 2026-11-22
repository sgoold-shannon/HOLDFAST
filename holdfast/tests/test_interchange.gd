extends "res://tests/test_support.gd"
## Mission 04 · Interchange: work zone, corridor pause and breaches, Grey drone attribution,
## suppress and restrain, assault, loading clock, record and carry-ins.
const Crew = preload("res://systems/drover_crew.gd")
const Drone = preload("res://systems/grey_drone.gd")
const Record = preload("res://systems/campaign_record.gd")
const Arc = preload("res://data/campaign_arc.gd")

func junction(label: String, record: String = ""):
	var board = load("res://interchange.tscn").instantiate()
	board.auto_resume = false
	board.record_path = record
	root.add_child(board)
	board.report_path = test_path(label+"-report.save")
	board.completion_path = test_path(label+"-complete.save")
	board.campaign_path = test_path(label+"-campaign.save")
	board.command_model = "authority"
	board.finish_opening()
	return board

func aim_at(board, index: int, cell: Vector2i) -> void:
	board.select_soldier(index)
	board.sight_mode = true
	board.pinned_target = cell

func run() -> void:
	var board = junction("ic-load")
	expect(board.mission_definition().mission_id == "interchange" and not board.machine_present(),"Interchange loads without the Farm Road machine")
	expect(board.deadline() == 10 and board.opening_pages().size() == 3 and board.scene_options().is_empty(),"Convoy window after round 10; its own opening")
	expect(Arc.mission(4)["status"] == "playable" and Arc.mission(4).has("briefing"),"Mission 04 is playable with a briefing")
	expect(board.target_at(board.HAULER) == 10 and board.target_at(Vector2i(9,6)) == 11,"Hauler and security are on the map")
	expect(not board.civilian_safe(Vector2i(10,9)) and board.civilian_safe(Vector2i(4,8)),"Civilians won't walk into the armed work zone")
	expect(board.cohorts[2]["cell"] == Vector2i(8,2) and board.WALL_CELLS.has(Vector2i(17,2)) and board.WALL_CELLS.has(Vector2i(17,3)),"Group C is on the overpass and the east end is cut")
	expect(not board.drone_visible(),"No drone yet")
	board.free()

	board = junction("ic-pause")
	board.soldiers[0]["cell"] = Vector2i(7,8)
	board.select_soldier(0)
	expect(not board.transmit_pause() and board.status_text.contains("Observe"),"Without ACK-01 the pause needs an observation first")
	expect(board.observe_hauler() and board.crew["observed"],"MSG observes the hauler")
	expect(board.transmit_pause() and board.crew["pause"]["state"] == "requested","MSG requests the pause")
	board.phase = 1
	board.resolve_enemy_turn()
	expect(Crew.pause_active(board.crew) and board.crew["pause"]["until"] == 1+Crew.PAUSE_ROUNDS,"The crew accepts in its phase: 3 rounds")
	expect(board.civilian_safe(Vector2i(10,9)),"During the pause civilians can cross the work zone")
	board.soldiers[1]["cell"] = Vector2i(10,7)
	board.phase = 2
	board.last_enemy_phase = 1
	board.resolve_enemy_turn()
	expect(board.crew["agreement"] == "breached_squad" and Crew.hostile(board.crew,2),"A soldier off the lane next to the hauler breaks the pause")
	expect(board.agreement() == "breached_squad","The record says the squad broke it")
	board.free()

	var ack_file := test_path("ic-ack-record.save")
	Record.save_record(ack_file,{"version":1,"missions":{1:{"acknowledged":true},3:{"platform":"demolished","component":true}}})
	board = junction("ic-gift",ack_file)
	expect(board.acknowledged and board.component_held and not board.wary,"Carry-ins read from the record")
	board.soldiers[0]["cell"] = Vector2i(7,9)
	board.select_soldier(0)
	expect(board.pause_reason(true) == "" and board.transmit_pause(true),"With ACK-01 the pause needs no observation, and the component can go with it")
	board.phase = 1
	board.resolve_enemy_turn()
	expect(board.crew["pause"]["until"] == 1+Crew.PAUSE_ROUNDS_GIFT,"Returning the component buys a 5-round pause")
	board.soldiers[1]["cell"] = Vector2i(10,9)
	board.phase = 2
	board.last_enemy_phase = 1
	board.resolve_enemy_turn()
	expect(Crew.pause_active(board.crew),"Soldiers on the green lane don't break it")
	# Observed drone fires during the pause: the pause holds and the Drovers down the drone.
	board.drone["stage"] = "active"
	board.drone["cell"] = Vector2i(11,13)
	board.drone["observed"] = true
	board.phase = 4
	board.last_enemy_phase = 3
	board.resolve_enemy_turn()
	expect(board.drone["fired"] and board.drone["attributed"] and Crew.pause_active(board.crew),"An observed drone's shot doesn't break the pause")
	board.phase = 5
	board.last_enemy_phase = 4
	board.resolve_enemy_turn()
	expect(board.drone["outcome"] == "downed_by_drovers","Drover security turns on the drone")
	board.phase = Crew.LEAVE_ROUND
	board.last_enemy_phase = Crew.LEAVE_ROUND-1
	board.resolve_enemy_turn()
	expect(board.crew["left"] and board.crew["cargo"] == "left" and board.agreement().begins_with("honored"),"The crew loads and leaves; the agreement is honored")
	expect(board.civilian_safe(Vector2i(10,9)) and board.target_at(board.HAULER) < 0,"The junction opens when they leave")
	board.free()

	board = junction("ic-blame")
	board.drone["stage"] = "active"
	board.drone["cell"] = Vector2i(11,13)
	board.phase = 4
	board.resolve_enemy_turn()
	expect(board.drone["fired"] and not board.drone["attributed"] and Crew.hostile(board.crew,5) and not Crew.hostile(board.crew,7),"An unseen drone shot gets blamed on the squad for 2 rounds")
	board.free()

	board = junction("ic-assault")
	board.soldiers[1]["cell"] = Vector2i(9,5)
	board.crew["units"][0]["hp"] = 2
	aim_at(board,1,Vector2i(9,6))
	var ammo: int = board.soldiers[1]["ammo"]
	expect(board.suppress() and board.soldiers[1]["ammo"] == ammo-2 and board.soldiers[1]["attacked"],"Suppress costs 1 AP and 2 rounds and uses the attack")
	expect(board.crew["units"][0]["suppressed_by"] == 1 and Crew.hostile(board.crew,board.phase) and board.agreement() == "assault","Suppression provokes the crew: an assault")
	expect(board.restrain() and board.crew["units"][0]["restrained"] and board.security_tally()["restrained"] == 1,"A suppressed Drover at low HP is restrained alive")
	expect(board.target_at(Vector2i(9,6)) >= 0 and board.aimed() == "","A held Drover blocks its square but isn't a target")
	board.soldiers[2]["cell"] = Vector2i(11,6)
	board.select_soldier(2)
	var moved: bool = board.try_move(Vector2i(11,5))
	expect(moved,"Soldiers still move")
	board.crew["hauler"]["hp"] = 4
	board.soldiers[3]["cell"] = Vector2i(11,10)
	aim_at(board,3,board.HAULER)
	board.shot_rng.seed = 7
	for attempt in range(6):
		if board.crew["hauler"]["hp"] == 0: break
		board.soldiers[3]["attacked"] = false
		board.soldiers[3]["ap"] = 2
		board.soldiers[3]["ammo"] = 4
		aim_at(board,3,board.HAULER)
		board.try_fire()
	expect(board.crew["cargo"] == "seized","Disabling the hauler seizes the cargo")
	board.free()

	board = junction("ic-suppress-end")
	board.soldiers[1]["cell"] = Vector2i(9,4+1)
	aim_at(board,1,Vector2i(9,6))
	board.suppress()
	board.sight_mode = false
	board.try_move(Vector2i(8,5))
	expect(board.crew["units"][0]["suppressed_by"] == -1,"Suppression ends when the suppressor moves")
	board.free()

	var carry_file := test_path("ic-carry-record.save")
	Record.save_record(carry_file,{"version":1,"missions":{1:{"acknowledged":false},2:{"sensor":true},3:{"platform":"redirected","component":false,"squad":[{"name":"MSG","condition":"active"},{"name":"Ortiz","condition":"stable"},{"name":"Okafor","condition":"active"},{"name":"Park","condition":"dead"}]}}})
	board = junction("ic-carry",carry_file)
	expect(board.wary and board.crew["stance"] == "wary" and board.drone["revealed"],"Preserved platform makes the crew wary; the sensor reveals the drone")
	expect(board.soldiers[1]["hp"] == 4 and board.soldiers[2]["name"] == "Okafor" and board.soldiers[3]["name"] == "Reyes","Main Street wounds, names and losses carry in")
	var line: String = Crew.provoke(board.crew,1,"squad")
	expect(line.contains("warning") and not Crew.hostile(board.crew,1),"A wary crew answers the first provocation with a warning")
	Crew.provoke(board.crew,1,"squad")
	expect(Crew.hostile(board.crew,1),"The second provocation is real")
	board.phase = 1
	board.resolve_enemy_turn()
	expect(board.drone_visible(),"With the sensor the drone shows as soon as it arrives")
	board.free()

	board = junction("ic-record")
	board.soldiers[0]["extracted"] = true
	board.request_close()
	board.request_close()
	for i in range(4): await process_frame
	var entry: Dictionary = Record.interchange_entry(board)
	expect(board.result_ready and entry["mission"] == 4 and entry.has("agreement") and entry["security"]["unharmed"] == 2,"Interchange result records the agreement and Drover security")
	expect(Record.carry_forward_interchange(entry).size() >= 2,"Interchange explains what carries forward")
	expect(not Record.field_contact(entry),"No agreement, no field contact")
	expect(Record.field_contact({"retry_required":false,"agreement":"honored"}),"An honored pause makes MSG field contact")
	expect(board.result_title().begins_with("INTERCHANGE"),"Results are titled Interchange")
	board.free()
	print("INTERCHANGE FAILURES: ",failures)
	quit(1 if failures else 0)
