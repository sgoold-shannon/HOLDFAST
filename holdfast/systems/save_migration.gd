extends RefCounted
## Existing C2-to-D1 upgrade policy. Source data is copied and validated before persistence.
const Persistence = preload("res://systems/encounter_persistence.gd")
const ReturnRules = preload("res://return_rules.gd")
static func return_slot(source_path: String, campaign_path: String, target_layout: String, reader: Callable = Persistence.read, writer: Callable = Persistence.write) -> Dictionary:
	var result: Dictionary = reader.call(source_path)
	# The normal loader still owns errors and all other layouts.
	if result["error"] != "" or result["snapshot"]["layout"] != "gdd3.1-c2-roster":
		return {"path":source_path,"error":""}
	var upgraded: Dictionary = result["snapshot"].duplicate(true)
	upgraded["layout"] = target_layout
	upgraded["return_map"] = ReturnRules.initial()
	var problem: String = writer.call(upgraded,campaign_path)
	return {"path":campaign_path if problem == "" else source_path,"error":problem}
