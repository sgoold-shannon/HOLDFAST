extends RefCounted
## Story flow: who knows what, the opening briefing, evidence, debrief pages, the scene
## log and the choices between pages. Moved out of encounter_controller.gd; the controller
## keeps one-line wrappers.

static func apply_rescue_knowledge(board, actor: int) -> void:
	board.rescue_events[-1]["closure_warning"] = board.closure_warning
	# The acting soldier knows the action; an unconscious patient is not assumed to.
	board.knowledge[actor].append(board.rescue_events[-1]["id"])

static func update_closure_knowledge(board) -> void:
	if not board.ended and board.phase >= 3: board.closure_warning = true

static func present(board, index: int) -> bool:
	return board.soldiers[index].get("actor_id","") != "" and board.soldiers[index]["extracted"] and ["active","stable"].has(board.soldiers[index]["condition"])

static func original_actor(board, index: int, original_name: String) -> bool:
	return board.soldiers[index].get("actor_id","") == original_name.to_lower()

static func knows(board, index: int, fact: String) -> bool:
	return present(board, index) and board.knowledge[index].has(fact)

static func deliver_briefing(board) -> void:
	for index in range(4):
		if not present(board, index): continue
		for fact in ["outcomes","machinery"]:
			if not board.knowledge[index].has(fact): board.knowledge[index].append(fact)
		for event in board.rescue_events:
			if not board.knowledge[index].has(event["id"]): board.knowledge[index].append(event["id"])
	board.persist_story_report()

static func opening_pages(board) -> Array:
	return [
		{"speaker":"EXERCISE CHECKPOINT / BEFORE 09:17", "text":"Ortiz: ‘Patients wait in the shade. That buys us time.’\n\nBell: ‘If the truck cannot turn, nobody leaves.’\n\nPark moves a folding chair outside the turning arc.\n‘Both fit. Unless the next truck is bigger.’", "tag":"Ortiz · medic    Bell · engineer    Park · reconnaissance"},
		{"speaker":"09:17 / NORTHERN RIDGE", "text":"A vertical distortion crosses the ridge. No explosion. The power trips. Radio recordings lose eleven seconds.\n\nPark closes his paper notebook. ‘That was not in the exercise.’\n\nA recovery machine emerges through the old service gate.","tag":"Observed disruption / cause unknown"},
		{"speaker":"MAJOR ELENA WARD / TASK FORCE ALDER", "text":"‘Move the civilians east toward town. Keep the Farm Road junction usable. Report what you can verify.’\n\nA broken municipal transmission cuts through:\n‘Clear the service lane. Do not cut the buried feeder. People below need that power.’\n\nThe sender is unverified. The return channel is damaged.","tag":"Protect the route · evacuate civilians · extract the squad"}
	]

static func report_text(board) -> String:
	var text = "Civilians: %d evacuated; %d stranded.\n" % [board.evacuated_people(),12-board.evacuated_people()]
	for cohort in board.cohorts:
		text += "Group %s: %s.\n" % [cohort["id"],"four evacuated" if cohort["status"] == "extracted" else "four stranded; fate unconfirmed"]
	text += "\n"
	for index in range(4): text += "%s: %s.\n" % [board.soldiers[index]["name"],board.soldier_disposition(index)]
	return text

static func evidence_pages(board) -> Array:
	var recoveries: Array[String] = []
	for event in board.rescue_events:
		var line = "%s: %s %s." % [board.soldiers[event["actor"]]["name"],{"stabilized":"stabilized","picked_up":"picked up","extracted_with":"carried out"}[event["kind"]],board.soldiers[event["casualty"]]["name"]]
		if not recoveries.has(line): recoveries.append(line)
	if recoveries.is_empty(): recoveries.append("No casualty recovery actions recorded.")
	var pages: Array = []
	for first in range(0,recoveries.size(),6):
		var evidence = board.machine_outcome()+"\n"+board.feeder_result()+"\n"+("ACK-01 received; a bounded channel only." if board.protocol["acknowledged"] else "No protocol acknowledgement recorded.")+"\n\n"+"\n".join(recoveries.slice(first,first+6))
		pages.append({"speaker":"VERIFIED RECORD / READ TO SURVIVORS","text":evidence,"tag":"Available survivors receive these facts before personal dialogue."})
	return pages

static func origin_debrief_pages(board) -> Array:
	var pages: Array = [{"speaker":"FARM ROAD / VERIFIED FIELD REPORT","text":report_text(board),"tag":"This report is read to the available survivors before discussion."}]
	pages.append_array(evidence_pages(board))
	var machine_text := "The machine remained active when we withdrew. No intervention was completed."
	if board.enemies[0]["hp"] <= 0:
		machine_text = "Machine is down. Its cooling unit is gone."
	elif board.disabled():
		machine_text = "Drive isolated. The gates lost power with it."
	elif board.protocol["diverted"]:
		var used := false
		for cohort in board.cohorts:
			used = used or (board.powered_gate_groups.has(cohort["id"]) and cohort["status"] == "extracted")
		machine_text = "The feeder stayed up. That gave the last group a route." if used else "The feeder stayed up. We kept that option."
	elif board.machine["departed"]:
		machine_text = "The machine departed without an intervention resolving it."
	pages.append({"speaker":"BELL" if original_actor(board, 2,"Bell") and knows(board, 2,"machinery") else "TECHNICAL RECORD",
		"text":machine_text+"\n\n"+board.feeder_result()+"\n\nA bounded protocol response does not establish an alliance." if board.protocol["acknowledged"] else machine_text+"\n\n"+board.feeder_result()+"\n\nNo protocol acknowledgement was recorded.",
		"tag":"Recorded machinery outcome / wider purpose unconfirmed"})
	var deaths: Array[String] = []
	for soldier in board.soldiers:
		if soldier["condition"] == "dead": deaths.append(soldier["name"])
	if not deaths.is_empty():
		pages.append({"speaker":"REST AREA / CASUALTY REPORT","text":"Confirmed dead: %s.\n\nAn empty place remains at the rest area. The casualty report replaces the usual conversation." % ", ".join(deaths),"tag":"Confirmed loss / no invented recovery"})
	elif original_actor(board, 1,"Ortiz") and original_actor(board, 3,"Park") and present(board, 1) and present(board, 3):
		for event in board.rescue_events:
			if event["kind"] == "stabilized" and event["actor"] == 1 and event["casualty"] == 3 and knows(board, 1,event["id"]) and knows(board, 3,event["id"]):
				pages.append({"speaker":"PARK / ORTIZ", "text":("Park: ‘You came back when the lane was closing.’" if event["closure_warning"] else "Park: ‘You came back for me.’")+"\n\nOrtiz: ‘You were still on this side of it.’\n\nTreatment continues. Extraction has not erased the injury.","tag":"Verified stabilization / both present and briefed"})
				break
	var response_text := "The report stays open for correction. What does the MSG say?"
	if not present(board, 0) or board.soldiers[0]["condition"] != "active":
		response_text = "The MSG remains under medical care. Discussion waits for treatment; the verified report stands."
	elif board.debrief_response != "unset":
		response_text = response_line(board, board.debrief_response)
	pages.append({"speaker":"MSG / THE RECORD", "text":response_text,"tag":"Acknowledgement changes no casualty or civilian totals."})
	return pages

static func response_line(board, value: String) -> String:
	match value:
		"cost": return "‘Keep the people we brought out and the people we lost in the same report.’"
		"correction": return "‘Correct anything we cannot support. Keep the observation separate from the assessment.’"
		"treatment": return "‘Treatment first. We can talk when everyone who can be helped is being helped.’"
	return ""

static func choose_opening(board, value: String) -> void:
	if board.opening_done or board.opening_step != 0 or not ["procedure","patients","logistics"].has(value): return
	board.preference = value
	board.opening_step = 1
	board.scene_page = 1
	board.queue_redraw()

static func begin_debrief(board) -> bool:
	if not board.result_ready or board.retry_required(): return false
	board.scene_view = "debrief"
	board.scene_page = 0
	board.queue_redraw()
	return true

static func choose_response(board, value: String) -> void:
	if board.scene_view != "debrief" or board.scene_page != board.debrief_pages().size()-1 or board.debrief_response != "unset" or not present(board, 0) or board.soldiers[0]["condition"] != "active" or not ["cost","correction","treatment"].has(value): return
	board.debrief_response = value
	board.persist_story_report()
	board.queue_redraw()

static func origin_log_pages(board) -> Array:
	var pages := opening_pages(board)
	pages.append({"speaker":"MSG / SAVED DIALOGUE PREFERENCE","text":"Opening choice: %s\n\nThis preference changes no combat stats." % {"unset":"Not chosen yet.","skipped":"Opening skipped; no preference selected.","procedure":"Mark both spaces, then check the route.","patients":"Ortiz, walk me through the slowest patient.","logistics":"Bell, show me the failure point."}[board.preference],"tag":"Dialogue record"})
	pages.append({"speaker":"INTELLIGENCE / OBSERVATION & ASSESSMENT", "text":("FACT: retrieving a marked component.\n\nASSESSMENT: evacuation equipment — unconfirmed." if board.protocol["observed"] else "No close observation has been completed.\n\nThe machine’s purpose is unconfirmed.")+ ("\n\nACK-01 received. This verifies a bounded channel only." if board.protocol["acknowledged"] else "\n\nNo protocol acknowledgement recorded."),"tag":"Facts and interpretation kept separate"})
	if board.result_ready and not board.retry_required(): pages.append_array(board.debrief_pages())
	return pages

static func current_pages(board) -> Array:
	if board.scene_view == "opening": return opening_pages(board)
	if board.scene_view == "debrief": return board.debrief_pages()
	return board.log_pages()

static func toggle_log(board) -> void:
	if board.scene_view == "log":
		board.scene_view = board.return_view
		board.scene_page = board.return_page
	else:
		board.return_view = board.scene_view
		board.return_page = board.scene_page
		board.scene_view = "log"
		board.scene_page = 0
	board.queue_redraw()

static func advance_origin_scene(board) -> void:
	if board.scene_view == "opening" and board.scene_page == 0: return
	if board.scene_view == "debrief" and board.scene_page == evidence_pages(board).size(): deliver_briefing(board)
	if board.scene_page+1 < current_pages(board).size():
		board.scene_page += 1
		if board.scene_view == "opening": board.opening_step = board.scene_page
	elif board.scene_view == "opening": board.finish_opening()
	elif board.scene_view == "log": toggle_log(board)
	else: board.scene_view = ""
	board.queue_redraw()

static func choose_origin_scene_option(board, index: int) -> void:
	if board.scene_view == "opening": choose_opening(board, ["procedure","patients","logistics"][index])
	elif board.scene_view == "debrief": choose_response(board, ["cost","correction","treatment"][index])

static func origin_scene_options(board) -> Array:
	if board.scene_view == "opening" and board.scene_page == 0:
		return ["Mark both spaces, then check the route.","Ortiz, walk me through the slowest patient.","Bell, show me the failure point."]
	if board.scene_view == "debrief" and board.scene_page == board.debrief_pages().size()-1 and board.debrief_response == "unset" and present(board, 0) and board.soldiers[0]["condition"] == "active":
		return ["Acknowledge the cost.","Ask for factual corrections.","Defer discussion until treatment."]
	return []
