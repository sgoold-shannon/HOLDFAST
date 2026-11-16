extends RefCounted
## Disk/validation boundary. Apply is called only after file and encounter checks succeed.
const Store = preload("res://encounter_save.gd")
static func write(snapshot: Dictionary, path: String) -> String:
	return Store.save(snapshot,path)

static func read(path: String) -> Dictionary:
	return Store.load_snapshot(path)

static func restore(path: String, expected_layout: String, mismatch_message: String, apply: Callable) -> String:
	var result := read(path)
	if result["error"] != "": return result["error"]
	var snapshot: Dictionary = result["snapshot"]
	if snapshot["layout"] != expected_layout: return mismatch_message
	apply.call(snapshot)
	return ""
