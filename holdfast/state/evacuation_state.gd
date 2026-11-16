extends RefCounted
## Civilian cohorts, per-phase order allowance and encounter closure state.
var cohorts: Array[Dictionary] = [
	{"id": "A", "cell": Vector2i.ZERO, "hp": 4, "order": "hold", "passed": false, "status": "active", "note": "Holding", "manifest": ["A-01","A-02","A-03","A-04"]},
	{"id": "B", "cell": Vector2i.ZERO, "hp": 4, "order": "hold", "passed": false, "status": "active", "note": "Holding", "manifest": ["B-01","B-02","B-03","B-04"]},
	{"id": "C", "cell": Vector2i.ZERO, "hp": 4, "order": "hold", "passed": false, "status": "active", "note": "Holding", "manifest": ["C-01","C-02","C-03","C-04"]}
]
var order_used := false
var ended := false
var end_reason := ""
var last_civilian_phase := 0
func snapshot() -> Dictionary:
	return {"cohorts":cohorts.duplicate(true),"order_used":order_used,"ended":ended,"reason":end_reason,"last_phase":last_civilian_phase}
func restore(data: Dictionary) -> void:
	cohorts.assign(data["cohorts"].duplicate(true))
	order_used = data["order_used"]
	ended = data["ended"]
	end_reason = data["reason"]
	last_civilian_phase = data["last_phase"]
