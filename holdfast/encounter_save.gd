extends RefCounted
## Versioned, checked binary data preserves Vector2i and full 64-bit RNG state.
const SAVE_PATH := "user://holdfast_a6.save"
const FORMAT := "HOLDFAST_A6"
const VERSION := 1
const MAX_BYTES := 8388608

static func checksum(data: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(data)
	return context.finish().hex_encode()

static func save(snapshot: Dictionary, path: String = SAVE_PATH) -> String:
	var problem := validate(snapshot)
	if problem != "":
		return "Cannot save: " + problem
	var payload := var_to_bytes(snapshot)
	var envelope := {"format": FORMAT, "version": VERSION,
		"engine": Engine.get_version_info()["string"], "payload": payload, "checksum": checksum(payload)}
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "Save failed: cannot write the local save file."
	file.store_var(envelope, false)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return "Save failed while writing; previous save retained."
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
		return "Save failed while replacing the slot; previous save retained."
	return ""

static func load_snapshot(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "No save yet. Press K or click Save first."}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES or file.get_length() < 4:
		return {"error": "Save cannot be read. Current encounter unchanged."}
	var envelope: Variant = file.get_var(false)
	file.close()
	if not envelope is Dictionary:
		return {"error": "Damaged save. Current encounter unchanged."}
	if envelope.get("format") != FORMAT or envelope.get("version") != VERSION:
		return {"error": "Unsupported save version. Current encounter unchanged."}
	if envelope.get("engine") != Engine.get_version_info()["string"]:
		return {"error": "Save uses a different Godot version; replay cannot be guaranteed."}
	if not envelope.get("payload") is PackedByteArray or not envelope.get("checksum") is String:
		return {"error": "Damaged save contents. Current encounter unchanged."}
	if checksum(envelope["payload"]) != envelope["checksum"]:
		return {"error": "Save integrity check failed. Current encounter unchanged."}
	var snapshot: Variant = bytes_to_var(envelope["payload"])
	if not snapshot is Dictionary:
		return {"error": "Invalid encounter data. Current encounter unchanged."}
	var problem := validate(snapshot)
	if problem != "":
		return {"error": "Invalid save: " + problem}
	return {"error": "", "snapshot": snapshot}

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return value is int and value >= minimum and value <= maximum

static func cell(value: Variant, allow_none: bool = false) -> bool:
	return value is Vector2i and ((allow_none and value == Vector2i(-1, -1)) or (value.x >= 1 and value.x <= 20 and value.y >= 1 and value.y <= 16))

static func validate(data: Dictionary) -> String:
	var return_scene: bool = data.get("layout") == "gdd3.1-d1-return"
	var roster_scene: bool = data.get("layout") == "gdd3.1-c2-roster" or return_scene
	if roster_scene:
		var roster_problem: String = preload("res://campaign_roster.gd").validate(data.get("campaign"),3 if return_scene else 2)
		if roster_problem != "": return roster_problem
	if return_scene:
		var return_problem: String = preload("res://return_rules.gd").validate(data.get("return_map"),data["campaign"])
		if return_problem != "": return return_problem
	var return_active: bool = return_scene and data["return_map"]["active"]
	var story_scene: bool = data.get("layout") == "gdd3.1-c1-story" or roster_scene
	var results: bool = data.get("layout") == "gdd3.1-b6-results" or story_scene
	var rescue: bool = data.get("layout") == "gdd3.1-b5-rescue" or results
	if results:
		if not data.get("rescue_events") is Array or data["rescue_events"].size() > 10000:
			return "invalid rescue history."
		var event_ids: Array[String] = []
		for event in data["rescue_events"]:
			if not event is Dictionary:
				return "invalid rescue event."
			if not event.get("id") is String or event_ids.has(event["id"]) or not ["stabilized","picked_up","extracted_with"].has(event.get("kind")):
				return "invalid rescue event identity."
			if not integer(event.get("actor"),0,3) or not integer(event.get("casualty"),0,3) or event["actor"] == event["casualty"] or not integer(event.get("phase"),1,1000000):
				return "invalid rescue event participants."
			event_ids.append(event["id"])
	var communication: bool = data.get("layout") == "gdd3.1-b4-protocol" or rescue
	var options: bool = data.get("layout") == "gdd3.1-b3-options" or communication
	var evac: bool = data.get("layout") == "gdd3.1-b2-evac" or options
	var farm: bool = data.get("layout") == "gdd3.1-b1-farm-road" or evac
	if not farm and data.get("layout") != "gdd3.1-a5-10x7":
		return "encounter layout mismatch."
	if not data.get("combat") is Dictionary or not data.get("ui") is Dictionary:
		return "missing encounter state."
	var combat: Dictionary = data["combat"]
	var ui: Dictionary = data["ui"]
	if not integer(combat.get("phase"), 1, 1000000) or not integer(combat.get("last_enemy_phase"), 0, combat["phase"]):
		return "invalid turn counters."
	if not combat.get("rng_seed") is int or not combat.get("rng_state") is int or not combat.get("enemy_message") is String:
		return "invalid random state or enemy report."
	if not combat.get("soldiers") is Array or combat["soldiers"].size() != 4:
		return "invalid squad roster."
	if not combat.get("targets") is Array or combat["targets"].size() != 1:
		return "invalid enemy roster."
	var occupied: Array[Vector2i] = []
	var names := ["MSG", "Ortiz", "Bell", "Park"]
	var marks := ["M", "O", "B", "P"]
	const WALLS := [Vector2i(12, 5), Vector2i(12, 6), Vector2i(12, 8), Vector2i(12, 9)]
	for index in range(4):
		var soldier: Variant = combat["soldiers"][index]
		if not soldier is Dictionary:
			return "invalid soldier data."
		if roster_scene:
			var actor_id: String = data["campaign"]["assignments"][index]
			var member: Dictionary = preload("res://campaign_roster.gd").actor(data["campaign"],actor_id)
			if soldier.get("actor_id") != actor_id: return "tactical actor identity mismatch."
			names[index] = "Vacant" if actor_id == "" else member["name"]
			marks[index] = "-" if actor_id == "" else member["name"].left(1)
			if actor_id == "" and (not soldier.get("extracted",false) or soldier.get("ap") != 0): return "vacancy cannot act."
			if not data["campaign"]["committed"] and actor_id != "" and not ["ready","wounded"].has(member["status"]): return "unavailable actor deployed."
		if soldier.get("name") != names[index] or soldier.get("mark") != marks[index] or not cell(soldier.get("cell")):
			return "invalid soldier identity or position."
		for stat in ["hp", "ap", "ammo"]:
			if not integer(soldier.get(stat), -4 if rescue and stat == "hp" else 0, {"hp": 8, "ap": 2, "ammo": 4}[stat]):
				return "invalid soldier resources."
		if not soldier.get("attacked") is bool or not soldier.get("extracted") is bool:
			return "invalid soldier flags."
		if soldier["hp"] == 0 and soldier["ap"] != 0:
			return "critical soldier has action points."
		if not soldier["extracted"] and (not rescue or (soldier.get("carried_by",-1) == -1 and soldier.get("condition") != "dead")):
			if occupied.has(soldier["cell"]) or WALLS.has(soldier["cell"]):
				return "invalid occupied cell."
			occupied.append(soldier["cell"])
	var enemy: Variant = combat["targets"][0]
	if not enemy is Dictionary or (not cell(enemy.get("cell")) if farm else enemy.get("cell") != Vector2i(10, 7)) or not integer(enemy.get("hp"), 0, 16 if farm else 8) or not integer(enemy.get("ammo"), 0, 4):
		return "invalid enemy state."
	var departed := false
	if farm:
		if not data.get("machine") is Dictionary:
			return "missing machine state."
		var machine: Dictionary = data["machine"]
		if not integer(machine.get("stage"), 0, 8) or not machine.get("hostile") is bool or not machine.get("departed") is bool or not cell(machine.get("pending_shot"), true) or not integer(machine.get("collected_round"), 0, combat["phase"]):
			return "invalid machine state."
		var route := [Vector2i(10,8), Vector2i(9,8), Vector2i(8,8), Vector2i(7,8), Vector2i(7,8), Vector2i(8,8), Vector2i(9,8), Vector2i(10,8), Vector2i(11,8)]
		var dynamic_route: bool = communication and data.get("protocol") is Dictionary and data["protocol"].get("route_set") == true
		if not dynamic_route and (enemy["cell"] != route[machine["stage"]] or (machine["departed"] and machine["stage"] != 8)):
			return "machine route mismatch."
		if (machine["stage"] >= 4) != (machine["collected_round"] > 0):
			return "machine collection mismatch."
		departed = machine["departed"]
	if enemy["hp"] > 0 and not departed and occupied.has(enemy["cell"]):
		return "enemy overlaps a soldier."
	if not combat.get("history") is Array:
		return "invalid shot history."
	for entry in combat["history"]:
		if not entry is Dictionary:
			return "invalid shot record."
		if not integer(entry.get("phase"), 1, combat["phase"]) or not integer(entry.get("soldier"), 0, 3) or not cell(entry.get("target")):
			return "invalid shot record position."
		if not integer(entry.get("chance"), 5, 95) or not integer(entry.get("roll"), 1, 100) or not integer(entry.get("damage"), 0, 4):
			return "invalid shot record result."
		if not entry.get("rng_before") is int or not entry.get("rng_after") is int:
			return "invalid shot random state."
	if not integer(ui.get("active"), -1, 3) or not cell(ui.get("selected"), true) or not cell(ui.get("pinned"), true):
		return "invalid selection."
	if not ui.get("sight") is bool or not ui.get("status") is String:
		return "invalid view state."
	if ui["active"] >= 0:
		var selected: Dictionary = combat["soldiers"][ui["active"]]
		if selected["extracted"] or selected["hp"] == 0 or selected["cell"] != ui["selected"]:
			return "selected soldier unavailable."
	if evac:
		if not data.get("evac") is Dictionary:
			return "missing evacuation state."
		var evacuation: Dictionary = data["evac"]
		if not evacuation.get("cohorts") is Array or evacuation["cohorts"].size() != 3:
			return "invalid civilian roster."
		if not integer(evacuation.get("selected"), 0, 2) or not integer(evacuation.get("last_phase"), 0, combat["phase"]) or not evacuation.get("order_used") is bool or not evacuation.get("ended") is bool or not evacuation.get("reason") is String:
			return "invalid evacuation phase."
		for index in range(3):
			var group: Variant = evacuation["cohorts"][index]
			if not group is Dictionary:
				return "invalid group data."
			var id: String = ["A", "B", "C"][index]
			if group.get("id") != id or not cell(group.get("cell")) or not integer(group.get("hp"),0,4) or not group.get("passed") is bool or not group.get("note") is String:
				return "invalid group identity or resources."
			if not ["hold","north","south"].has(group.get("order")) or not ["active","extracted","stranded"].has(group.get("status")):
				return "invalid group order or disposition."
			var manifest_id := "D%d-%s" % [data["campaign"]["deployment"],id] if roster_scene else id
			if group.get("manifest") != [manifest_id+"-01",manifest_id+"-02",manifest_id+"-03",manifest_id+"-04"]:
				return "invalid civilian manifest."
			if (group["hp"] == 0 and group["status"] != "stranded") or (evacuation["ended"] and group["status"] == "active"):
				return "invalid civilian outcome."
			if group["status"] == "extracted" and (group["cell"] != (Vector2i(10,1) if return_active else Vector2i(19,8)) or group["hp"] == 0):
				return "invalid evacuation location."
		for soldier in combat["soldiers"]:
			if not soldier.get("left_behind") is bool or (soldier["left_behind"] and soldier["extracted"]):
				return "invalid soldier disposition."
			if evacuation["ended"] and not soldier["extracted"] and not soldier["left_behind"] and not (rescue and soldier.get("condition") == "dead"):
				return "unresolved soldier disposition."
	if options:
		if not integer(data.get("breaker"),0,2):
			return "invalid breaker progress."
		if data["breaker"] == 2 and data["machine"]["pending_shot"] != Vector2i(-1,-1):
			return "disabled machine has a pending shot."
	if communication:
		if not data.get("protocol") is Dictionary:
			return "missing protocol state."
		var protocol: Dictionary = data["protocol"]
		for key in ["observed","acknowledged","pause_pending","pause_used","authenticated","route_set","diverted","component_collected","betrayed"]:
			if not protocol.get(key) is bool:
				return "invalid protocol flag."
		if not integer(protocol.get("waypoint"),0,3):
			return "invalid diversion progress."
		if (protocol["acknowledged"] and not protocol["observed"]) or (protocol["authenticated"] and not protocol["acknowledged"]) or (protocol["route_set"] and not protocol["authenticated"]):
			return "protocol prerequisite missing."
		if (protocol["pause_pending"] or protocol["pause_used"]) and not protocol["acknowledged"]:
			return "unacknowledged pause."
		if protocol["pause_pending"] and protocol["pause_used"]:
			return "pause already consumed."
		if (protocol["diverted"] or protocol["betrayed"]) and not protocol["route_set"]:
			return "unconfigured diversion."
		if protocol["diverted"] and protocol["betrayed"]:
			return "conflicting routing state."
		if protocol["component_collected"] != (protocol["waypoint"] == 3):
			return "alternate collection mismatch."
		if protocol["diverted"] and (data["machine"]["pending_shot"] != Vector2i(-1,-1) or data["machine"]["collected_round"] > 0):
			return "unsafe diverted machine state."
	if rescue:
		if not integer(data.get("rescue_target"),-1,3):
			return "invalid rescue selection."
		for index in range(4):
			var soldier: Dictionary = combat["soldiers"][index]
			if not ["active","critical","stable","dead"].has(soldier.get("condition")) or not integer(soldier.get("bleed"),0,3) or not integer(soldier.get("critical_epoch"),0,combat["phase"]):
				return "invalid casualty state."
			if not integer(soldier.get("medical"),0,2 if index == 1 else 0) or not integer(soldier.get("carrying"),-1,3) or not integer(soldier.get("carried_by"),-1,3):
				return "invalid rescue resources or carrier link."
			if soldier["condition"] != "active" and soldier["ap"] != 0:
				return "incapacitated soldier has action points."
			if soldier["condition"] == "critical" and (soldier["hp"] > 0 or soldier["hp"] <= -4 or soldier["bleed"] == 0):
				return "invalid critical wound."
			if soldier["condition"] == "stable" and (soldier["hp"] != 1 or soldier["bleed"] != 0):
				return "invalid stabilized casualty."
			if soldier["condition"] == "active" and (soldier["hp"] <= 0 or soldier["bleed"] != 0):
				return "invalid active soldier health."
			if soldier["condition"] == "dead" and (soldier["hp"] > 0 or soldier["bleed"] != 0 or soldier["left_behind"]):
				return "invalid death disposition."
		for index in range(4):
			var soldier: Dictionary = combat["soldiers"][index]
			var host: int = soldier["carried_by"]
			var passenger: int = soldier["carrying"]
			if host >= 0:
				var carrier: Dictionary = combat["soldiers"][host]
				if host == index or carrier["carrying"] != index or carrier["carried_by"] >= 0 or carrier["condition"] == "dead" or carrier["extracted"] or soldier["extracted"] or not ["critical","stable"].has(soldier["condition"]) or soldier["cell"] != carrier["cell"]:
					return "inconsistent carried casualty."
			if passenger >= 0 and (passenger == index or combat["soldiers"][passenger]["carried_by"] != index):
				return "inconsistent carrier."
		if ui["active"] >= 0 and combat["soldiers"][ui["active"]]["condition"] != "active":
			return "selected soldier is incapacitated."
	if story_scene:
		var story: Variant = data.get("story")
		if not story is Dictionary:
			return "missing scene state."
		if not story.get("opening_done") is bool or not story.get("closure_warning") is bool or not integer(story.get("opening_step"),0,2):
			return "invalid scene progress."
		if not ["unset","skipped","procedure","patients","logistics"].has(story.get("preference")) or not ["unset","cost","correction","treatment"].has(story.get("debrief_response")):
			return "invalid dialogue choice."
		if not story.get("powered_gate_groups") is Array or story["powered_gate_groups"].size() > 3:
			return "invalid gate record."
		var groups: Array = []
		for group in story["powered_gate_groups"]:
			if not ["A","B","C"].has(group) or groups.has(group): return "invalid gate event."
			groups.append(group)
		if not groups.is_empty() and not data["protocol"]["route_set"]: return "gate event without diversion."
		var valid_facts: Array = ["outcomes","machinery"]
		for event in data["rescue_events"]:
			if not event.get("closure_warning") is bool or event["phase"] > combat["phase"]: return "invalid rescue context."
			valid_facts.append(event["id"])
		if not story.get("knowledge") is Array or story["knowledge"].size() != 4: return "invalid knowledge roster."
		for known in story["knowledge"]:
			if not known is Array or known.size() > valid_facts.size(): return "invalid knowledge record."
			var seen: Array = []
			for fact in known:
				if not valid_facts.has(fact) or seen.has(fact): return "unknown or duplicate fact."
				seen.append(fact)
	if return_active:
		var retained: bool = ["diverted","disabled"].has(data["return_map"]["source"])
		if combat["targets"][0]["hp"] != (16 if retained else 0) or data["machine"]["pending_shot"] != Vector2i(-1,-1) or data["machine"]["hostile"] or data["machine"]["stage"] != 0 or data["machine"]["departed"] or data["breaker"] != 0:
			return "invalid return-map machinery."
	return ""
