extends "res://farm_story.gd"
const RosterPanel = preload("res://presentation/roster_panel.gd")
const Roster = preload("res://campaign_roster.gd")
const CAMPAIGN_SLOT := "user://holdfast_c2_campaign.save"
const TACTICAL_SLOT := "user://holdfast_c2.save"
const ROSTER_RECT := Rect2(402,945,320,40)
const DEPLOY_RECT := Rect2(60,1080,480,58)
const BACK_RECT := Rect2(560,1080,480,58)
const CARE_RECT := Rect2(60,1002,1024,48)
var campaign: Dictionary = {}
var auto_resume := true
var campaign_path := CAMPAIGN_SLOT
var roster_open := false
var roster_index := 0
var history_page := 0

func _ready() -> void:
	super._ready()
	report_path = "user://holdfast_c2_result.save"
	completion_path = "user://holdfast_c2_completed.save"
	if campaign.is_empty(): campaign = Roster.initial()
	apply_assignments()
	if campaign["deployment"] == 2:
		opening_done = true
		opening_step = 2
		scene_view = ""
		status_text = "Deployment 2 roster test: same map, new civilian manifest. Existing wounds remain."
	save_feedback = "C2: K save / L load. G roster after resolution. Campaign resumes saved progress."
	if auto_resume and FileAccess.file_exists(campaign_path):
		load_encounter(campaign_path)

func apply_assignments() -> void:
	for index in range(4):
		var id: String = campaign["assignments"][index]
		var soldier: Dictionary = soldiers[index]
		soldier["actor_id"] = id
		if id == "":
			soldier["name"] = "Vacant"
			soldier["mark"] = "-"
			soldier["extracted"] = true
			soldier["ap"] = 0
			soldier["medical"] = 0
		else:
			var actor := Roster.actor(campaign,id)
			soldier["name"] = actor["name"]
			soldier["mark"] = actor["name"].left(1)
			soldier["hp"] = actor["hp"]
	for cohort in cohorts:
		var id: String = cohort["id"]
		cohort["manifest"] = []
		for number in range(1,5): cohort["manifest"].append("D%d-%s-%02d" % [campaign["deployment"],id,number])
	rebuild_movement()

func rescue_layout() -> String: return "gdd3.1-c2-roster"
func rescue_slot() -> String: return TACTICAL_SLOT

func encounter_snapshot() -> Dictionary:
	var snapshot := super.encounter_snapshot()
	snapshot["campaign"] = campaign.duplicate(true)
	return snapshot

func restore_extra_snapshot(snapshot: Dictionary) -> void:
	super.restore_extra_snapshot(snapshot)
	campaign = snapshot["campaign"].duplicate(true)
	roster_open = false
	roster_index = 0
	history_page = 0

func save_encounter(path: String = TACTICAL_SLOT) -> bool:
	if [RESULT_SLOT,STORY_SLOT].has(path): path = TACTICAL_SLOT
	var success := super.save_encounter(path)
	if success:
		var problem := checkpoint()
		save_feedback = "C2 saved: deployment, roster, service history and current actions." if problem == "" else problem
	return success

func load_encounter(path: String = TACTICAL_SLOT) -> bool:
	if [RESULT_SLOT,STORY_SLOT].has(path): path = TACTICAL_SLOT
	var success := super.load_encounter(path)
	if success: save_feedback = "C2 restored: deployment %d / 2. Identities and losses retained." % campaign["deployment"]
	return success

func checkpoint() -> String:
	return Persistence.write(encounter_snapshot(),campaign_path)

func original_actor(index: int, original_name: String) -> bool:
	return soldiers[index].get("actor_id","") == original_name.to_lower()

func present(index: int) -> bool:
	return soldiers[index].get("actor_id","") != "" and super.present(index)

func soldier_disposition(index: int) -> String:
	if soldiers[index].get("actor_id","") == "": return "NOT DEPLOYED / vacancy"
	return super.soldier_disposition(index)

func append_unique(array: Array, value: String) -> void:
	if not array.has(value): array.append(value)

func sync_knowledge() -> void:
	for index in range(4):
		var actor := Roster.actor(campaign,campaign["assignments"][index])
		if actor.is_empty(): continue
		for fact in knowledge[index]: append_unique(actor["knowledge"],"D%d:%s" % [campaign["deployment"],fact])

	# A patient forms this relationship memory only after receiving the event record.
	for event in rescue_events:
		if event["kind"] != "stabilized" or not knows(event["casualty"],event["id"]): continue
		var patient := Roster.actor(campaign,campaign["assignments"][event["casualty"]])
		var rescuer_id: String = campaign["assignments"][event["actor"]]
		if patient.is_empty() or rescuer_id == "": continue
		if not patient["relationships"].has(rescuer_id): patient["relationships"][rescuer_id] = []
		append_unique(patient["relationships"][rescuer_id],"Stabilized me during deployment %d." % campaign["deployment"])

func commit_roster() -> void:
	if not result_ready or retry_required() or campaign["committed"]: return
	var mission := {"id":"deployment-%d" % campaign["deployment"],"machine":machine_outcome(),
		"feeder":feeder_result(),"cohorts":cohorts.duplicate(true),"soldiers":[]}
	for index in range(4):
		var id: String = campaign["assignments"][index]
		if id == "": continue
		var actor := Roster.actor(campaign,id)
		var soldier: Dictionary = soldiers[index]
		actor["hp"] = soldier["hp"]
		actor["condition"] = soldier["condition"]
		actor["status"] = "dead" if soldier["condition"] == "dead" else ("left_behind" if not soldier["extracted"] else ("recovering" if soldier["condition"] != "active" else ("wounded" if soldier["hp"] < 8 else "ready")))
		var disposition := soldier_disposition(index)
		append_unique(actor["history"],"D%d: %s" % [campaign["deployment"],disposition])
		mission["soldiers"].append({"id":id,"disposition":disposition})
	for event in rescue_events:
		var rescuer := Roster.actor(campaign,campaign["assignments"][event["actor"]])
		var patient := Roster.actor(campaign,campaign["assignments"][event["casualty"]])
		if rescuer.is_empty() or patient.is_empty(): continue
		var action: String = {"stabilized":"stabilized","picked_up":"picked up","extracted_with":"carried out"}[event["kind"]]
		var memory := "D%d / %s: %s %s %s." % [campaign["deployment"],event["id"],rescuer["name"],action,patient["name"]]
		append_unique(rescuer["history"],memory)
		append_unique(patient["history"],memory)
	sync_knowledge()
	campaign["missions"].append(mission)
	campaign["committed"] = true
	if campaign["deployment"] == 1:
		for index in range(1,4):
			var actor := Roster.actor(campaign,campaign["assignments"][index])
			if not actor.is_empty() and actor["status"] == "dead" and Roster.actor(campaign,"reserve-%d" % index).is_empty():
				campaign["members"].append(Roster.replacement(index))

func finalize_result() -> void:
	var already := result_ready
	super.finalize_result()
	if not result_ready or already: return
	commit_roster()
	persist_campaign_result()

func persist_campaign_result() -> void:
	var problem := checkpoint()
	if problem == "": problem = Persistence.write(encounter_snapshot(),report_path)
	if problem == "" and not retry_required(): problem = Persistence.write(encounter_snapshot(),completion_path)
	result_feedback = "Mission and roster saved. G: review service records." if problem == "" else problem

func persist_story_report() -> void:
	super.persist_story_report()
	if result_ready and not retry_required():
		sync_knowledge()
		persist_campaign_result()

func can_receive_staging_care() -> bool:
	if not campaign["committed"]: return false
	for actor in campaign["members"]:
		if actor["status"] == "recovering": return true
	return false

func provide_staging_care() -> bool:
	if not can_receive_staging_care(): return false
	# An explicit between-deployment interval, not a tactical heal or resurrection.
	for actor in campaign["members"]:
		if actor["status"] != "recovering": continue
		actor["hp"] = 1
		actor["condition"] = "active"
		actor["status"] = "wounded"
		append_unique(actor["history"],"After deployment %d: treatment and rest; cleared for duty at 1 HP." % campaign["deployment"])
	persist_campaign_result()
	queue_redraw()
	return true

func can_deploy() -> bool:
	return campaign["committed"] and campaign["deployment"] == 1 and Roster.next_assignments(campaign)[0] == "msg"

func start_second_deployment() -> bool:
	if not can_deploy(): return false
	var next := campaign.duplicate(true)
	next["deployment"] = 2
	next["committed"] = false
	next["assignments"] = Roster.next_assignments(campaign)
	return replace_attempt(next)

func replace_attempt(next: Dictionary) -> bool:
	var fresh = load("res://farm_roster.tscn").instantiate()
	fresh.auto_resume = false
	fresh.campaign = next
	fresh.campaign_path = campaign_path
	fresh.preference = preference
	get_parent().add_child(fresh)
	fresh.report_path = report_path
	fresh.completion_path = completion_path
	var problem: String = fresh.checkpoint()
	if problem != "":
		fresh.queue_free()
		result_feedback = problem
		queue_redraw()
		return false
	if get_tree().current_scene == self: get_tree().current_scene = fresh
	queue_free()
	return true

func restart_attempt() -> void:
	if campaign["committed"]:
		roster_open = true
		queue_redraw()
		return
	replace_attempt(campaign.duplicate(true))

func open_roster() -> void:
	if not result_ready: return
	roster_open = true
	scene_view = ""
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		if roster_open: roster_open = false
		else: open_roster()
		queue_redraw()
		return
	if not roster_open:
		if result_ready and scene_view == "" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
			if ROSTER_RECT.has_point(point):
				open_roster()
				return
		super._unhandled_input(event)
		return
	var rows := []
	for index in range(campaign["members"].size()): rows.append(Rect2(60,210+index*67,300,58))
	var point := Vector2.ZERO
	if event is InputEventMouse: point = get_global_transform_with_canvas().affine_inverse()*event.position
	var action := ModalInput.command(event,point,
		{KEY_ESCAPE:"back",KEY_ENTER:"deploy",KEY_T:"care",KEY_RIGHT:"right",KEY_LEFT:"left",KEY_DOWN:"down",KEY_UP:"up",KEY_K:"save",KEY_L:"load"},
		{"care":CARE_RECT,"deploy":DEPLOY_RECT,"back":BACK_RECT},rows)
	match action:
		"back": roster_open = false
		"deploy": start_second_deployment()
		"care": provide_staging_care()
		"right": history_page += 1
		"left": history_page = maxi(0,history_page-1)
		"down", "up":
			roster_index = posmod(roster_index+(1 if action=="down" else -1),campaign["members"].size())
			history_page = 0
		"save": save_encounter()
		"load": load_encounter()
		_:
			if action.begins_with("row:"):
				roster_index = int(action.get_slice(":",1))
				history_page = 0
	queue_redraw()

func roster_details(actor: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	lines.append("Traits: %s / %s" % actor["traits"])
	lines.append(actor["hook"])
	lines.append("")
	lines.append("RELATIONSHIPS")
	if actor["relationships"].is_empty(): lines.append("No established relationships.")
	for id in actor["relationships"]:
		for note in actor["relationships"][id]: lines.append(Roster.actor(campaign,id)["name"]+": "+note)
	lines.append("")
	lines.append("SERVICE HISTORY")
	if actor["history"].is_empty(): lines.append("No deployment history. New to this element.")
	for memory in actor["history"]:
		var parts: PackedStringArray = memory.split(": ",true,1)
		lines.append(parts[0].split(" / ")[0].replace("D","Deployment ")+": "+parts[1] if parts.size() == 2 else memory)
	lines.append("")
	lines.append("Briefed / witnessed records: %d" % actor["knowledge"].size())
	for mission in campaign["missions"]:
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

func log_pages() -> Array:
	var pages := super.log_pages()
	if campaign["deployment"] == 2:
		# The original opening is historical, not a new scene performed by replacements.
		for index in range(3): pages[index]["speaker"] = "DEPLOYMENT 1 TRANSCRIPT / "+pages[index]["speaker"]
	return pages

func _draw() -> void:
	if not roster_open:
		super._draw()
		if scene_view != "": return
		if not result_ready:
			SceneChrome.header(self,font,"HOLDFAST / C2 · DEPLOYMENT %d / 2" % campaign.get("deployment",1),805,Color.WHITE)
		else:
			SceneChrome.button(self,font,ROSTER_RECT,"Roster / service history [G]",Color("344f46"),27,17)
			if campaign["committed"]:
				SceneChrome.button(self,font,RETRY_RECT,"Roster [Q / G]",Color("304965"),35,19)
		return
	RosterPanel.render(self,font,board_projection,roster_panel_snapshot())

func roster_panel_snapshot() -> Dictionary:
	var details := roster_details(campaign["members"][roster_index])
	history_page = clampi(history_page,0,maxi(1,ceili(details.size()/9.0))-1)
	return {
		"roster_index":roster_index,
		"history_page":history_page,
		"CARE_RECT":CARE_RECT,
		"DEPLOY_RECT":DEPLOY_RECT,
		"BACK_RECT":BACK_RECT,
		"result_feedback":result_feedback,
		"campaign":campaign.duplicate(true),
		"details":details,
		"care":can_receive_staging_care(),
		"deploy":can_deploy()}
