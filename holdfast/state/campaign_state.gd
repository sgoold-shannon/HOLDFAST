extends RefCounted
## Persistent roster/campaign records and the linked return encounter.
const ReturnRules = preload("res://return_rules.gd")
var campaign: Dictionary = {}
var return_state := ReturnRules.initial()
func snapshot() -> Dictionary:
	return {"campaign":campaign.duplicate(true),"return_map":return_state.duplicate(true)}
func restore_campaign(data: Dictionary) -> void:
	campaign = data.duplicate(true)
func restore_return(data: Dictionary) -> void:
	return_state = data.duplicate(true)
