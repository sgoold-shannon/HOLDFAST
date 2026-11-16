extends "res://tests/test_support.gd"

func run() -> void:
	var main = new_board("narrative")
	var legacy = load("res://farm_return.tscn").instantiate()
	legacy.auto_resume = false
	legacy.campaign_path = test_path("legacy-campaign.save")
	root.add_child(legacy)
	legacy.report_path = test_path("legacy-report.save")
	legacy.completion_path = test_path("legacy-complete.save")
	for scenario in ["opening","historical","casualty","vacancy","return"]:
		for board in [main,legacy]:
			board.campaign["deployment"] = 2 if scenario=="historical" else 1
			board.return_state["active"] = scenario=="return"
			board.campaign["missions"] = [{"feeder":"Feeder intact; skid not collected."}] if scenario=="return" else []
			board.soldiers[1]["condition"] = "dead" if scenario=="casualty" else "active"
			board.soldiers[2]["actor_id"] = "" if scenario=="vacancy" else "bell"
			board.scene_view = "opening"
			board.scene_page = 0
		expect(main.log_pages()==legacy.log_pages(),scenario+": log content parity")
		expect(main.debrief_pages()==legacy.debrief_pages(),scenario+": debrief content parity")
		expect(main.scene_options()==legacy.scene_options(),scenario+": available choice parity")
		for index in range(4):
			expect(main.present(index)==legacy.present(index) and main.soldier_disposition(index)==legacy.soldier_disposition(index),scenario+": survivor and vacancy parity")
		for board in [main,legacy]:
			board.choose_scene_option(0)
			board.advance_scene()
		expect(main.story_state_snapshot()==legacy.story_state_snapshot() and main.scene_page==legacy.scene_page and main.scene_view==legacy.scene_view,scenario+": choice and navigation parity")
	main.free()
	legacy.free()
	print("NARRATIVE PARITY FAILURES: ",failures)
	quit(1 if failures else 0)
