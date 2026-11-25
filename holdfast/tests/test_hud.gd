extends "res://tests/test_support.gd"
## Desktop HUD (game.tscn): real mouse input through the GUI, compared against direct calls.
func hud_click(point: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	for down in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.position = point
		event.pressed = down
		root.push_input(event,true)
	await process_frame
	await process_frame

func cell_point(shell, cell: Vector2i) -> Vector2:
	var local: Vector2 = shell.board.cell_to_local(cell)+Vector2(18,18)
	return shell.map_view.get_global_rect().position+shell.holder.position+local*shell.holder.scale.x

func hud_press(shell, key: String) -> void:
	var button: Button = shell.actions[key]
	if shell.widgets["sidebar_scroll"].is_ancestor_of(button): shell.widgets["sidebar_scroll"].ensure_control_visible(button)
	await process_frame
	await hud_click(button.get_global_rect().get_center())

func run() -> void:
	expect(ProjectSettings.get_setting("application/run/main_scene")=="res://game.tscn","Desktop HUD is the main scene")
	expect(int(ProjectSettings.get_setting("display/window/size/viewport_width"))==1920 and int(ProjectSettings.get_setting("display/window/size/viewport_height"))==1080,"Landscape 1920x1080 layout")
	var shell = load("res://game.tscn").instantiate()
	shell.board_auto_resume = false
	shell.board_campaign_path = test_path("hud-campaign.save")
	root.add_child(shell)
	current_scene = shell
	await process_frame
	await process_frame
	var board = shell.board
	board.report_path = test_path("hud-report.save")
	board.completion_path = test_path("hud-complete.save")
	var reference = new_board("hud-reference")
	reference.command_model = "authority"
	expect(board != null and board.hud_mode and board.command_model == "authority","Shell adopts the encounter in HUD mode with MSG command rules")
	expect(not root.get_node("Readability").overlay.visible,"Magnifier toolbar hidden under the HUD")
	for child in board.get_children():
		if child is Camera2D: expect(not child.enabled,"Legacy fixed camera disabled")
	expect(shell.holder.scale.x > 1.3,"Map is drawn larger than the legacy page (scale %.2f)" % shell.holder.scale.x)
	shell.refresh()
	expect(shell.modal_root.visible,"Opening scene shows as a readable modal")
	# Skip the opening through the modal's buttons, the same as Esc on the reference.
	var skip: Button = null
	for row in shell.modal_box.get_children():
		if row is HBoxContainer:
			for button in row.get_children():
				if button is Button and button.text.begins_with("Skip"): skip = button
	expect(skip != null,"Opening modal offers Skip")
	if skip: await hud_click(skip.get_global_rect().get_center())
	reference.finish_opening()
	expect(board.scene_view=="","Skip closes the opening")
	shell.refresh()
	expect(shell.modal_root.visible and shell.should_brief(),"Mission briefing follows the opening")
	expect(shell.widgets["priority_box"].visible and String(shell.widgets["priority"].text).contains("STOP THE MACHINE"),"Priority box warns about the machine")
	var got_it: Button = null
	for row in shell.modal_box.get_children():
		if row is HBoxContainer:
			for button in row.get_children():
				if button is Button and button.text == "Got it": got_it = button
	expect(got_it != null,"Briefing has a Got it button")
	if got_it: await hud_click(got_it.get_global_rect().get_center())
	shell.refresh()
	expect(not shell.modal_root.visible,"Modal hides after the briefing")
	# Select MSG, move one square, end the turn: HUD clicks vs. direct calls.
	var start: Vector2i = board.soldiers[0]["cell"]
	await hud_click(cell_point(shell,start))
	reference.select_soldier(0)
	expect(board.active_soldier==0,"Clicking a soldier on the map selects it")
	var destination := Vector2i(-1,-1)
	for direction in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
		if board.move_cost(start+direction)==1:
			destination = start+direction
			break
	expect(destination != Vector2i(-1,-1),"A 1 AP square exists next to MSG")
	await hud_click(cell_point(shell,destination))
	reference.hovered_cell = destination
	reference.try_move(destination)
	expect(board.soldiers[0]["cell"]==destination,"Clicking a green square moves the soldier")
	await hud_click(cell_point(shell,destination),MOUSE_BUTTON_RIGHT)
	reference.run_tactical_command("clear")
	expect(board.active_soldier==-1,"Right-click clears the selection")
	await hud_press(shell,"next")
	reference.next_phase()
	expect(board.phase==2,"End turn button advances the round")
	board.hovered_cell = reference.hovered_cell
	expect(var_to_bytes(board.encounter_snapshot())==var_to_bytes(reference.encounter_snapshot()),"HUD play matches direct play exactly")
	# Civilian group button + order button.
	await hud_press(shell,"group1")
	reference.cohort_selected = 1
	expect(board.cohort_selected==1,"Group button selects the group")
	await hud_press(shell,"exit")
	reference.order_exit(1)
	expect(var_to_bytes(board.encounter_snapshot())==var_to_bytes(reference.encounter_snapshot()),"Civilian order via HUD matches direct call")
	# Keyboard shortcuts still reach the controller.
	var key := InputEventKey.new()
	key.keycode = KEY_T
	key.pressed = true
	root.push_input(key,true)
	await process_frame
	expect(board.sight_mode,"T still toggles aim mode under the HUD")
	# Campaign: operations board and the record Farm Road leaves behind.
	var Record = load("res://systems/campaign_record.gd")
	if FileAccess.file_exists(shell.campaign_record_path): DirAccess.remove_absolute(shell.campaign_record_path)
	expect(shell.campaign_record_path != Record.PATH,"Tests never touch the player's campaign record")
	expect(String(shell.widgets["mission"].text).contains("Mission 01"),"Top bar places Farm Road in the campaign")
	shell.open_operations()
	shell.refresh()
	var briefed := false
	for child in shell.modal_box.get_children():
		if child is Label and String(child.text).contains("REGIONAL AIRFIELD"): briefed = true
	expect(shell.modal_root.visible and briefed,"Operations board shows the arc and briefs Mission 08")
	shell.close_operations()
	board.soldiers[0]["extracted"] = true
	board.request_close()
	board.request_close()
	for i in range(4): await process_frame
	shell.refresh()
	var record: Dictionary = Record.load_record(shell.campaign_record_path)
	expect(board.result_ready and record["missions"].has(1),"Finishing Farm Road writes the campaign record")
	if record["missions"].has(1):
		expect(record["missions"][1]["machine"] == Record.machine_state(board) and record["missions"][1]["evacuated"] == board.evacuated_people(),"Record matches the mission's outcome")
		expect(Record.carry_forward(record["missions"][1]).size() >= 3,"Record explains what carries forward")
	# Mission 02 launches from the operations board in HUD mode.
	shell.play_river_bridge()
	await process_frame
	shell.refresh()
	expect(shell.is_river() and shell.board.hud_mode and shell.board.command_model == "authority","River Bridge launches in the HUD")
	expect(String(shell.widgets["mission"].text).contains("Mission 02") and shell.actions["lanes_people"].visible,"HUD shows River Bridge controls")
	expect(shell.modal_root.visible,"River Bridge opens with its story")
	# Mission 03 launches the same way, with its own controls.
	shell.play_main_street()
	await process_frame
	shell.refresh()
	expect(shell.is_main() and shell.board.hud_mode and shell.board.command_model == "authority","Main Street launches in the HUD")
	expect(String(shell.widgets["mission"].text).contains("Mission 03") and shell.actions["interrupt"].visible and shell.actions["component"].visible and shell.actions["breaker"].visible and not shell.actions["lanes_people"].visible,"HUD shows Main Street controls")
	shell.board.finish_opening()
	shell.refresh()
	expect(shell.should_brief() and String(shell.widgets["priority"].text).contains("STOP THE PLATFORM"),"Main Street briefs and points at the platform")
	# Mission 04 launches with its own controls.
	shell.play_interchange()
	await process_frame
	shell.refresh()
	expect(shell.is_interchange() and shell.board.hud_mode and String(shell.widgets["mission"].text).contains("Mission 04"),"Interchange launches in the HUD")
	expect(shell.actions["ic_pause"].visible and shell.actions["suppress"].visible and not shell.actions["breaker"].visible and not shell.actions["observe"].visible and not shell.actions["interrupt"].visible,"HUD shows Interchange controls only")
	shell.board.finish_opening()
	shell.refresh()
	expect(shell.should_brief() and String(shell.widgets["priority"].text).contains("OPEN THE JUNCTION"),"Interchange briefs and points at the junction")
	# Mission 05 launches with its own controls.
	shell.play_rail_yard()
	await process_frame
	shell.refresh()
	expect(shell.is_rail() and shell.board.hud_mode and String(shell.widgets["mission"].text).contains("Mission 05"),"Rail Yard launches in the HUD")
	expect(shell.actions["ry_cut"].visible and shell.actions["ry_download"].visible and not shell.actions["ic_pause"].visible and not shell.actions["breaker"].visible,"HUD shows Rail Yard controls only")
	shell.board.finish_opening()
	shell.refresh()
	expect(shell.should_brief() and String(shell.widgets["priority"].text).contains("FREE THE PENS"),"Rail Yard briefs and points at the pens")
	# Mission 06 launches with its own controls.
	shell.play_county_hospital()
	await process_frame
	shell.refresh()
	expect(shell.is_hospital() and shell.board.hud_mode and String(shell.widgets["mission"].text).contains("Mission 06"),"County Hospital launches in the HUD")
	expect(shell.actions["ch_power_ambulance"].visible and shell.actions["ch_detain"].visible and shell.actions["ch_hold"].visible and not shell.actions["ry_cut"].visible and not shell.actions["breaker"].visible,"HUD shows County Hospital controls only")
	expect(String(shell.widgets["civ_how"].text).contains("SCREENING"),"The civilian panel lists the persons of interest")
	shell.board.finish_opening()
	shell.refresh()
	expect(shell.should_brief() and String(shell.widgets["priority"].text).contains("ASSIGN POWER"),"County Hospital briefs and points at the power")
	# Mission 07 launches with its own controls.
	shell.play_quarry()
	await process_frame
	shell.refresh()
	expect(shell.is_quarry() and not shell.is_main() and shell.board.hud_mode and String(shell.widgets["mission"].text).contains("Mission 07"),"Quarry launches in the HUD")
	expect(shell.actions["q_charge"].visible and shell.actions["q_controller"].visible and not shell.actions["q_rig_move"].visible and not shell.actions["ch_load"].visible and not shell.actions["breaker"].visible,"HUD shows Quarry controls only (no rig without the Farm Road record)")
	shell.board.finish_opening()
	shell.refresh()
	expect(shell.should_brief() and String(shell.widgets["priority"].text).contains("haul tunnel"),"Quarry briefs and points at the tunnel")
	# Mission 08 launches with its own controls.
	shell.play_airfield()
	await process_frame
	shell.refresh()
	expect(shell.is_airfield() and shell.board.hud_mode and String(shell.widgets["mission"].text).contains("Mission 08"),"Regional Airfield launches in the HUD")
	expect(shell.actions["af_contact"].visible and shell.actions["af_shield"].visible and not shell.actions["af_cut"].visible and not shell.actions["q_charge"].visible and not shell.actions["breaker"].visible,"HUD shows Airfield controls only (no pod without Rail Yard captives)")
	shell.board.finish_opening()
	shell.refresh()
	expect(shell.should_brief() and String(shell.widgets["priority"].text).contains("MAKE CONTACT"),"Airfield briefs and points at the contact window")
	# New game from Extras: confirm, then a fresh Farm Road board is adopted.
	shell.open_extra(2)
	shell.refresh()
	expect(shell.modal_root.visible,"New game asks for confirmation")
	var old = shell.board
	shell.new_game()
	await process_frame
	shell.refresh()
	expect(shell.board != old and shell.board.hud_mode and shell.board.phase==1 and not shell.board.return_state["active"],"New game starts a fresh Farm Road in HUD mode")
	expect(String(shell.widgets["civ_how"].text).contains("MSG can order"),"Civilian panel explains the command rules")
	current_scene = null
	shell.free()
	reference.free()
	print("HUD FAILURES: ",failures)
	quit(1 if failures else 0)
