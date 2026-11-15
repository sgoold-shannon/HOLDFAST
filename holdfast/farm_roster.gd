extends "res://farm_story.gd"
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
	return SaveStore.save(encounter_snapshot(),campaign_path)

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
	if problem == "": problem = SaveStore.save(encounter_snapshot(),report_path)
	if problem == "" and not retry_required(): problem = SaveStore.save(encounter_snapshot(),completion_path)
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
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE: roster_open = false
			KEY_ENTER: start_second_deployment()
			KEY_T: provide_staging_care()
			KEY_RIGHT: history_page += 1
			KEY_LEFT: history_page = maxi(0,history_page-1)
			KEY_DOWN:
				roster_index = (roster_index+1)%campaign["members"].size()
				history_page = 0
			KEY_UP:
				roster_index = posmod(roster_index-1,campaign["members"].size())
				history_page = 0
			KEY_K: save_encounter()
			KEY_L: load_encounter()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
		if CARE_RECT.has_point(point): provide_staging_care()
		elif DEPLOY_RECT.has_point(point): start_second_deployment()
		elif BACK_RECT.has_point(point): roster_open = false
		else:
			for index in range(campaign["members"].size()):
				if Rect2(60,210+index*67,300,58).has_point(point):
					roster_index = index
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
			draw_rect(Rect2(35,10,805,34),Color("0e1412"))
			draw_string(font,Vector2(40,36),"HOLDFAST / C2 · DEPLOYMENT %d / 2" % campaign.get("deployment",1),HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
		else:
			draw_rect(ROSTER_RECT,Color("344f46"))
			draw_string(font,ROSTER_RECT.position+Vector2(0,27),"Roster / service history [G]",HORIZONTAL_ALIGNMENT_CENTER,320,17,Color.WHITE)
			if campaign["committed"]:
				draw_rect(RETRY_RECT,Color("304965"))
				draw_string(font,RETRY_RECT.position+Vector2(0,35),"Roster [Q / G]",HORIZONTAL_ALIGNMENT_CENTER,320,19,Color.WHITE)
		return
	draw_rect(Rect2(0,0,1144,1224),Color("0e1412"))
	result_line(65,"HOLDFAST / C2 · PERSISTENT ROSTER",Color("8be6de"),22)
	result_line(115,"Deployment %d / 2 · %d mission records" % [campaign["deployment"],campaign["missions"].size()],Color("f7cd6c"),25)
	result_line(155,"Confirmed deaths remain in service records. Replacements have separate identities.",Color("aebbb6"),17)
	for index in range(campaign["members"].size()):
		var member: Dictionary = campaign["members"][index]
		var rect := Rect2(60,210+index*67,300,58)
		draw_rect(rect,Color("476b59") if index == roster_index else Color("263b32"))
		draw_string(font,rect.position+Vector2(14,24),member["name"]+(" · new" if member["replacement"] else ""),HORIZONTAL_ALIGNMENT_LEFT,270,20,Color.WHITE)
		draw_string(font,rect.position+Vector2(14,47),member["status"].replace("_"," ").to_upper(),HORIZONTAL_ALIGNMENT_LEFT,270,15,Color("f7cd6c"))
	var actor: Dictionary = campaign["members"][roster_index]
	draw_string(font,Vector2(400,238),"%s · %s · HP %d/8" % [actor["name"],["MSG","Medic","Engineer","Recon"][actor["role"]],actor["hp"]],HORIZONTAL_ALIGNMENT_LEFT,660,25,Color.WHITE)
	var lines := roster_details(actor)
	var page_count := maxi(1,ceili(lines.size()/9.0))
	history_page = clampi(history_page,0,page_count-1)
	draw_multiline_string(font,Vector2(400,290),"\n".join(lines.slice(history_page*9,history_page*9+9)),HORIZONTAL_ALIGNMENT_LEFT,660,21,-1,Color("d6ded9"))
	draw_string(font,Vector2(400,765),"Record %d/%d · ← / → pages · ↑ / ↓ soldier" % [history_page+1,page_count],HORIZONTAL_ALIGNMENT_LEFT,660,17,Color("8be6de"))
	result_line(840,"Next deployment: available survivors keep their remaining HP.",Color.WHITE,19)
	result_line(875,"Casualty-care patients rest. Living people left behind remain unavailable.",Color("aebbb6"),18)
	result_line(910,"Ammunition, AP and deployed medic charges are replenished at staging.",Color("aebbb6"),18)
	result_line(955,"Deployment 2 is a roster test on the same map, with new civilian identities.",Color("8be6de"),18)
	draw_rect(CARE_RECT,Color("304965") if can_receive_staging_care() else Color("28332d"))
	draw_string(font,CARE_RECT.position+Vector2(15,32),"Staging care [T] · treatment and rest; patients return at 1 HP" if can_receive_staging_care() else "No patients awaiting staging care",HORIZONTAL_ALIGNMENT_LEFT,994,19,Color.WHITE)
	var action := "Deploy roster [Enter]"
	if campaign["deployment"] == 2: action = "Two-deployment fixture complete" if campaign["committed"] else "Finish this deployment first"
	elif not campaign["committed"]: action = "Retry required before continuation"
	elif not can_deploy(): action = "MSG needs staging care [T]"
	for item in [[DEPLOY_RECT,action],[BACK_RECT,"Back to results [Esc]"]]:
		draw_rect(item[0],Color("304965"))
		draw_string(font,item[0].position+Vector2(15,35),item[1],HORIZONTAL_ALIGNMENT_LEFT,450,20,Color.WHITE)
	result_line(1180,result_feedback,Color("aebbb6"),15)
