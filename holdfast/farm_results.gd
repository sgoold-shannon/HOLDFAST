extends "res://farm_rescue.gd"
const Completion = preload("res://systems/encounter_completion.gd")
const ResultState = preload("res://state/result_state.gd")
var result_state := ResultState.new()
const CampaignPersistence = preload("res://systems/campaign_persistence.gd")
const ResultInput = preload("res://presentation/modal_input.gd")
const ResultsPanel = preload("res://presentation/results_panel.gd")
## B6 derives results from the resolved encounter, never from predicted outcomes.
const RESULT_SLOT := "user://holdfast_b6.save"
const REPORT_SLOT := "user://holdfast_b6_result.save"
const COMPLETION_SLOT := "user://holdfast_b6_completed.save"
const RETRY_RECT := Rect2(60,1080,320,54)
const RESUME_RECT := Rect2(402,1080,320,54)
const RECORD_RECT := Rect2(744,1080,320,54)
var rescue_events: Array:
	get: return result_state.rescue_events
	set(value): result_state.rescue_events = value
var result_ready: bool:
	get: return result_state.result_ready
	set(value): result_state.result_ready = value
var pending_finish_reason: String:
	get: return result_state.pending_finish_reason
	set(value): result_state.pending_finish_reason = value
var result_feedback := ""
var report_path := REPORT_SLOT
var completion_path := COMPLETION_SLOT

func _ready() -> void:
	super._ready()
	initialize_results()

func initialize_results() -> void:
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
	restore_results_state(snapshot)

func restore_results_state(snapshot: Dictionary) -> void:
	result_state.restore(snapshot["rescue_events"],snapshot["evac"]["ended"])
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
	append_rescue_record(kind,actor,casualty)

func append_rescue_record(kind: String, actor: int, casualty: int) -> void:
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
	Completion.finalize(result_state,soldiers,close_result_operation,save_mission_result)

func close_result_operation(reason: String) -> void:
	super.finish_operation(reason)

func save_mission_result() -> void:
	var problem := CampaignPersistence.report(encounter_snapshot,report_path,completion_path,not retry_required())
	result_feedback = "Mission record saved automatically." if problem == "" else problem
	queue_redraw()

func retry_required() -> bool:
	return not soldiers[0]["extracted"] or soldiers[0]["condition"] == "dead"

func soldier_disposition(index: int) -> String:
	return recorded_soldier_disposition(index)

func recorded_soldier_disposition(index: int) -> String:
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
	if not handle_results_input(event): super._unhandled_input(event)

func handle_results_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		load_encounter(report_path)
		return true
	if not ended:
		return false
	if not result_ready:
		return true
	var point := Vector2.ZERO
	if event is InputEventMouse: point = get_global_transform_with_canvas().affine_inverse()*event.position
	var action := ResultInput.command(event,point,{KEY_Q:"retry",KEY_L:"load",KEY_K:"save"},
		{"retry":RETRY_RECT,"load":RESUME_RECT,"save":RECORD_RECT})
	match action:
		"retry": restart_attempt()
		"load": load_encounter()
		"save":
			save_encounter()
			result_feedback = save_feedback
	queue_redraw()
	return true

func result_line(y: float, text: String, color: Color = Color("d6ded9"), size: int = 19) -> void:
	draw_string(font,Vector2(60,y),text,HORIZONTAL_ALIGNMENT_LEFT,1024,size,color)

func _draw() -> void:
	if not result_ready:
		super._draw()
		SceneChrome.header(self,font,"HOLDFAST / B6 MISSION RESULTS",790,Color.WHITE)
		return
	ResultsPanel.render(self,font,board_projection,results_panel_snapshot())

func results_panel_snapshot() -> Dictionary:
	var dispositions := []
	for index in range(soldiers.size()): dispositions.append(soldier_disposition(index))
	return {
		"phase":phase,
		"end_reason":end_reason,
		"result_feedback":result_feedback,
		"RETRY_RECT":RETRY_RECT,
		"RESUME_RECT":RESUME_RECT,
		"RECORD_RECT":RECORD_RECT,
		"soldiers":soldiers.duplicate(true),
		"cohorts":cohorts.duplicate(true),
		"protocol":protocol.duplicate(true),
		"rescue_events":rescue_events.duplicate(true),
		"title":result_title(),
		"retry":retry_required(),
		"dispositions":dispositions,
		"evacuated":evacuated_people(),
		"outcome":machine_outcome(),
		"feeder":feeder_result()}
