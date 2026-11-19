extends RefCounted
## Mission results: recovery failure, closing and recording the result, dispositions, titles and restarting.
## Moved out of encounter_controller.gd; the controller keeps one-line wrappers.
const Completion = preload("res://systems/encounter_completion.gd")
const ReturnRules = preload("res://return_rules.gd")

static func check_recovery_failure(board) -> void:
	if board.ended or board.soldiers[0]["extracted"] or board.soldiers[0]["condition"] == "active":
		return
	for index in range(board.soldiers.size()):
		if board.soldier_can_act(index):
			return
	board.finish_operation("MSG incapacitated; no conscious rescuer remains")

static func finalize_result(board) -> void:
	Completion.finalize(board.result_state,board.soldiers,board.close_result_operation,board.save_mission_result,
		board.commit_roster,board.persist_campaign_result)

static func close_result_operation(board, reason: String) -> void:
	board.close_evacuation(reason)
	board.close_rescue()

static func recorded_soldier_disposition(board, index: int) -> String:
	var soldier: Dictionary = board.soldiers[index]
	if soldier["condition"] == "dead":
		return "CONFIRMED DEAD"
	if not soldier["extracted"]:
		return "LEFT BEHIND / unavailable"
	if soldier["condition"] == "critical":
		return "EXTRACTED / critical casualty"
	if soldier["condition"] == "stable":
		return "EXTRACTED / stabilized casualty"
	return "EXTRACTED / %d HP" % soldier["hp"]

static func origin_feeder_result(board) -> String:
	if board.machine["collected_round"] > 0:
		return "Feeder severed when the skid was collected."
	if board.disabled():
		return "Feeder isolated / power outage; skid retained."
	return "Feeder intact; skid not collected."

static func evacuated_people(board) -> int:
	var count = 0
	for cohort in board.cohorts:
		if cohort["status"] == "extracted": count += cohort["manifest"].size()
	return count

static func result_title(board) -> String:
	if board.retry_required():
		return "ATTEMPT ENDED / RETRY REQUIRED"
	var everyone = evacuated_people(board) == 12
	for soldier in board.soldiers:
		everyone = everyone and soldier["extracted"] and soldier["condition"] != "dead"
	return "FARM ROAD / EVACUATION COMPLETE" if everyone else "FARM ROAD / PARTIAL COMPLETION"

static func restart_attempt(board) -> void:
	if board.campaign["committed"]:
		board.open_roster()
		return
	var state = ReturnRules.initial()
	if board.return_state["active"]:
		state["active"] = true
		state["source"] = board.return_state["source"]
	board.replace_return_attempt(board.campaign.duplicate(true),state)
