extends "res://tests/test_support.gd"

func run() -> void:
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
		for y in range(16):
			for x in range(20):
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
