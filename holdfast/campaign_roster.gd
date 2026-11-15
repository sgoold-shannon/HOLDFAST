extends RefCounted
## Stable actor identities outlive tactical slots. This fixture stops after two deployments.
static func initial() -> Dictionary:
	var members: Array = []
	var names := ["MSG","Ortiz","Bell","Park"]
	var ids := ["msg","ortiz","bell","park"]
	var traits := [["Evidence-minded","Accountable"],["Patient-focused","Direct"],["Methodical","Practical"],["Observant","Cautious"]]
	var hooks := ["Keeps a truthful record of his own decisions.","Wants an injured teammate's family notified.","Promised a junior teammate a lesson in unsafe improvisations.","Owes a family member a call after the exercise."]
	for index in range(4):
		members.append({"id":ids[index],"name":names[index],"role":index,"traits":traits[index],"hook":hooks[index],
			"replacement":false,"status":"ready","hp":8,"condition":"active","history":[],"knowledge":[],"relationships":{}})
	members[1]["relationships"]["msg"] = ["Trusts him to listen when casualty estimates change."]
	members[2]["relationships"]["ortiz"] = ["Trusts her competence; disputes committing transport before routes are secure."]
	return {"deployment":1,"committed":false,"members":members,"assignments":ids,"missions":[]}

static func actor(campaign: Dictionary, id: String) -> Dictionary:
	for member in campaign["members"]:
		if member["id"] == id: return member
	return {}

static func replacement(role: int) -> Dictionary:
	# A small, deterministic template draw; no broad character generator.
	var rng := RandomNumberGenerator.new()
	rng.seed = 310200+role
	var names := [["Reyes","Sato"],["Chen","Ellis"],["Vale","Morgan"]]
	var traits := ["Deliberate","Plain-spoken","Resourceful","Patient","Watchful","Steady"]
	var first := rng.randi_range(0,2)
	var second := rng.randi_range(3,5)
	var hooks := ["Keeps a list of families waiting for medical updates.","Carries a damaged pocket tool from a former workshop.","Sketches road junctions to send home when communications return."]
	return {"id":"reserve-%d" % role,"name":names[role-1][rng.randi_range(0,1)],"role":role,
		"traits":[traits[first],traits[second]],"hook":hooks[role-1],"replacement":true,
		"status":"ready","hp":8,"condition":"active","history":[],"knowledge":[],"relationships":{}}

static func next_assignments(campaign: Dictionary) -> Array:
	var result: Array = ["","","",""]
	for member in campaign["members"]:
		if ["ready","wounded"].has(member["status"]): result[member["role"]] = member["id"]
	return result

static func validate(campaign: Variant, maximum_deployments: int = 2) -> String:
	if not campaign is Dictionary: return "missing campaign roster."
	if not campaign.get("deployment") is int or campaign["deployment"] < 1 or campaign["deployment"] > maximum_deployments or not campaign.get("committed") is bool:
		return "invalid deployment state."
	if not campaign.get("members") is Array or campaign["members"].size() < 4 or campaign["members"].size() > 7:
		return "invalid persistent roster."
	var ids: Array = []
	for member in campaign["members"]:
		if not member is Dictionary: return "invalid actor."
		if not member.get("id") is String or ids.has(member["id"]) or not ["msg","ortiz","bell","park","reserve-1","reserve-2","reserve-3"].has(member["id"]): return "invalid actor identity."
		ids.append(member["id"])
		if not member.get("name") is String or member["name"].length() < 1 or member["name"].length() > 20 or not member.get("role") is int or member["role"] < 0 or member["role"] > 3: return "invalid actor role."
		if not member.get("replacement") is bool or not member.get("hp") is int or member["hp"] < -4 or member["hp"] > 8: return "invalid actor health."
		if not ["ready","wounded","recovering","dead","left_behind"].has(member.get("status")) or not ["active","stable","critical","dead"].has(member.get("condition")): return "invalid actor disposition."
		if not member.get("traits") is Array or member["traits"].size() != 2 or not member.get("hook") is String: return "invalid identity details."
		for trait_name in member["traits"]:
			if not trait_name is String: return "invalid trait."
		for key in ["history","knowledge"]:
			if not member.get(key) is Array or member[key].size() > 10000: return "invalid actor history."
			for entry in member[key]:
				if not entry is String: return "invalid history entry."
		if not member.get("relationships") is Dictionary: return "invalid relationships."
		for other in member["relationships"]:
			if not other is String or not member["relationships"][other] is Array: return "invalid relationship target."
			for note in member["relationships"][other]:
				if not note is String: return "invalid relationship note."
		if member["replacement"]:
			if member["role"] == 0 or member["id"] != "reserve-%d" % member["role"]: return "invalid replacement identity."
			if member["name"] != replacement(member["role"])["name"]: return "replacement identity changed."
		else:
			if member["id"] != ["msg","ortiz","bell","park"][member["role"]] or member["name"] != ["MSG","Ortiz","Bell","Park"][member["role"]]: return "original identity changed."
		if ["ready","wounded"].has(member["status"]) and (member["condition"] != "active" or member["hp"] <= 0): return "unfit actor marked available."
		if member["status"] == "dead" and member["condition"] != "dead": return "death mismatch."
		if member["status"] == "dead" and member["hp"] > 0: return "dead actor has positive health."
		if member["status"] == "recovering" and not ["critical","stable"].has(member["condition"]): return "invalid recovery status."
		if member["replacement"] and campaign["deployment"] == 1 and (not member["history"].is_empty() or not member["knowledge"].is_empty() or not member["relationships"].is_empty()): return "replacement inherited earlier history."
	for original in ["msg","ortiz","bell","park"]:
		if not ids.has(original): return "missing original service record."
	for member in campaign["members"]:
		for other in member["relationships"]:
			if not ids.has(other) or other == member["id"]: return "unknown relationship."
	if not campaign.get("assignments") is Array or campaign["assignments"].size() != 4 or campaign["assignments"][0] != "msg": return "invalid deployment assignments."
	for role in range(4):
		var id: Variant = campaign["assignments"][role]
		if id == "": continue
		if not id is String or not ids.has(id) or actor(campaign,id)["role"] != role: return "actor assigned to wrong role."
	if not campaign.get("missions") is Array or campaign["missions"].size() != campaign["deployment"]-(0 if campaign["committed"] else 1): return "invalid mission ledger."
	for index in range(campaign["missions"].size()):
		var mission: Variant = campaign["missions"][index]
		if not mission is Dictionary or mission.get("id") != "deployment-%d" % (index+1) or not mission.get("machine") is String or not mission.get("feeder") is String or not mission.get("cohorts") is Array or mission["cohorts"].size() != 3 or not mission.get("soldiers") is Array: return "invalid mission record."
	for member in campaign["members"]:
		if member["replacement"] and actor(campaign,["msg","ortiz","bell","park"][member["role"]])["status"] != "dead": return "replacement requires a confirmed death."
	for index in range(campaign["missions"].size()):
		var mission: Dictionary = campaign["missions"][index]
		for group_index in range(3):
			var group: Variant = mission["cohorts"][group_index]
			var prefix := "D%d-%s" % [index+1,["A","B","C"][group_index]]
			if not group is Dictionary or not ["extracted","stranded"].has(group.get("status")) or group.get("manifest") != [prefix+"-01",prefix+"-02",prefix+"-03",prefix+"-04"]: return "invalid archived civilian outcome."
		var participants: Array = []
		for entry in mission["soldiers"]:
			if not entry is Dictionary or not ids.has(entry.get("id")) or participants.has(entry["id"]) or not entry.get("disposition") is String: return "invalid archived soldier outcome."
			participants.append(entry["id"])
			if entry["disposition"] == "CONFIRMED DEAD" and actor(campaign,entry["id"])["status"] != "dead": return "dead actor cannot return."
	return ""
