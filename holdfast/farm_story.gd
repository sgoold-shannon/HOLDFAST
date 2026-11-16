extends "res://farm_results.gd"
const ModalInput = preload("res://presentation/modal_input.gd")
const StoryPanel = preload("res://presentation/story_panel.gd")
## C1: authored scenes consume recorded facts; dialogue never changes combat values.
const STORY_SLOT := "user://holdfast_c1.save"
const DEBRIEF_RECT := Rect2(744,945,320,40)
const NEXT_RECT := Rect2(60,1030,480,58)
const SKIP_RECT := Rect2(560,1030,480,58)
const LOG_RECT := Rect2(560,1110,480,48)
var opening_done := false
var opening_step := 0
var preference := "unset"
var debrief_response := "unset"
var closure_warning := false
var powered_gate_groups: Array = []
var knowledge: Array = [[],[],[],[]]
var scene_view := "opening"
var scene_page := 0
var return_view := ""
var return_page := 0

func _ready() -> void:
	super._ready()
	report_path = "user://holdfast_c1_result.save"
	completion_path = "user://holdfast_c1_completed.save"
	save_feedback = "C1: Tab opens the scene log / intelligence. K save / L load."

func rescue_layout() -> String: return "gdd3.1-c1-story"
func rescue_slot() -> String: return STORY_SLOT

func encounter_snapshot() -> Dictionary:
	var snapshot := super.encounter_snapshot()
	snapshot["story"] = {"opening_done":opening_done,"opening_step":opening_step,
		"preference":preference,"debrief_response":debrief_response,
		"closure_warning":closure_warning,"powered_gate_groups":powered_gate_groups.duplicate(),
		"knowledge":knowledge.duplicate(true)}
	return snapshot

func restore_extra_snapshot(snapshot: Dictionary) -> void:
	super.restore_extra_snapshot(snapshot)
	var story: Dictionary = snapshot["story"]
	opening_done = story["opening_done"]
	opening_step = story["opening_step"]
	preference = story["preference"]
	debrief_response = story["debrief_response"]
	closure_warning = story["closure_warning"]
	powered_gate_groups = story["powered_gate_groups"].duplicate()
	knowledge = story["knowledge"].duplicate(true)
	scene_view = "" if opening_done else "opening"
	scene_page = opening_step
	return_view = ""

func save_encounter(path: String = STORY_SLOT) -> bool:
	if path == RESULT_SLOT: path = STORY_SLOT
	var success := super.save_encounter(path)
	if success: save_feedback = "C1 saved: mission, dialogue preference, evidence and knowledge."
	return success

func load_encounter(path: String = STORY_SLOT) -> bool:
	if path == RESULT_SLOT: path = STORY_SLOT
	var success := super.load_encounter(path)
	if success: save_feedback = "C1 loaded. Mission facts and dialogue choices restored."
	return success

func record_rescue(kind: String, actor: int, casualty: int) -> void:
	super.record_rescue(kind,actor,casualty)
	rescue_events[-1]["closure_warning"] = closure_warning
	# The acting soldier knows the action; an unconscious patient is not assumed to.
	knowledge[actor].append(rescue_events[-1]["id"])

func on_civilian_step(cohort: Dictionary, cell: Vector2i) -> void:
	if protocol["diverted"] and not disabled() and [Vector2i(11,7),Vector2i(11,10)].has(cell) and not powered_gate_groups.has(cohort["id"]):
		powered_gate_groups.append(cohort["id"])

func after_turn_resolution() -> void:
	super.after_turn_resolution()
	if not ended and phase >= 3: closure_warning = true

func protocol_action(action: String) -> bool:
	var success := super.protocol_action(action)
	if success and action == "observe":
		status_text = "Fact: retrieving a marked component. Assessment: evacuation equipment (unconfirmed). Tab: log."
	return success

func present(index: int) -> bool:
	return soldiers[index]["extracted"] and ["active","stable"].has(soldiers[index]["condition"])

func original_actor(index: int, original_name: String) -> bool:
	return soldiers[index]["name"] == original_name

func knows(index: int, fact: String) -> bool:
	return present(index) and knowledge[index].has(fact)

func deliver_briefing() -> void:
	for index in range(4):
		if not present(index): continue
		for fact in ["outcomes","machinery"]:
			if not knowledge[index].has(fact): knowledge[index].append(fact)
		for event in rescue_events:
			if not knowledge[index].has(event["id"]): knowledge[index].append(event["id"])
	persist_story_report()

func persist_story_report() -> void:
	if not ended or retry_required(): return
	var problem := SaveStore.save(encounter_snapshot(),report_path)
	if problem == "": problem = SaveStore.save(encounter_snapshot(),completion_path)
	result_feedback = "Debrief choices and knowledge saved." if problem == "" else problem

func opening_pages() -> Array:
	return [
		{"speaker":"EXERCISE CHECKPOINT / BEFORE 09:17", "text":"Ortiz: ‘Patients wait in the shade. That buys us time.’\n\nBell: ‘If the truck cannot turn, nobody leaves.’\n\nPark moves a folding chair outside the turning arc.\n‘Both fit. Unless the next truck is bigger.’", "tag":"Ortiz · medic    Bell · engineer    Park · reconnaissance"},
		{"speaker":"09:17 / NORTHERN RIDGE", "text":"A vertical distortion crosses the ridge. No explosion. The power trips. Radio recordings lose eleven seconds.\n\nPark closes his paper notebook. ‘That was not in the exercise.’\n\nA recovery machine emerges through the old service gate.","tag":"Observed disruption / cause unknown"},
		{"speaker":"MAJOR ELENA WARD / TASK FORCE ALDER", "text":"‘Move the civilians east toward town. Keep the Farm Road junction usable. Report what you can verify.’\n\nA broken municipal transmission cuts through:\n‘Clear the service lane. Do not cut the buried feeder. People below need that power.’\n\nThe sender is unverified. The return channel is damaged.","tag":"Protect the route · evacuate civilians · extract the squad"}
	]

func report_text() -> String:
	var text := "Civilians: %d evacuated; %d stranded.\n" % [evacuated_people(),12-evacuated_people()]
	for cohort in cohorts:
		text += "Group %s: %s.\n" % [cohort["id"],"four evacuated" if cohort["status"] == "extracted" else "four stranded; fate unconfirmed"]
	text += "\n"
	for index in range(4): text += "%s: %s.\n" % [soldiers[index]["name"],soldier_disposition(index)]
	return text

func evidence_pages() -> Array:
	var recoveries: Array[String] = []
	for event in rescue_events:
		var line := "%s: %s %s." % [soldiers[event["actor"]]["name"],{"stabilized":"stabilized","picked_up":"picked up","extracted_with":"carried out"}[event["kind"]],soldiers[event["casualty"]]["name"]]
		if not recoveries.has(line): recoveries.append(line)
	if recoveries.is_empty(): recoveries.append("No casualty recovery actions recorded.")
	var pages: Array = []
	for first in range(0,recoveries.size(),6):
		var evidence := machine_outcome()+"\n"+feeder_result()+"\n"+("ACK-01 received; a bounded channel only." if protocol["acknowledged"] else "No protocol acknowledgement recorded.")+"\n\n"+"\n".join(recoveries.slice(first,first+6))
		pages.append({"speaker":"VERIFIED RECORD / READ TO SURVIVORS","text":evidence,"tag":"Available survivors receive these facts before personal dialogue."})
	return pages

func debrief_pages() -> Array:
	var pages: Array = [{"speaker":"FARM ROAD / VERIFIED FIELD REPORT","text":report_text(),"tag":"This report is read to the available survivors before discussion."}]
	pages.append_array(evidence_pages())
	var machine_text := "The machine remained active when we withdrew. No intervention was completed."
	if enemies[0]["hp"] <= 0:
		machine_text = "Machine is down. Its cooling unit is gone."
	elif disabled():
		machine_text = "Drive isolated. The gates lost power with it."
	elif protocol["diverted"]:
		var used := false
		for cohort in cohorts:
			used = used or (powered_gate_groups.has(cohort["id"]) and cohort["status"] == "extracted")
		machine_text = "The feeder stayed up. That gave the last group a route." if used else "The feeder stayed up. We kept that option."
	elif machine["departed"]:
		machine_text = "The machine departed without an intervention resolving it."
	pages.append({"speaker":"BELL" if original_actor(2,"Bell") and knows(2,"machinery") else "TECHNICAL RECORD",
		"text":machine_text+"\n\n"+feeder_result()+"\n\nA bounded protocol response does not establish an alliance." if protocol["acknowledged"] else machine_text+"\n\n"+feeder_result()+"\n\nNo protocol acknowledgement was recorded.",
		"tag":"Recorded machinery outcome / wider purpose unconfirmed"})
	var deaths: Array[String] = []
	for soldier in soldiers:
		if soldier["condition"] == "dead": deaths.append(soldier["name"])
	if not deaths.is_empty():
		pages.append({"speaker":"REST AREA / CASUALTY REPORT","text":"Confirmed dead: %s.\n\nAn empty place remains at the rest area. The casualty report replaces the usual conversation." % ", ".join(deaths),"tag":"Confirmed loss / no invented recovery"})
	elif original_actor(1,"Ortiz") and original_actor(3,"Park") and present(1) and present(3):
		for event in rescue_events:
			if event["kind"] == "stabilized" and event["actor"] == 1 and event["casualty"] == 3 and knows(1,event["id"]) and knows(3,event["id"]):
				pages.append({"speaker":"PARK / ORTIZ", "text":("Park: ‘You came back when the lane was closing.’" if event["closure_warning"] else "Park: ‘You came back for me.’")+"\n\nOrtiz: ‘You were still on this side of it.’\n\nTreatment continues. Extraction has not erased the injury.","tag":"Verified stabilization / both present and briefed"})
				break
	var response_text := "The report stays open for correction. What does the MSG say?"
	if not present(0) or soldiers[0]["condition"] != "active":
		response_text = "The MSG remains under medical care. Discussion waits for treatment; the verified report stands."
	elif debrief_response != "unset":
		response_text = response_line(debrief_response)
	pages.append({"speaker":"MSG / THE RECORD", "text":response_text,"tag":"Acknowledgement changes no casualty or civilian totals."})
	return pages

func response_line(value: String) -> String:
	match value:
		"cost": return "‘Keep the people we brought out and the people we lost in the same report.’"
		"correction": return "‘Correct anything we cannot support. Keep the observation separate from the assessment.’"
		"treatment": return "‘Treatment first. We can talk when everyone who can be helped is being helped.’"
	return ""

func choose_opening(value: String) -> void:
	if opening_done or opening_step != 0 or not ["procedure","patients","logistics"].has(value): return
	preference = value
	opening_step = 1
	scene_page = 1
	queue_redraw()

func finish_opening() -> void:
	if preference == "unset": preference = "skipped"
	opening_done = true
	opening_step = 2
	scene_view = ""
	save_feedback = "C1: Tab scene log / intelligence. K save / L load."
	queue_redraw()

func begin_debrief() -> bool:
	if not result_ready or retry_required(): return false
	scene_view = "debrief"
	scene_page = 0
	queue_redraw()
	return true

func choose_response(value: String) -> void:
	if scene_view != "debrief" or scene_page != debrief_pages().size()-1 or debrief_response != "unset" or not present(0) or soldiers[0]["condition"] != "active" or not ["cost","correction","treatment"].has(value): return
	debrief_response = value
	persist_story_report()
	queue_redraw()

func log_pages() -> Array:
	var pages := opening_pages()
	pages.append({"speaker":"MSG / SAVED DIALOGUE PREFERENCE","text":"Opening choice: %s\n\nThis preference changes no combat stats." % {"unset":"Not chosen yet.","skipped":"Opening skipped; no preference selected.","procedure":"Mark both spaces, then check the route.","patients":"Ortiz, walk me through the slowest patient.","logistics":"Bell, show me the failure point."}[preference],"tag":"Dialogue record"})
	pages.append({"speaker":"INTELLIGENCE / OBSERVATION & ASSESSMENT", "text":("FACT: retrieving a marked component.\n\nASSESSMENT: evacuation equipment — unconfirmed." if protocol["observed"] else "No close observation has been completed.\n\nThe machine’s purpose is unconfirmed.")+ ("\n\nACK-01 received. This verifies a bounded channel only." if protocol["acknowledged"] else "\n\nNo protocol acknowledgement recorded."),"tag":"Facts and interpretation kept separate"})
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func current_pages() -> Array:
	if scene_view == "opening": return opening_pages()
	if scene_view == "debrief": return debrief_pages()
	return log_pages()

func toggle_log() -> void:
	if scene_view == "log":
		scene_view = return_view
		scene_page = return_page
	else:
		return_view = scene_view
		return_page = scene_page
		scene_view = "log"
		scene_page = 0
	queue_redraw()

func advance_scene() -> void:
	if scene_view == "opening" and scene_page == 0: return
	if scene_view == "debrief" and scene_page == evidence_pages().size(): deliver_briefing()
	if scene_page+1 < current_pages().size():
		scene_page += 1
		if scene_view == "opening": opening_step = scene_page
	elif scene_view == "opening": finish_opening()
	elif scene_view == "log": toggle_log()
	else: scene_view = ""
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			toggle_log()
			return
		if event.keycode == KEY_L:
			load_encounter()
			return
		if event.keycode == KEY_K:
			save_encounter()
			return
		if scene_view == "" and event.keycode == KEY_B and result_ready:
			begin_debrief()
			return
	if scene_view == "":
		if result_ready and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
			if DEBRIEF_RECT.has_point(point):
				begin_debrief()
				return
		super._unhandled_input(event)
		return
	var rows := []
	for index in range(3): rows.append(Rect2(60,770+index*70,980,58))
	var point := Vector2.ZERO
	if event is InputEventMouse: point = get_global_transform_with_canvas().affine_inverse()*event.position
	var action := ModalInput.command(event,point,
		{KEY_ESCAPE:"back",KEY_ENTER:"next",KEY_SPACE:"next",KEY_1:"row:0",KEY_2:"row:1",KEY_3:"row:2"},
		{"next":NEXT_RECT,"back":SKIP_RECT,"log":LOG_RECT},rows)
	match action:
		"back":
			if scene_view == "opening": finish_opening()
			elif scene_view == "log": toggle_log()
			else: scene_view = ""
		"next": advance_scene()
		"log": toggle_log()
		_:
			if action.begins_with("row:"): choose_scene_option(int(action.get_slice(":",1)))
	queue_redraw()

func choose_scene_option(index: int) -> void:
	if scene_view == "opening": choose_opening(["procedure","patients","logistics"][index])
	elif scene_view == "debrief": choose_response(["cost","correction","treatment"][index])

func scene_options() -> Array:
	if scene_view == "opening" and scene_page == 0:
		return ["Mark both spaces, then check the route.","Ortiz, walk me through the slowest patient.","Bell, show me the failure point."]
	if scene_view == "debrief" and scene_page == debrief_pages().size()-1 and debrief_response == "unset" and present(0) and soldiers[0]["condition"] == "active":
		return ["Acknowledge the cost.","Ask for factual corrections.","Defer discussion until treatment."]
	return []

func _draw() -> void:
	if scene_view == "":
		super._draw()
		if not result_ready:
			draw_rect(Rect2(35,10,790,34),Color("0e1412"))
			draw_string(font,Vector2(40,36),"HOLDFAST / C1 · TAB: SCENE LOG",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
		elif not retry_required():
			draw_rect(DEBRIEF_RECT,Color("344f46"))
			draw_string(font,DEBRIEF_RECT.position+Vector2(0,27),"Debrief [B]",HORIZONTAL_ALIGNMENT_CENTER,320,18,Color.WHITE)
		return
	StoryPanel.render(self,font,board_projection,story_panel_snapshot())

func story_panel_snapshot() -> Dictionary:
	return {
		"scene_view":scene_view,
		"scene_page":scene_page,
		"NEXT_RECT":NEXT_RECT,
		"SKIP_RECT":SKIP_RECT,
		"LOG_RECT":LOG_RECT,
		"save_feedback":save_feedback,
		"pages":current_pages().duplicate(true),
		"options":scene_options().duplicate()}
