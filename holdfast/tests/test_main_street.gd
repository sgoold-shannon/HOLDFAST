extends "res://tests/test_support.gd"
## Mission 03 · Main Street: platform, junction box / control panel, Fallow mark → transform,
## node interrupt, Drover component, record, Act I close, carry-over.
const Fallow = preload("res://systems/fallow_cutter.gd")
const Record = preload("res://systems/campaign_record.gd")
const Arc = preload("res://data/campaign_arc.gd")

func town(label: String, record: String = ""):
	var board = load("res://main_street.tscn").instantiate()
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
	var board = town("ms-load")
	expect(board.mission_definition().mission_id == "main_street" and board.machine_present(),"Main Street loads with the platform")
	expect(board.enemies[0]["hp"] == 24 and board.deadline() == 9,"Platform has 24 HP; corridor closes after round 9")
	expect(board.opening_pages().size() == 3 and board.scene_options().is_empty(),"Main Street has its own opening, no forced choice")
	expect(board.drover["present"] and board.target_at(board.drover["cell"]) == 20,"Drover security walks beside the platform")
	expect(not board.civilian_safe(board.drover["cell"]),"Civilians path around Drover security")
	expect(board.fallow["stage"] == "waiting" and board.FIXTURES.size() == 2,"No Fallow and no rifts at the start")
	expect(Arc.mission(3)["status"] == "playable" and Arc.mission(3).has("briefing"),"Mission 03 is playable with a briefing")
	board.select_soldier(0)
	board.sight_mode = true
	board.pinned_target = board.drover["cell"]
	expect(board.fire_block_reason().contains("isn't a target"),"Drover security can't be shot")
	board.sight_mode = false
	board.pinned_target = board.NONE
	board.free()

	board = town("ms-substation")
	board.machine["stage"] = board.mission_definition().machine_collect_stage
	board.enemies[0]["cell"] = board.SKID_CELL
	board.phase = 6
	board.resolve_enemy_turn()
	expect(board.machine["collected_round"] == 6 and board.deadline() == 8,"Reaching the substation closes the corridor two rounds later")
	expect(board.platform_state() == "substation","Platform state records the substation")
	board.free()

	board = town("ms-fallow")
	var fallow: Dictionary = board.fallow
	board.phase = 2
	Fallow.act(fallow,board)
	expect(fallow["stage"] == "waiting","Nothing before round 3")
	board.phase = 3
	Fallow.act(fallow,board)
	expect(fallow["stage"] == "signaled","Round 3: the distortion is shown first")
	expect(Fallow.threat_cells(fallow).is_empty(),"A signal alone isn't a threat")
	board.phase = 4
	board.update_drover()
	Fallow.act(fallow,board)
	expect(fallow["stage"] == "active" and fallow["marked"].size() == Fallow.STRIP_WITH_NODE,"Round 4: the cutter arrives and marks 4 squares with its node linked")
	expect(board.drover["component"] != board.NONE,"Drover security drops its component when the cutter arrives")
	var marked: Vector2i = fallow["marked"][0]
	expect(board.civilian_threats().has(marked),"Marked ground scares civilians")
	board.soldiers[1]["cell"] = marked
	var hp: int = board.soldiers[1]["hp"]
	board.phase = 5
	Fallow.act(fallow,board)
	expect(fallow["rifts"].has(marked) and board.FIXTURES.has(marked),"Marked ground becomes rift the next Fallow turn")
	expect(board.soldiers[1]["hp"] == hp-Fallow.RIFT_DAMAGE and board.soldiers[1]["cell"] != marked,"Anyone on it takes 4 and is thrown clear")
	expect(not board.is_walkable(marked),"Rift ground is impassable")
	board.free()

	board = town("ms-exit")
	board.fallow["stage"] = "active"
	board.cohorts[0]["cell"] = Vector2i(18,8)
	Fallow.mark(board.fallow,board)
	var clear: bool = not board.fallow["marked"].is_empty()
	for cell in board.fallow["marked"]: clear = clear and cell.x <= board.GRID_SIZE.x-Fallow.EXIT_MARGIN
	expect(clear,"Marks never land on the exit columns")
	expect(board.sheltered_from_fallow(Vector2i(15,8)) and board.sheltered_from_fallow(Vector2i(15,3)),"Route waypoints are never marked")
	board.free()

	var fresh = town("ms-fresh")
	expect(fresh.FIXTURES.size() == 2,"Rifts from one attempt don't leak into the next")
	fresh.free()

	board = town("ms-interrupt")
	fallow = board.fallow
	board.phase = 3
	Fallow.act(fallow,board)
	board.phase = 4
	Fallow.act(fallow,board)
	var strip: Array = fallow["marked"].duplicate()
	board.soldiers[3]["cell"] = fallow["node"]+Vector2i(0,1)
	board.select_soldier(3)
	var ap: int = board.soldiers[3]["ap"]
	expect(board.interrupt_node() and board.soldiers[3]["ap"] == ap-1,"A soldier next to the node interrupts it for 1 AP")
	expect(not board.interrupt_node(),"One interrupt per turn")
	board.phase = 5
	Fallow.act(fallow,board)
	expect(fallow["rifts"].is_empty() and fallow["marked"] == strip and not fallow["interrupted"],"Interrupted: the strip holds one turn, then the link comes back")
	Fallow.take_hit(fallow,0,Fallow.SHOT_DAMAGE)
	Fallow.take_hit(fallow,0,Fallow.SHOT_DAMAGE)
	var line := Fallow.take_hit(fallow,0,Fallow.SHOT_DAMAGE)
	expect(not Fallow.cutter_alive(fallow) and fallow["marked"].is_empty() and line.contains("folds"),"Three hits kill the cutter and clear its marks")
	expect(Fallow.node_present(fallow),"The node can't be destroyed")
	board.free()

	board = town("ms-redirect")
	board.protocol["diverted"] = true
	board.protocol["component_collected"] = true
	board.enemies[0]["cell"] = Vector2i(13,3)
	board.phase = 5
	board.resolve_enemy_turn()
	expect(not board.machine["departed"] and board.platform_parked(),"A redirected platform parks instead of leaving")
	expect(board.sheltered_from_fallow(Vector2i(13,2)) and not board.sheltered_from_fallow(Vector2i(10,8)),"Ground beside the parked platform is sheltered from marks")
	expect(not board.civilian_threats().has(Vector2i(13,3)),"The parked platform doesn't scare civilians")
	expect(board.platform_state() == "redirected","Platform state records the redirect")
	board.free()

	board = town("ms-record")
	board.drover["component"] = Vector2i(8,7)
	board.drover["present"] = false
	board.soldiers[2]["cell"] = Vector2i(8,6)
	board.select_soldier(2)
	expect(board.recover_component() and board.drover["recovered"],"A soldier next to the component recovers it")
	board.enemies[0]["hp"] = 0
	board.soldiers[0]["extracted"] = true
	board.request_close()
	board.request_close()
	for i in range(4): await process_frame
	var entry: Dictionary = Record.main_street_entry(board)
	expect(board.result_ready and entry["mission"] == 3 and entry["platform"] == "demolished" and entry["component"],"Main Street result records the platform and the component")
	var carry: Array = Record.carry_forward_main(entry)
	expect(carry.size() >= 3 and carry.back().begins_with("ACT I COMPLETE"),"Main Street closes Act I")
	expect(Record.act_one_complete({"missions":{3:entry}}),"Act I complete once Main Street is recorded")
	expect(board.result_title().begins_with("MAIN STREET"),"Results are titled Main Street")
	expect(board.debrief_pages().back()["speaker"].begins_with("ACT I COMPLETE"),"Debrief ends on the Act I close")
	board.free()

	var record_file := test_path("ms-carry-record.save")
	Record.save_record(record_file,{"version":1,"missions":{2:{"squad":[{"name":"MSG","condition":"active"},{"name":"Reyes","condition":"active"},{"name":"Bell","condition":"dead"},{"name":"Park","condition":"critical"}]}}})
	board = town("ms-carry",record_file)
	expect(board.soldiers[1]["name"] == "Reyes","A replacement from River Bridge keeps their name")
	expect(board.soldiers[2]["name"] == "Okafor" and board.soldiers[2]["replacement_for"] == "Bell","A soldier lost at River Bridge is replaced without doubling a name")
	expect(board.soldiers[3]["hp"] == 4,"River Bridge wounds carry into Main Street")
	board.free()
	print("MAIN STREET FAILURES: ",failures)
	quit(1 if failures else 0)
