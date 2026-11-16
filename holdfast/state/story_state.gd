extends RefCounted
## Persistent dialogue choices and witnessed knowledge; view/page selection stays in the controller.
var opening_done := false
var opening_step := 0
var preference := "unset"
var debrief_response := "unset"
var closure_warning := false
var powered_gate_groups: Array = []
var knowledge: Array = [[],[],[],[]]

func snapshot() -> Dictionary:
	return {"opening_done":opening_done,"opening_step":opening_step,
		"preference":preference,"debrief_response":debrief_response,
		"closure_warning":closure_warning,"powered_gate_groups":powered_gate_groups.duplicate(),
		"knowledge":knowledge.duplicate(true)}

func restore(story: Dictionary) -> void:
	opening_done = story["opening_done"]
	opening_step = story["opening_step"]
	preference = story["preference"]
	debrief_response = story["debrief_response"]
	closure_warning = story["closure_warning"]
	powered_gate_groups = story["powered_gate_groups"].duplicate()
	knowledge = story["knowledge"].duplicate(true)
