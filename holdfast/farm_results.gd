extends "res://farm_rescue.gd"
## B6 derives results from the resolved encounter, never from predicted outcomes.
const RESULT_SLOT := "user://holdfast_b6.save"
const REPORT_SLOT := "user://holdfast_b6_result.save"
const COMPLETION_SLOT := "user://holdfast_b6_completed.save"
const RETRY_RECT := Rect2(60,1080,320,54)
const RESUME_RECT := Rect2(402,1080,320,54)
const RECORD_RECT := Rect2(744,1080,320,54)
var rescue_events: Array = []
var result_ready := false
var pending_finish_reason := ""
var result_feedback := ""
var report_path := REPORT_SLOT
var completion_path := COMPLETION_SLOT

func _ready() -> void:
	super._ready()
	save_feedback = "B6: K save / L load. H opens the last resolved mission report."

func rescue_layout() -> String:
	return "gdd3.1-b6-results"

func rescue_slot() -> String:
	return RESULT_SLOT

func encounter_snapshot() -> Dictionary:
	var snapshot := super.encounter_snapshot()
	snapshot["rescue_events"] = rescue_events.duplicate(true)
	return snapshot

func restore_extra_snapshot(snapshot: Dictionary) -> void:
	rescue_events = snapshot["rescue_events"].duplicate(true)
	pending_finish_reason = ""
	result_ready = snapshot["evac"]["ended"]
	result_feedback = "Recorded mission restored. Dispositions unchanged."

func save_encounter(path: String = RESULT_SLOT) -> bool:
	var success := super.save_encounter(path)
	if success:
		save_feedback = "B6 saved: encounter, casualty dispositions and verified rescue events."
	return success

func load_encounter(path: String = RESULT_SLOT) -> bool:
	var success := super.load_encounter(path)
	if success:
		save_feedback = "B6 loaded. Recorded outcomes and rescue events restored."
	else:
		result_feedback = save_feedback
	return success

func record_rescue(kind: String, actor: int, casualty: int) -> void:
	rescue_events.append({"id":"rescue-%d" % (rescue_events.size()+1),
		"kind":kind,"actor":actor,"casualty":casualty,"phase":phase})

func try_stabilize() -> bool:
	var actor := active_soldier
	var casualty := target_for_rescue()
	var success := super.try_stabilize()
	if success:
		record_rescue("stabilized",actor,casualty)
	return success

func try_pickup() -> bool:
	var actor := active_soldier
	var casualty := rescue_target
	var success := super.try_pickup()
	if success:
		record_rescue("picked_up",actor,casualty)
	return success

func try_extract() -> bool:
	var actor := active_soldier
	var casualty: int = soldiers[actor]["carrying"] if actor >= 0 else -1
	var success := super.try_extract()
	if success and casualty >= 0:
		record_rescue("extracted_with",actor,casualty)
	return success

func damage_cell(cell: Vector2i, amount: int) -> String:
	var report := super.damage_cell(cell,amount)
	# All cells of an explosion and the enclosing action resolve before this runs.
	call_deferred("check_recovery_failure")
	return report

func check_recovery_failure() -> void:
	if ended or soldiers[0]["extracted"] or soldiers[0]["condition"] == "active":
		return
	for index in range(soldiers.size()):
		if soldier_can_act(index):
			return
	finish_operation("MSG incapacitated; no conscious rescuer remains")

func resolve_enemy_turn() -> void:
	super.resolve_enemy_turn()
	check_recovery_failure()
	finalize_result()

func try_fire() -> bool:
	var success := super.try_fire()
	check_recovery_failure()
	finalize_result()
	return success

func after_turn_resolution() -> void:
	super.after_turn_resolution()
	check_recovery_failure()
	finalize_result()

func finish_operation(reason: String) -> void:
	if ended or pending_finish_reason != "":
		return
	pending_finish_reason = reason
	call_deferred("finalize_result")

func finalize_result() -> void:
	if pending_finish_reason == "" or result_ready:
		return
	super.finish_operation(pending_finish_reason)
	pending_finish_reason = ""
	# All scheduled damage has resolved before dispositions are finalized.
	for soldier in soldiers:
		soldier["left_behind"] = not soldier["extracted"] and soldier["condition"] != "dead"
	result_ready = true
	var problem := SaveStore.save(encounter_snapshot(),report_path)
	if problem == "" and not retry_required():
		problem = SaveStore.save(encounter_snapshot(),completion_path)
	result_feedback = "Mission record saved automatically." if problem == "" else problem
	queue_redraw()

func retry_required() -> bool:
	return not soldiers[0]["extracted"] or soldiers[0]["condition"] == "dead"

func soldier_disposition(index: int) -> String:
	var soldier: Dictionary = soldiers[index]
	if soldier["condition"] == "dead":
		return "CONFIRMED DEAD"
	if not soldier["extracted"]:
		return "LEFT BEHIND / unavailable"
	if soldier["condition"] == "critical":
		return "EXTRACTED / critical casualty"
	if soldier["condition"] == "stable":
		return "EXTRACTED / stabilized casualty"
	return "EXTRACTED / %d HP" % soldier["hp"]

func feeder_result() -> String:
	if machine["collected_round"] > 0:
		return "Feeder severed when the skid was collected."
	if disabled():
		return "Feeder isolated / power outage; skid retained."
	return "Feeder intact; skid not collected."

func evacuated_people() -> int:
	var count := 0
	for cohort in cohorts:
		if cohort["status"] == "extracted": count += cohort["manifest"].size()
	return count

func result_title() -> String:
	if retry_required():
		return "ATTEMPT ENDED / RETRY REQUIRED"
	var everyone := evacuated_people() == 12
	for soldier in soldiers:
		everyone = everyone and soldier["extracted"] and soldier["condition"] != "dead"
	return "FARM ROAD / EVACUATION COMPLETE" if everyone else "FARM ROAD / PARTIAL COMPLETION"

func restart_attempt() -> void:
	get_tree().reload_current_scene()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		load_encounter(report_path)
		return
	if not ended:
		super._unhandled_input(event)
		return
	if not result_ready:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q: restart_attempt()
			KEY_L: load_encounter()
			KEY_K:
				save_encounter()
				result_feedback = save_feedback
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
		if RETRY_RECT.has_point(point): restart_attempt()
		elif RESUME_RECT.has_point(point): load_encounter()
		elif RECORD_RECT.has_point(point):
			save_encounter()
			result_feedback = save_feedback
	queue_redraw()

func result_line(y: float, text: String, color: Color = Color("d6ded9"), size: int = 19) -> void:
	draw_string(font,Vector2(60,y),text,HORIZONTAL_ALIGNMENT_LEFT,1024,size,color)

func _draw() -> void:
	if not result_ready:
		super._draw()
		draw_rect(Rect2(35,10,790,34),Color("0e1412"))
		draw_string(font,Vector2(40,36),"HOLDFAST / B6 MISSION RESULTS",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
		return
	draw_rect(Rect2(0,0,1144,1224),Color("0e1412"))
	result_line(55,"HOLDFAST  /  FARM ROAD RECORD",Color("8be6de"),17)
	result_line(108,result_title(),Color("f7cd6c"),29)
	result_line(146,"Round %d · %s" % [phase,end_reason],Color("aebbb6"),18)
	result_line(184,"MSG terminal loss prevents continuation. Retry or load a tactical save." if retry_required() else "MSG recovered. The casualties and losses below remain recorded.",Color.WHITE,18)
	result_line(243,"SQUAD DISPOSITIONS",Color("8be6de"),18)
	for index in range(soldiers.size()):
		result_line(282+index*37,"%-8s  %s" % [soldiers[index]["name"],soldier_disposition(index)])
	result_line(443,"CIVILIANS  /  %d evacuated · %d stranded" % [evacuated_people(),12-evacuated_people()],Color("8be6de"),20)
	for index in range(cohorts.size()):
		var cohort: Dictionary = cohorts[index]
		result_line(480+index*33,"Group %s · 4 people · %s" % [cohort["id"],"EVACUATED" if cohort["status"] == "extracted" else "STRANDED — fate unconfirmed"],Color("d6ded9"),18)
	result_line(605,"MACHINERY & VERIFIED OBSERVATIONS",Color("8be6de"),18)
	result_line(641,machine_outcome(),Color.WHITE,18)
	result_line(675,feeder_result(),Color("d6ded9"),18)
	result_line(709,"Protocol observed: %s · ACK-01 received: %s · Console authenticated: %s" % ["yes" if protocol["observed"] else "no","yes" if protocol["acknowledged"] else "no","yes" if protocol["authenticated"] else "no"],Color("d6ded9"),17)
	result_line(743,"These are local observations; the machine's wider purpose is unconfirmed.",Color("aebbb6"),17)
	result_line(799,"VERIFIED CASUALTY RECOVERY",Color("8be6de"),18)
	var summaries: Array[String] = []
	for index in range(4):
		var treatments := 0
		var pickups := 0
		var extractions := 0
		for event in rescue_events:
			if event["actor"] == index:
				treatments += 1 if event["kind"] == "stabilized" else 0
				pickups += 1 if event["kind"] == "picked_up" else 0
				extractions += 1 if event["kind"] == "extracted_with" else 0
		if treatments+pickups+extractions > 0:
			summaries.append("%s · treated %d · picked up %d · carried out %d" % [soldiers[index]["name"],treatments,pickups,extractions])
	if summaries.is_empty(): summaries.append("No casualty recovery actions recorded.")
	for index in range(summaries.size()): result_line(835+index*32,summaries[index],Color("d6ded9"),18)
	result_line(1002,result_feedback,Color("f7cd6c"),17)
	result_line(1036,"Non-MSG deaths stay recorded. Left behind and stranded do not mean confirmed dead.",Color("aebbb6"),16)
	for item in [[RETRY_RECT,"Retry mission [Q]" if retry_required() else "Replay mission [Q]"],[RESUME_RECT,"Load tactical save [L]"],[RECORD_RECT,"Save this state [K]"]]:
		draw_rect(item[0],Color("304965"))
		draw_string(font,item[0].position+Vector2(0,35),item[1],HORIZONTAL_ALIGNMENT_CENTER,320,19,Color.WHITE)
	result_line(1180,"A replay starts a new attempt. H reopens the last resolved mission record.",Color("aebbb6"),17)
