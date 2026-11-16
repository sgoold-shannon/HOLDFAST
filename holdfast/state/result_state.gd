extends RefCounted
## Verified rescue records and result-finalization state.
var rescue_events: Array = []
var result_ready := false
var pending_finish_reason := ""
func snapshot() -> Array:
	return rescue_events.duplicate(true)
func restore(events: Array, ended: bool) -> void:
	rescue_events = events.duplicate(true)
	pending_finish_reason = ""
	result_ready = ended
