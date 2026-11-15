extends RefCounted
static func initial() -> Dictionary:
	return {"active":false,"source":"none","repair":0,"bonus_event":"","bonus_group":""}
static func outcome(campaign: Dictionary) -> String:
	if campaign["missions"].is_empty(): return "none"
	var description: String = campaign["missions"][0]["machine"]
	if description.begins_with("Diverted"): return "diverted"
	if description.begins_with("Disabled"): return "disabled"
	if description.begins_with("Destroyed"): return "destroyed"
	return "unresolved"
static func validate(state: Variant, campaign: Dictionary) -> String:
	if not state is Dictionary or not state.get("active") is bool or not ["none","diverted","disabled","destroyed","unresolved"].has(state.get("source")): return "invalid return-map state."
	if not state.get("repair") is int or state["repair"] < 0 or state["repair"] > 2: return "invalid repair progress."
	if not ["","return-cooling-move-1"].has(state.get("bonus_event")) or not ["","A","B","C"].has(state.get("bonus_group")): return "invalid cooling event."
	if (state["bonus_event"] == "") != (state["bonus_group"] == ""): return "cooling event lacks recipient."
	if not state["active"]:
		if state != initial(): return "inactive return contains effects."
		return ""
	if campaign["deployment"] < 2 or state["source"] != outcome(campaign): return "return outcome differs from original mission."
	if state["repair"] > 0 and state["source"] != "disabled": return "unrepairable machine has repair progress."
	if state["bonus_event"] != "" and not (state["source"] == "diverted" or (state["source"] == "disabled" and state["repair"] == 2)): return "cooling used without working equipment."
	return ""
