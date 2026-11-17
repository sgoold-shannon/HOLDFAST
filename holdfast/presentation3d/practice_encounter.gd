extends "res://encounter_controller.gd"
## Practice keeps all production resolution rules, but never persists results.
func save_encounter(_path: String = RETURN_SLOT) -> bool:
	return false
func load_encounter(_path: String = RETURN_SLOT) -> bool:
	return false
func save_mission_result() -> void:
	pass
func save_story_report() -> void:
	pass
func persist_campaign_result() -> void:
	pass
