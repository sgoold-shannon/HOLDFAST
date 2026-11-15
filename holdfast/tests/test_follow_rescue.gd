extends "res://tests/test_support.gd"
func follow_order(board,index: int) -> void:
	select(board,0)
	click(board,Vector2(900,150+index*112))
	click(board,board.FOLLOW_RECT.get_center())
	expect(board.cohorts[index]["order"] == "follow" and board.cohorts[index]["leader"] == 0,"Group follows MSG through input handlers")
func run() -> void:
	var board = new_board("follow-origin")
	board.finish_opening()
	for turn in range(12):
		if board.ended: break
		if board.phase <= 3: follow_order(board,board.phase-1)
		if board.phase == 1:
			for index in range(4):
				select(board,index)
				expect(invoke(board,"try_move",[Vector2i(7,[6,7,9,10][index])]),"Reach firing position legally")
				board.sight_mode = true
				board.pinned_target = board.enemies[0]["cell"]
				expect(invoke(board,"try_fire"),"Fire legal first-round volley")
				board.sight_mode = false
		else:
			for index in range(4):
				if index != 0 or board.phase >= 3: evacuate(board,index)
		if board.phase == 3:
			expect(board.save_encounter(test_path("follow-mid.save")),"Save following groups")
			var exact: Dictionary = board.encounter_snapshot()
			expect(board.load_encounter(test_path("follow-mid.save")) and board.encounter_snapshot() == exact,"Restore exact following state")
		press(board,KEY_N)
	await process_frame
	expect(board.ended and board.evacuated_people()==12 and board.all_extracted(),"All following civilians and squad evacuate")
	print("FOLLOW ORIGIN: round=",board.phase," civilians=",board.evacuated_people()," squad=",board.all_extracted())
	var prior: Dictionary = board.campaign["missions"][0].duplicate(true)
	press(board,KEY_G)
	press(board,KEY_ENTER)
	var ret = root.get_child(root.get_child_count()-1)
	expect(ret != board and ret.return_state["active"],"Deploy return through controls")
	for turn in range(12):
		if ret.ended: break
		if ret.phase <= 3: follow_order(ret,ret.phase-1)
		for index in range(4):
			if index != 0 or ret.phase >= 3: evacuate(ret,index)
		press(ret,KEY_N)
	await process_frame
	expect(ret.ended and ret.evacuated_people()==12 and ret.all_extracted(),"Follow works through northbound return")
	expect(ret.campaign["missions"][0] == prior,"Return preserves first mission")
	print("FOLLOW RETURN: round=",ret.phase," civilians=",ret.evacuated_people()," squad=",ret.all_extracted())
	ret.queue_free()
	await process_frame
	await wounded_follow()
	print("FOLLOW END-TO-END FAILURES: ",failures)
	quit(1 if failures else 0)
func wounded_follow() -> void:
	var board = new_board("follow-wounded")
	board.finish_opening()
	for turn in range(12):
		if board.ended: break
		if board.phase == 1:
			follow_order(board,0)
			select(board,0)
			expect(invoke(board,"try_move",[Vector2i(9,8)]),"Leader enters warning cell legally")
			select(board,1)
			expect(invoke(board,"try_move",[Vector2i(8,8)]),"Medic reaches rescue position")
		elif board.phase == 2: expect(board.order_exit(1),"Order second group")
		elif board.phase == 3:
			expect(board.soldiers[0]["condition"] == "critical", "Leader critically wounded by actual machine impacts")
			expect("Leader down" in board.cohorts[0]["note"],"Followers explicitly wait for downed leader")
			expect(board.order_exit(2),"Order third group")
			select(board,1)
			click(board,board.cell_to_local(Vector2i(9,8))+Vector2(18,18))
			press(board,KEY_S)
			press(board,KEY_U)
			expect(board.soldiers[1]["carrying"]==0,"Medic stabilizes and carries leader")
		elif board.phase == 4: expect(board.order_exit(0),"Waiting followers accept replacement exit order")
		if board.phase >= 4: evacuate(board,1)
		for index in [2,3]: evacuate(board,index)
		press(board,KEY_N)
	await process_frame
	expect(board.ended and not board.retry_required() and board.soldiers[0]["extracted"],"Wounded leader rescue reaches completion")
	print("FOLLOW WOUNDED: round=",board.phase," civilians=",board.evacuated_people()," rescued MSG=",board.soldiers[0]["extracted"])
	board.queue_free()
	await process_frame
