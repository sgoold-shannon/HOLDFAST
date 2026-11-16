extends RefCounted
## Finalize only after the enclosing action has resolved all scheduled damage.
## Mark ready before saving; repeated/deferred completion cannot duplicate history.
static func finalize(state: RefCounted, soldiers: Array, close_operation: Callable,
		save_report: Callable, commit_campaign: Callable = Callable(),
		save_campaign: Callable = Callable()) -> bool:
	if state.pending_finish_reason == "" or state.result_ready:
		return false
	close_operation.call(state.pending_finish_reason)
	state.pending_finish_reason = ""
	for soldier in soldiers:
		soldier["left_behind"] = not soldier["extracted"] and soldier["condition"] != "dead"
	state.result_ready = true
	save_report.call()
	if commit_campaign.is_valid(): commit_campaign.call()
	if save_campaign.is_valid(): save_campaign.call()
	return true
