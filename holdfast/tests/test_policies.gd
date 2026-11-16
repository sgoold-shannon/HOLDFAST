extends "res://tests/test_support.gd"

func run() -> void:
	var search = preload("res://systems/movement_search.gd")
	var directions := [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i.UP]
	var walkable := func(cell: Vector2i): return cell.x>=0 and cell.x<4 and cell.y>=0 and cell.y<4 and cell!=Vector2i(1,0)
	var found: Dictionary = search.reachable(Vector2i.ZERO,3,directions,walkable)
	expect(not found["distances"].has(Vector2i(1,0)) and found["distances"][Vector2i(1,1)]==2,"Search routes around blocked cells")
	expect(found["parents"][Vector2i(1,2)]==Vector2i(1,1),"Equal routes retain supplied direction priority")
	expect(not found["distances"].has(Vector2i(3,3)),"Search respects movement budget")
	var zero: Dictionary = search.reachable(Vector2i.ZERO,0,directions,walkable)
	expect(zero["distances"]=={Vector2i.ZERO:0} and zero["parents"].is_empty(),"Zero budget retains only the origin")
	found["distances"].clear()
	expect(search.reachable(Vector2i.ZERO,3,directions,walkable)["distances"].size()>1,"Separate searches do not share mutable results")
	var main = new_board("policies")
	var legacy = load("res://farm_return.tscn").instantiate()
	legacy.auto_resume = false
	legacy.campaign_path = test_path("legacy.save")
	root.add_child(legacy)
	for scenario in ["origin","disabled","casualty","carrying","ended","return"]:
		for board in [main,legacy]:
			board.breaker_progress = 2 if scenario=="disabled" else 0
			board.return_state["active"] = scenario=="return"
			board.ended = scenario=="ended"
			board.soldiers[1]["condition"] = "critical" if scenario=="casualty" else "active"
			board.soldiers[0]["carrying"] = 1 if scenario=="carrying" else -1
			board.soldiers[1]["carried_by"] = 0 if scenario=="carrying" else -1
			board.active_soldier = 0
			board.machine["pending_shot"] = Vector2i(6,6)
		for y in range(1,17):
			for x in range(1,21):
				var cell := Vector2i(x,y)
				expect(main.is_walkable(cell)==legacy.is_walkable(cell),scenario+": walkability parity")
				expect(main.civilian_safe(cell)==legacy.civilian_safe(cell),scenario+": civilian safety parity")
				expect(main.target_at(cell)==legacy.target_at(cell),scenario+": target parity")
				expect(main.cell_occupied_by_people(cell)==legacy.cell_occupied_by_people(cell),scenario+": occupancy parity")
		for index in range(-1,5):
			expect(main.soldier_can_act(index)==legacy.soldier_can_act(index),scenario+": eligibility parity")
		for order in ["north","south","follow","hold"]:
			expect(main.civilian_waypoint(order)==legacy.civilian_waypoint(order),scenario+": waypoint parity")
		for action in ["observe","transmit","authenticate","divert"]:
			expect(main.protocol_reason(action)==legacy.protocol_reason(action),scenario+": protocol rejection parity")
		expect(main.fire_block_reason()==legacy.fire_block_reason(),scenario+": firing rejection parity")
		expect(main.breaker_reason()==legacy.breaker_reason(),scenario+": breaker rejection parity")
		expect(main.machine_plan()==legacy.machine_plan() and main.next_machine_cell()==legacy.next_machine_cell(),scenario+": activation plan parity")
		expect(main.mission_definition()==legacy.mission_definition(),scenario+": mission selection parity")
	main.free()
	legacy.free()
	print("POLICY PARITY FAILURES: ",failures)
	quit(1 if failures else 0)
