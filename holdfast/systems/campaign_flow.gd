extends RefCounted
## Campaign between missions: roster assignments, shared knowledge, recording results,
## staging care, deployment and service-history details.
## Moved out of encounter_controller.gd; the controller keeps one-line wrappers.
const CampaignPersistence = preload("res://systems/campaign_persistence.gd")
const Roster = preload("res://campaign_roster.gd")
const ReturnRules = preload("res://return_rules.gd")

static func apply_assignments(board) -> void:
	for index in range(4):
		var id: String = board.campaign["assignments"][index]
		var soldier: Dictionary = board.soldiers[index]
		soldier["actor_id"] = id
		if id == "":
			soldier["name"] = "Vacant"
			soldier["mark"] = "-"
			soldier["extracted"] = true
			soldier["ap"] = 0
			soldier["medical"] = 0
		else:
			var actor = Roster.actor(board.campaign,id)
			soldier["name"] = actor["name"]
			soldier["mark"] = actor["name"].left(1)
			soldier["hp"] = actor["hp"]
	for cohort in board.cohorts:
		var id: String = cohort["id"]
		cohort["manifest"] = []
		for number in range(1,5): cohort["manifest"].append("D%d-%s-%02d" % [board.campaign["deployment"],id,number])
	board.rebuild_movement()

static func sync_knowledge(board) -> void:
	for index in range(4):
		var actor = Roster.actor(board.campaign,board.campaign["assignments"][index])
		if actor.is_empty(): continue
		for fact in board.knowledge[index]: board.append_unique(actor["knowledge"],"D%d:%s" % [board.campaign["deployment"],fact])

	# A patient forms this relationship memory only after receiving the event record.
	for event in board.rescue_events:
		if event["kind"] != "stabilized" or not board.knows(event["casualty"],event["id"]): continue
		var patient = Roster.actor(board.campaign,board.campaign["assignments"][event["casualty"]])
		var rescuer_id: String = board.campaign["assignments"][event["actor"]]
		if patient.is_empty() or rescuer_id == "": continue
		if not patient["relationships"].has(rescuer_id): patient["relationships"][rescuer_id] = []
		board.append_unique(patient["relationships"][rescuer_id],"Stabilized me during deployment %d." % board.campaign["deployment"])

static func commit_roster(board) -> void:
	record_campaign_result(board)
	board.record_return_result()

static func record_campaign_result(board) -> void:
	if not board.result_ready or board.retry_required() or board.campaign["committed"]: return
	var mission = {"id":"deployment-%d" % board.campaign["deployment"],"machine":board.machine_outcome(),
		"feeder":board.feeder_result(),"cohorts":board.cohorts.duplicate(true),"soldiers":[]}
	for index in range(4):
		var id: String = board.campaign["assignments"][index]
		if id == "": continue
		var actor = Roster.actor(board.campaign,id)
		var soldier: Dictionary = board.soldiers[index]
		actor["hp"] = soldier["hp"]
		actor["condition"] = soldier["condition"]
		actor["status"] = "dead" if soldier["condition"] == "dead" else ("left_behind" if not soldier["extracted"] else ("recovering" if soldier["condition"] != "active" else ("wounded" if soldier["hp"] < 8 else "ready")))
		var disposition = board.soldier_disposition(index)
		board.append_unique(actor["history"],"D%d: %s" % [board.campaign["deployment"],disposition])
		mission["soldiers"].append({"id":id,"disposition":disposition})
	for event in board.rescue_events:
		var rescuer = Roster.actor(board.campaign,board.campaign["assignments"][event["actor"]])
		var patient = Roster.actor(board.campaign,board.campaign["assignments"][event["casualty"]])
		if rescuer.is_empty() or patient.is_empty(): continue
		var action: String = {"stabilized":"stabilized","picked_up":"picked up","extracted_with":"carried out"}[event["kind"]]
		var memory = "D%d / %s: %s %s %s." % [board.campaign["deployment"],event["id"],rescuer["name"],action,patient["name"]]
		board.append_unique(rescuer["history"],memory)
		board.append_unique(patient["history"],memory)
	sync_knowledge(board)
	board.campaign["missions"].append(mission)
	board.campaign["committed"] = true
	if board.campaign["deployment"] == 1:
		for index in range(1,4):
			var actor = Roster.actor(board.campaign,board.campaign["assignments"][index])
			if not actor.is_empty() and actor["status"] == "dead" and Roster.actor(board.campaign,"reserve-%d" % index).is_empty():
				board.campaign["members"].append(Roster.replacement(index))

static func persist_campaign_result(board) -> void:
	var problem = CampaignPersistence.campaign_result(board.encounter_snapshot,board.campaign_path,board.report_path,board.completion_path,not board.retry_required())
	board.result_feedback = "Mission and roster saved. G: review service records." if problem == "" else problem

static func can_receive_staging_care(board) -> bool:
	if not board.campaign["committed"]: return false
	for actor in board.campaign["members"]:
		if actor["status"] == "recovering": return true
	return false

static func provide_staging_care(board) -> bool:
	if not can_receive_staging_care(board): return false
	# An explicit between-deployment interval, not a tactical heal or resurrection.
	for actor in board.campaign["members"]:
		if actor["status"] != "recovering": continue
		actor["hp"] = 1
		actor["condition"] = "active"
		actor["status"] = "wounded"
		board.append_unique(actor["history"],"After deployment %d: treatment and rest; cleared for duty at 1 HP." % board.campaign["deployment"])
	persist_campaign_result(board)
	board.queue_redraw()
	return true

static func can_deploy(board) -> bool:
	return not board.return_state["active"] and board.campaign["committed"] and board.campaign["deployment"] < 3 and Roster.next_assignments(board.campaign)[0] == "msg"

static func start_second_deployment(board) -> bool:
	if not can_deploy(board): return false
	var next = board.campaign.duplicate(true)
	next["deployment"] += 1
	next["committed"] = false
	next["assignments"] = Roster.next_assignments(board.campaign)
	var state := ReturnRules.initial()
	state["active"] = true
	state["source"] = ReturnRules.outcome(board.campaign)
	return board.replace_return_attempt(next,state)

static func open_roster(board) -> void:
	if not board.result_ready: return
	board.roster_open = true
	board.scene_view = ""
	board.queue_redraw()

static func roster_details(board, actor: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	lines.append("Traits: %s / %s" % actor["traits"])
	lines.append(actor["hook"])
	lines.append("")
	lines.append("RELATIONSHIPS")
	if actor["relationships"].is_empty(): lines.append("No established relationships.")
	for id in actor["relationships"]:
		for note in actor["relationships"][id]: lines.append(Roster.actor(board.campaign,id)["name"]+": "+note)
	lines.append("")
	lines.append("SERVICE HISTORY")
	if actor["history"].is_empty(): lines.append("No deployment history. New to this element.")
	for memory in actor["history"]:
		var parts: PackedStringArray = memory.split(": ",true,1)
		lines.append(parts[0].split(" / ")[0].replace("D","Deployment ")+": "+parts[1] if parts.size() == 2 else memory)
	lines.append("")
	lines.append("Briefed / witnessed records: %d" % actor["knowledge"].size())
	for mission in board.campaign["missions"]:
		var participated := false
		for entry in mission["soldiers"]: participated = participated or entry["id"] == actor["id"]
		if not participated: continue
		var evacuated := 0
		for cohort in mission["cohorts"]:
			if cohort["status"] == "extracted": evacuated += cohort["manifest"].size()
		lines.append("")
		lines.append(mission["id"].replace("deployment-","Deployment ")+": %d evacuated / %d stranded" % [evacuated,12-evacuated])
		lines.append(mission["machine"])
		lines.append(mission["feeder"])
	return lines

static func annotate_historical_pages(board, pages: Array) -> Array:
	if board.campaign["deployment"] == 2:
		# The original opening is historical, not a new scene performed by replacements.
		for index in range(3): pages[index]["speaker"] = "DEPLOYMENT 1 TRANSCRIPT / "+pages[index]["speaker"]
	return pages
