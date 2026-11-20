extends "res://encounter_controller.gd"
## Mission 03 · Main Street (spec: docs/missions/main-street.md). Act I's major encounter.
## The Farm Road machine rules drive a bigger Drover recovery platform (shoot, isolate at
## the junction box, or redirect it through the control panel to park across the alley).
## Adds the first Fallow contact (cutter + coordination node, mark → transform), Drover
## security abandoning a component, and the Act I close. Save/load for this mission comes later.
const MainMission = preload("res://missions/main_street.tres")
const FallowCutter = preload("res://systems/fallow_cutter.gd")
const CampaignRecord = preload("res://systems/campaign_record.gd")

const FALLOW_ENTRY := Vector2i(17,2)
const FALLOW_NODE := Vector2i(18,2)
const SUBSTATION: Array[Vector2i] = [Vector2i(11,11),Vector2i(12,11)]
const REPLACEMENTS := ["Reyes","Okafor","Lindqvist"]

var mission_copy: Resource = null
var fallow: Dictionary = {}
var drover := {"cell":Vector2i(8,7),"present":true,"component":Vector2i(-1,-1),"recovered":false}
var record_path := ""

func mission_definition() -> Resource:
	if mission_override != null: return mission_override
	if mission_copy == null: mission_copy = MainMission.duplicate(true)
	return mission_copy

func _ready() -> void:
	initialize_tactical()
	initialize_machine()
	initialize_evacuation()
	initialize_breaker()
	initialize_protocol()
	initialize_rescue()
	initialize_results()
	initialize_story()
	initialize_roster(false)
	report_path = "user://holdfast_m03_result.save"
	completion_path = "user://holdfast_m03_completed.save"
	campaign_path = "user://holdfast_m03_campaign.save"
	fallow = FallowCutter.initial(FALLOW_ENTRY,FALLOW_NODE)
	carry_over_squad()
	status_text = "Main Street: the platform is grinding toward the substation. Get the town moving east."
	enemy_message = "Drover platform on Main Street, security walking beside it."
	save_feedback = "Saving isn't available on Main Street yet."
	rebuild_movement()

## Wounds and losses from earlier missions (latest record wins). MSG always deploys.
func carry_over_squad() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	var entry: Dictionary = missions.get(2,missions.get(1,{}))
	if entry.is_empty() or not entry.has("squad"): return
	var count := mini(entry["squad"].size(),soldiers.size())
	# Survivors (and earlier replacements) keep their names first, so a new replacement never doubles up.
	for index in range(1,count):
		var previous: Dictionary = entry["squad"][index]
		if previous["condition"] != "dead" and previous.has("name"):
			soldiers[index]["name"] = previous["name"]
			soldiers[index]["mark"] = previous["name"].left(1)
		if previous["condition"] in ["critical","stable"]: soldiers[index]["hp"] = 4
	for index in range(1,count):
		if entry["squad"][index]["condition"] != "dead": continue
		var taken: Array = soldiers.map(func(soldier): return soldier["name"])
		for pick in REPLACEMENTS:
			if taken.has(pick): continue
			soldiers[index]["name"] = pick
			soldiers[index]["mark"] = pick.left(1)
			soldiers[index]["replacement_for"] = entry["squad"][index].get("name","")
			break

# ---------------------------------------------------------------- map rules

func cohort_at(cell: Vector2i) -> int:
	for index in range(cohorts.size()):
		if cohorts[index]["status"] == "active" and cohorts[index]["cell"] == cell: return index
	return -1

func platform_parked() -> bool:
	return protocol["diverted"] and protocol["component_collected"] and enemies[0]["hp"] > 0

## Next to the parked platform, ground is safe from the cutter's marks. The route waypoints and
## the exit are never marked either, so a route can be cut but the town is never sealed.
func sheltered_from_fallow(cell: Vector2i) -> bool:
	var mission := mission_definition()
	if cell == mission.civilian_exit or mission.squad_exits.has(cell) or mission.civilian_routes.values().has(cell): return true
	return platform_parked() and absi(cell.x-enemies[0]["cell"].x)+absi(cell.y-enemies[0]["cell"].y) <= 1

func add_rift(cell: Vector2i) -> void:
	var fixtures: Array[Vector2i] = mission_definition().fixtures
	if not fixtures.has(cell): fixtures.append(cell)

## Push whoever stood on new rift ground to the nearest open square.
func throw_clear(cell: Vector2i) -> void:
	var frontier: Array[Vector2i] = [cell]
	var seen := {cell:true}
	var landing := NONE
	var cursor := 0
	while cursor < frontier.size() and landing == NONE:
		var current: Vector2i = frontier[cursor]
		cursor += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current+direction
			if seen.has(next) or not cell_is_in_bounds(next) or WALL_CELLS.has(next): continue
			seen[next] = true
			if not FIXTURES.has(next) and soldier_at(next) < 0 and cohort_at(next) < 0 and target_at(next) < 0:
				landing = next
				break
			frontier.append(next)
	if landing == NONE: return
	var soldier := soldier_at(cell)
	if soldier >= 0: soldiers[soldier]["cell"] = landing
	var group := cohort_at(cell)
	if group >= 0: cohorts[group]["cell"] = landing

func target_at(cell: Vector2i) -> int:
	if machine_present() and enemies[0]["cell"] == cell: return 0
	if not fallow.is_empty() and FallowCutter.unit_at(fallow,cell) >= 0: return 10+FallowCutter.unit_at(fallow,cell)
	if drover["present"] and drover["cell"] == cell: return 20
	return -1

func civilian_safe(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell): return false
	if target_at(cell) >= 0: return false
	if not platform_parked() and (cell == next_machine_cell() or cell == machine["pending_shot"]): return false
	return true

func on_civilian_step(_cohort: Dictionary, _cell: Vector2i) -> void:
	pass

func civilian_threats() -> Array[Vector2i]:
	var threats: Array[Vector2i] = []
	if machine_present() and not platform_parked():
		threats.append(enemies[0]["cell"])
		if machine["pending_shot"] != NONE: threats.append(machine["pending_shot"])
	threats.append_array(FallowCutter.threat_cells(fallow))
	threats.append_array(round_noise)
	return threats

func deadline() -> int:
	var mission := mission_definition()
	if machine["collected_round"] > 0: return mini(mission.closing_round,machine["collected_round"]+2)
	return mission.closing_round

func mission_completion_reason(round_number: int) -> String:
	var mission := mission_definition()
	if round_number >= deadline(): return "Substation down: corridor closed" if machine["collected_round"] > 0 else mission.closure_reason
	if all_extracted() and remaining_civilians() == 0: return mission.evacuation_reason
	return ""

# ---------------------------------------------------------------- actions

func interrupt_node() -> bool:
	if ended or not FallowCutter.node_present(fallow):
		status_text = "No node to interrupt yet." if not ended else "Operation over."
		queue_redraw()
		return false
	if not soldier_can_act(active_soldier) or soldiers[active_soldier]["ap"] < 1 or FallowCutter.distance(soldiers[active_soldier]["cell"],fallow["node"]) > 1:
		status_text = "Interrupt: a soldier with 1 AP next to the node at (%d,%d)." % [fallow["node"].x,fallow["node"].y]
		queue_redraw()
		return false
	if fallow["interrupted"]:
		status_text = "The node is already interrupted this turn."
		queue_redraw()
		return false
	soldiers[active_soldier]["ap"] -= 1
	status_text = FallowCutter.interrupt(fallow)
	rebuild_movement()
	return true

func recover_component() -> bool:
	if ended or drover["component"] == NONE or drover["recovered"]:
		status_text = "Component already recovered." if drover["recovered"] else "Nothing to recover yet."
		queue_redraw()
		return false
	if not soldier_can_act(active_soldier) or soldiers[active_soldier]["ap"] < 1 or FallowCutter.distance(soldiers[active_soldier]["cell"],drover["component"]) > 1:
		status_text = "Recover: a soldier with 1 AP next to the component at (%d,%d)." % [drover["component"].x,drover["component"].y]
		queue_redraw()
		return false
	soldiers[active_soldier]["ap"] -= 1
	drover["recovered"] = true
	status_text = "%s recovers the Drover component: a sealed coolant regulator, tagged in a script nobody can read." % soldiers[active_soldier]["name"]
	rebuild_movement()
	return true

func fallow_targeted() -> int:
	return FallowCutter.unit_at(fallow,sight_target()) if not fallow.is_empty() else -1

func fire_block_reason() -> String:
	if fallow_targeted() < 0:
		if drover["present"] and sight_target() == drover["cell"]: return "Drover security isn't a target. It's guarding its people."
		return super.fire_block_reason()
	if ended: return "Operation ended."
	if not soldier_can_act(active_soldier): return "Select a standing soldier."
	var soldier: Dictionary = soldiers[active_soldier]
	if soldier.get("carrying",-1) >= 0: return "Cannot fire while carrying a casualty."
	if soldier["ap"] < 1: return "No AP left."
	if soldier["attacked"]: return "Already fired this round."
	if soldier["ammo"] < 1: return "Out of ammunition: reload."
	if not sight_preview(soldier["cell"],sight_target())["can_fire"]: return "No clear shot at that range."
	return ""

func try_fire() -> bool:
	if fallow_targeted() < 0: return super.try_fire()
	var reason := fire_block_reason()
	if reason != "":
		status_text = reason
		queue_redraw()
		return false
	var soldier: Dictionary = soldiers[active_soldier]
	var target := sight_target()
	var index := fallow_targeted()
	var info := sight_preview(soldier["cell"],target)
	soldier["ap"] -= 1
	soldier["ammo"] -= 1
	soldier["attacked"] = true
	round_noise.append(soldier["cell"])
	var roll := shot_rng.randi_range(1,100)
	if roll <= info["chance"]:
		status_text = "%s fires (%d%%): %s" % [soldier["name"],info["chance"],FallowCutter.take_hit(fallow,index,FallowCutter.SHOT_DAMAGE)]
	else:
		status_text = "%s fires (%d%%) and misses." % [soldier["name"],info["chance"]]
	if FallowCutter.unit_at(fallow,target) < 0: pinned_target = NONE
	rebuild_movement()
	return true

# ---------------------------------------------------------------- turn

func resolve_enemy_turn() -> void:
	if last_enemy_phase == phase: return
	var lines: Array[String] = []
	if platform_parked():
		last_enemy_phase = phase
		lines.append("Platform parked across the alley, shielding the ground beside it.")
	else:
		activate_origin_machine()
		if enemy_message != "": lines.append("Platform: " + enemy_message)
	last_enemy_phase = phase
	update_drover()
	var fallow_line := FallowCutter.act(fallow,self)
	if fallow_line != "": lines.append(fallow_line)
	if drover["component"] != NONE and drover["present"]:
		drover["present"] = false
		lines.append("Drover security drops a component and peels away toward its own people.")
	enemy_message = " ".join(lines)
	rebuild_movement()
	check_recovery_failure()
	finalize_result()

func update_drover() -> void:
	if not drover["present"]: return
	if fallow["stage"] == "active" or (fallow["stage"] == "signaled" and phase >= FallowCutter.ENTRY_ROUND):
		drover["component"] = drover["cell"]
		return
	if not machine_present(): return
	var beside: Vector2i = enemies[0]["cell"]+Vector2i(0,-1)
	if cell_is_in_bounds(beside) and not WALL_CELLS.has(beside) and not FIXTURES.has(beside) and soldier_at(beside) < 0 and cohort_at(beside) < 0:
		drover["cell"] = beside

func begin_player_phase() -> void:
	super.begin_player_phase()
	if fallow["stage"] == "signaled": status_text = "Round %d. A distortion is open at the alley's north-east end. Something arrives next turn." % phase
	elif FallowCutter.cutter_alive(fallow): status_text = "Round %d. Violet squares become rift next Fallow turn. Get people off them, or interrupt the node." % phase
	else: status_text = "Round %d. %s" % [phase,enemy_message.left(140)]

func enemy_intent() -> String:
	var parts: Array[String] = []
	if platform_parked(): parts.append("Platform parked across the alley (redirected)")
	elif enemies[0]["hp"] <= 0: parts.append("Platform demolished")
	else: parts.append("PLATFORM " + super.enemy_intent().replace("collect skid","reach the substation").replace("Machine","Platform").replace("machine","platform").replace("skid","substation"))
	match fallow["stage"]:
		"signaled": parts.append("FALLOW: distortion at (%d,%d), arrival next turn" % [FALLOW_ENTRY.x,FALLOW_ENTRY.y])
		"active":
			if FallowCutter.cutter_alive(fallow): parts.append("FALLOW: %d squares marked%s" % [fallow["marked"].size()," · node interrupted" if fallow["interrupted"] else ""])
			else: parts.append("FALLOW: cutter down; rifts remain")
	return " · ".join(parts) if not parts.is_empty() else "Main Street quiet."

func danger_summary() -> String:
	return "Platform reaches the substation at stage %d; then the corridor closes two rounds later. Fallow marks turn to rift one turn after they appear." % mission_definition().machine_collect_stage

func machine_label() -> String:
	return "PLATFORM"

func platform_state() -> String:
	if enemies[0]["hp"] <= 0: return "demolished"
	if disabled(): return "isolated"
	if platform_parked() or protocol["diverted"]: return "redirected"
	if machine["collected_round"] > 0: return "substation"
	return "active"

func machine_outcome() -> String:
	match platform_state():
		"demolished": return "Platform demolished: Main Street open, nothing preserved."
		"isolated": return "Platform isolated at the junction box: intact, inert, the crossing kept clear."
		"redirected": return "Platform redirected into the alley as a barrier. Its work order is readable: substation coolant maintenance."
		"substation": return "Platform reached the substation. Power failed across the corridor."
	return "Platform still moving when the squad withdrew."

func feeder_result() -> String:
	var parts: Array[String] = []
	parts.append("Drover component recovered." if drover["recovered"] else ("Drover component left behind." if drover["component"] != NONE else "Drover security never broke away."))
	parts.append("%d squares of rift ground." % fallow["rifts"].size())
	if fallow["log"].has("cutter_down"): parts.append("Fallow cutter killed.")
	if fallow["interrupts"] > 0: parts.append("Node interrupted %d time%s." % [fallow["interrupts"],"" if fallow["interrupts"] == 1 else "s"])
	return " ".join(parts)

func result_title() -> String:
	if retry_required(): return "ATTEMPT ENDED / RETRY REQUIRED"
	var everyone := evacuated_people() == 12
	for soldier in soldiers:
		everyone = everyone and soldier["extracted"] and soldier["condition"] != "dead"
	return "MAIN STREET / TOWN EVACUATED" if everyone else "MAIN STREET / PARTIAL EVACUATION"

# ---------------------------------------------------------------- story

func opening_pages() -> Array:
	return [
		{"speaker":"ACT I · MISSION 03 / MAIN STREET","text":"County calls it an assault engine. It's the size of a house, grinding east down Main Street toward the substation while the town tries to leave.\n\nWard's order: protect the evacuation corridor and stop dangerous platform movement.","tag":"Evacuate the town · stop the platform · extract the squad"},
		{"speaker":"BELL / JUNCTION BOX","text":"‘There's a junction box on the south side. Kill its power and it stops where it stands. Or there's a control panel up by the shops, if we can talk to it like the one at the farm.’\n\nOrtiz: ‘Or we take it apart before it reaches the substation.’","tag":"Demolish, isolate, or redirect: each keeps something and costs something"},
		{"speaker":"PARK","text":"‘There's something walking beside it. Not a machine. It's watching the platform, not us.’\n\nThe radios crackle with the same eleven-second gap as Farm Road.","tag":"Drover security escorts the platform; it isn't hostile"}]

func current_pages() -> Array:
	if scene_view == "opening": return opening_pages()
	if scene_view == "debrief": return debrief_pages()
	return log_pages()

func log_pages() -> Array:
	var pages := opening_pages()
	pages.append({"speaker":"INTELLIGENCE / MAIN STREET","text":enemy_intent()+"\n\n"+danger_summary(),"tag":"Observation, not doctrine"})
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func debrief_pages() -> Array:
	var out: Array[String] = []
	var left: Array[String] = []
	for cohort in cohorts:
		if cohort["status"] == "extracted": out.append(cohort["id"])
		else: left.append(cohort["id"])
	var pages: Array = [{"speaker":"MAIN STREET / VERIFIED FIELD REPORT","text":"Evacuated: %s.\nLeft behind: %s.\n\n%s\n%s" % [", ".join(out) if not out.is_empty() else "none",", ".join(left) if not left.is_empty() else "none",machine_outcome(),feeder_result()],"tag":"Read to the available survivors"}]
	pages.append({"speaker":"PARK","text":"‘It marked the ground, and then the ground wasn't ground anymore. It didn't talk. It didn't take anyone. It just… changed the street.’\n\nNo one in the squad can say what it wanted. The record says only what it did.","tag":"Fallow: learnable tactics, no stated motive"})
	if not retry_required():
		pages.append({"speaker":"ACT I COMPLETE / THE BREAKING OF SILENCE","text":"The squad files its assessment: the machines at Farm Road went around people; the Greys at the river went for them; the thing on Main Street answered to neither. These are not one invasion.\n\nWard accepts the local assessment and asks for independent corroboration. The question isn't whether every alien serves the same commander anymore. It's what each of them is trying to save, and what the new one will do.","tag":"The single-command hypothesis is formally rejected"})
	return pages

func advance_scene() -> void:
	var pages := current_pages()
	if scene_page+1 < pages.size():
		scene_page += 1
		if scene_view == "opening": opening_step = scene_page
	elif scene_view == "opening": finish_opening()
	elif scene_view == "log": toggle_log()
	else: scene_view = ""
	queue_redraw()

func scene_options() -> Array:
	return []

func choose_scene_option(_index: int) -> void:
	pass

# ---------------------------------------------------------------- saves and retry

func save_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Saving isn't available on Main Street yet."
	status_text = save_feedback
	queue_redraw()
	return false

func load_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Loading isn't available on Main Street yet."
	status_text = save_feedback
	queue_redraw()
	return false

func save_mission_result() -> void:
	result_feedback = "Mission recorded in the campaign record."

func persist_campaign_result() -> void:
	pass

func commit_roster() -> void:
	pass

func persist_story_report() -> void:
	pass

func restart_attempt() -> void:
	var fresh = load("res://main_street.tscn").instantiate()
	fresh.auto_resume = false
	fresh.record_path = record_path
	get_parent().add_child(fresh)
	queue_free()

# ---------------------------------------------------------------- drawing (HUD map layer)

func draw_mission_layer(projection, font: Font) -> void:
	var size := CELL_SIZE
	# Street and alley tint so the two corridors read at a glance.
	for x in range(1,GRID_SIZE.x+1):
		for y in [7,8,9]:
			draw_rect(Rect2(projection.cell_anchor(Vector2i(x,y)),Vector2.ONE*size),Color(0.35,0.35,0.38,0.18))
		for y in [2,3,4]:
			draw_rect(Rect2(projection.cell_anchor(Vector2i(x,y)),Vector2.ONE*size),Color(0.45,0.38,0.25,0.12))
	draw_string(font,projection.cell_anchor(Vector2i(1,7))+Vector2(2,-3),"MAIN STREET",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("c9d3e0"))
	draw_string(font,projection.cell_anchor(Vector2i(1,2))+Vector2(2,-3),"NORTH ALLEY",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e8c9a0"))
	for cell in SUBSTATION:
		draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(2,2),Vector2.ONE*(size-4)),Color("6b5a1e"))
	draw_string(font,projection.cell_anchor(SUBSTATION[0])+Vector2(0,size+11),"SUBSTATION",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("f7cd6c"))
	for label in [[BREAKER_CELL,"JB","junction box"],[CONSOLE_CELL,"CP","control panel"]]:
		var at: Vector2 = projection.cell_anchor(label[0])
		draw_rect(Rect2(at+Vector2(3,3),Vector2.ONE*(size-6)),Color("2b3a4a"))
		draw_rect(Rect2(at+Vector2(3,3),Vector2.ONE*(size-6)),Color("8be6de"),false,2)
		draw_string(font,at+Vector2(0,23),label[1],HORIZONTAL_ALIGNMENT_CENTER,size,12,Color("8be6de"))
	# Rifts and marks.
	for cell in fallow.get("rifts",[]):
		var at: Vector2 = projection.cell_anchor(cell)
		draw_rect(Rect2(at,Vector2.ONE*size),Color("1a0f24"))
		draw_line(at+Vector2(4,6),at+Vector2(size-6,size-4),Color("8a5cc7"),2)
		draw_line(at+Vector2(size-8,4),at+Vector2(8,size-6),Color("5e3a8c"),2)
	for cell in fallow.get("marked",[]):
		var at: Vector2 = projection.cell_anchor(cell)
		draw_rect(Rect2(at+Vector2(1,1),Vector2.ONE*(size-2)),Color(0.6,0.3,0.95,0.35))
		draw_rect(Rect2(at+Vector2(1,1),Vector2.ONE*(size-2)),Color("b98cff"),false,2)
	if platform_parked():
		for direction in DIRECTIONS:
			var cell: Vector2i = enemies[0]["cell"]+direction
			if cell_is_in_bounds(cell): draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(4,4),Vector2.ONE*(size-8)),Color(0.55,0.9,0.87,0.2))
	# Platform, its next square and any pending shot.
	if machine_present():
		var at: Vector2 = projection.cell_anchor(enemies[0]["cell"])
		draw_rect(Rect2(at+Vector2(-3,-3),Vector2.ONE*(size+6)),Color("8a6a3a"))
		draw_rect(Rect2(at+Vector2(-3,-3),Vector2.ONE*(size+6)),Color("ffcf7a"),false,2)
		draw_string(font,at+Vector2(-3,23),"PLAT",HORIZONTAL_ALIGNMENT_CENTER,size+6,11,Color.WHITE)
		var next := next_machine_cell()
		if next != NONE and not platform_parked():
			draw_rect(Rect2(projection.cell_anchor(next)+Vector2(3,3),Vector2.ONE*(size-6)),Color("ffb75a"),false,2)
		if machine["pending_shot"] != NONE:
			var shot: Vector2 = projection.cell_anchor(machine["pending_shot"])
			draw_line(shot+Vector2(6,6),shot+Vector2(size-6,size-6),Color("ff5c66"),3)
			draw_line(shot+Vector2(size-6,6),shot+Vector2(6,size-6),Color("ff5c66"),3)
	elif enemies[0]["hp"] <= 0:
		draw_string(font,projection.cell_anchor(enemies[0]["cell"])+Vector2(0,23),"WRECK",HORIZONTAL_ALIGNMENT_CENTER,size,10,Color("aebbb6"))
	# Drover security and its component.
	if drover["present"]:
		var center: Vector2 = projection.cell_anchor(drover["cell"])+Vector2(18,18)
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-13),center+Vector2(12,10),center+Vector2(-12,10)]),Color("6fa0c8"))
		draw_string(font,center+Vector2(-30,-17),"DROVER",HORIZONTAL_ALIGNMENT_CENTER,60,9,Color("a8d0f0"))
	if drover["component"] != NONE and not drover["recovered"]:
		var at: Vector2 = projection.cell_anchor(drover["component"])
		draw_circle(at+Vector2(18,18),7,Color("7fe0ff"))
		draw_string(font,at+Vector2(-12,-3),"COMPONENT",HORIZONTAL_ALIGNMENT_CENTER,60,9,Color("7fe0ff"))
	# Fallow.
	if fallow.get("stage","") == "signaled":
		var at: Vector2 = projection.cell_anchor(FALLOW_ENTRY)
		draw_rect(Rect2(at+Vector2(12,-6),Vector2(12,size+12)),Color(0.75,0.5,1,0.6))
		draw_string(font,at+Vector2(-20,-8),"DISTORTION",HORIZONTAL_ALIGNMENT_CENTER,76,9,Color("d9b8ff"))
	if FallowCutter.node_present(fallow):
		var node_at: Vector2 = projection.cell_anchor(fallow["node"])+Vector2(18,18)
		draw_circle(node_at,10,Color("5e3a8c") if fallow["interrupted"] else Color("b98cff"))
		draw_string(font,node_at+Vector2(-24,-14),"NODE" + (" (CUT)" if fallow["interrupted"] else ""),HORIZONTAL_ALIGNMENT_CENTER,48,9,Color("d9b8ff"))
		if FallowCutter.cutter_alive(fallow) and not fallow["interrupted"]:
			draw_dashed_line(node_at,projection.cell_anchor(fallow["cutter"]["cell"])+Vector2(18,18),Color(0.73,0.55,1,0.5),2,5)
	if FallowCutter.cutter_alive(fallow):
		var center: Vector2 = projection.cell_anchor(fallow["cutter"]["cell"])+Vector2(18,18)
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-15),center+Vector2(9,0),center+Vector2(0,15),center+Vector2(-9,0)]),Color("2a1a3a"))
		draw_polyline(PackedVector2Array([center+Vector2(0,-15),center+Vector2(9,0),center+Vector2(0,15),center+Vector2(-9,0),center+Vector2(0,-15)]),Color("d9b8ff"),2)
		draw_rect(Rect2(center+Vector2(-40,-31),Vector2(80,13)),Color(0.05,0.03,0.08,0.85))
		draw_string(font,center+Vector2(-40,-21),"CUTTER %d HP" % fallow["cutter"]["hp"],HORIZONTAL_ALIGNMENT_CENTER,80,9,Color("d9b8ff"))
		if sight_mode and pinned_target == fallow["cutter"]["cell"]:
			draw_rect(Rect2(projection.cell_anchor(fallow["cutter"]["cell"])+Vector2(1,1),Vector2.ONE*(size-2)),Color("e6a2c7"),false,2)
