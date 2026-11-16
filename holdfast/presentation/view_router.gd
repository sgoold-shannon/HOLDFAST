extends RefCounted
## Explicit draw order for the composed current encounter. Earlier gate scenes keep adapters.
static func screen(roster_open: bool, scene_view: String, result_ready: bool) -> String:
	if roster_open: return "roster"
	if scene_view != "": return "story"
	if result_ready: return "results"
	return "tactical"

static func layers(active_screen: String) -> Array[String]:
	match active_screen:
		"roster": return ["roster","return","ending"]
		"story": return ["story","return","ending"]
		"results": return ["results","story_navigation","roster_navigation","return","ending"]
		_: return ["tactical","machine","civilian","breaker","protocol","rescue","results_header","story_navigation","roster_navigation","return","ending"]

static func render(active_screen: String, views: Dictionary) -> void:
	for layer in layers(active_screen): views[layer].call()
