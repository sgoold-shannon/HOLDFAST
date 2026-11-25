extends "res://encounter_controller.gd"
## Mission 05 · Rail Yard (spec: docs/missions/rail-yard.md). A Grey extraction site:
## three field pens, a transport on a visible schedule, an archive terminal and a supply
## handcar. People, evidence or supplies; an optional Grey trade for survey records.
## The Farm Road machine is switched off. Save/load for this mission comes later.
const YardMission = preload("res://missions/rail_yard.tres")
const GreyYard = preload("res://systems/grey_yard.gd")
const CampaignRecord = preload("res://systems/campaign_record.gd")

const TRANSPORT: Array[Vector2i] = [Vector2i(17,7),Vector2i(18,7),Vector2i(17,8),Vector2i(18,8),Vector2i(17,9),Vector2i(18,9)]
const TRANSPORT_RAMP := Vector2i(16,8)
const TERMINAL := Vector2i(14,4)
const COLLECTOR_START := Vector2i(15,8)
const SENTRIES: Array[Vector2i] = [Vector2i(15,5),Vector2i(15,11)]
const DISRUPTOR_START := Vector2i(16,10)
const HANDCAR_START := Vector2i(12,11)
const HANDCAR_ROLL := 3
const ENGINEER := 2              # Bell: the electronic lock bypass
const CUT_AP := 2
const REPLACEMENTS := ["Reyes","Okafor","Lindqvist"]

var yard: Dictionary = {}
var record_path := ""
var pens: Array = []             # per group: {"cell","cut":0,"open":false}
var archive := {"steps":0,"needed":2,"state":"none"}   # none / partial / full
var handcar := {"cell":HANDCAR_START,"released":false,"out":false}
## Carry-ins.
var river_taken: Array = []
var drone_evidence := false

func mission_definition() -> Resource:
	if mission_override != null: return mission_override
	return YardMission

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
	report_path = "user://holdfast_m05_result.save"
	completion_path = "user://holdfast_m05_completed.save"
	campaign_path = "user://holdfast_m05_campaign.save"
	read_carry_ins()
	yard = GreyYard.initial(COLLECTOR_START,SENTRIES,DISRUPTOR_START,TRANSPORT)
	archive["needed"] = 1 if drone_evidence else 2
	var origins := ["Rail workers held at the yard","Townspeople brought in from the east road","Travellers taken off the interstate"]
	for index in range(cohorts.size()):
		var cohort: Dictionary = cohorts[index]
		cohort["penned"] = true
		cohort["note"] = "Held in a field pen"
		pens.append({"cell":cohort["cell"],"cut":0,"open":false})
		cohort["manifest"] = []
		if index < river_taken.size():
			cohort["origin"] = "River Bridge group %s" % river_taken[index]
			for number in range(1,5): cohort["manifest"].append("RB-%s-%02d" % [river_taken[index],number])
		else:
			cohort["origin"] = origins[index]
			for number in range(1,5): cohort["manifest"].append("RY-%s-%02d" % [cohort["id"],number])
	carry_over_squad()
	status_text = "Rail Yard: three pens, one transport. It lifts off at the end of round %d." % GreyYard.DEPART_ROUND
	enemy_message = "Grey extraction crew working the yard."
	save_feedback = "Saving isn't available at the Rail Yard yet."
	rebuild_movement()

func read_carry_ins() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	river_taken = missions.get(2,{}).get("taken",[]).duplicate()
	drone_evidence = ["observed","shot","shot_after","downed_by_drovers"].has(missions.get(4,{}).get("drone",""))

func carry_over_squad() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	var entry: Dictionary = {}
	for id in [4,3,2,1]:
		if missions.get(id,{}).has("squad"):
			entry = missions[id]
			break
	if entry.is_empty(): return
	var count := mini(entry["squad"].size(),soldiers.size())
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

func target_at(cell: Vector2i) -> int:
	if not yard.is_empty():
		var index := GreyYard.unit_at(yard,cell)
		if index >= 0: return 10+index
	if not handcar["out"] and handcar["cell"] == cell: return 30
	return -1

func blacked_out(cell: Vector2i) -> bool:
	return not yard.is_empty() and GreyYard.blacked_out(yard,cell)

func civilian_safe(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell): return false
	return target_at(cell) < 0

func civilian_waypoint(_order: String) -> Vector2i:
	return civilian_exit()

func route_available(_order: String) -> bool:
	return true

func route_label(order: String) -> String:
	return "West exit (north tracks)" if order == "north" else "West exit (south tracks)"

func on_civilian_step(_cohort: Dictionary, _cell: Vector2i) -> void:
	pass

func move_cohort(cohort: Dictionary, budget: int) -> void:
	if cohort.get("penned",false):
		cohort["note"] = "Held in a field pen" if cohort["status"] == "active" else cohort["note"]
		return
	super.move_cohort(cohort,budget)

## Penned groups sit out the civilian phase entirely: they can't scatter through a field lock.
func resolve_civilian_phase() -> void:
	var held: Array = []
	for cohort in cohorts:
		if cohort.get("penned",false) and cohort["status"] == "active":
			cohort["status"] = "held"
			held.append(cohort)
	super.resolve_civilian_phase()
	for cohort in held: cohort["status"] = "active"

## In a blackout there's no radio: MSG only reaches a group right next to him.
func blackout_order_block(index: int) -> String:
	if active_soldier != 0 or index < 0 or index >= cohorts.size(): return ""
	var near := GreyYard.distance(soldiers[0]["cell"],cohorts[index]["cell"]) <= 1
	if not near and (blacked_out(soldiers[0]["cell"]) or blacked_out(cohorts[index]["cell"])):
		return "Blackout: no radio. MSG has to be right next to group %s." % cohorts[index]["id"]
	return ""

func order_cohort(index: int, order: String) -> bool:
	var block := blackout_order_block(index)
	if block != "": return reject(block)
	return super.order_cohort(index,order)

func order_exit(index: int) -> bool:
	var block := blackout_order_block(index)
	if block != "": return reject(block)
	return super.order_exit(index)

func civilian_threats() -> Array[Vector2i]:
	var threats: Array[Vector2i] = GreyYard.threat_cells(yard)
	threats.append_array(round_noise)
	return threats

func deadline() -> int:
	return mission_definition().closing_round

func mission_completion_reason(round_number: int) -> String:
	return MissionObjectives.completion_reason(mission_definition(),round_number,0,all_extracted(),remaining_civilians())

# ---------------------------------------------------------------- actions

func reject(text: String) -> bool:
	status_text = text
	queue_redraw()
	return false

func ready_reason(cost: int = 1) -> String:
	if ended: return "Operation over."
	if not soldier_can_act(active_soldier): return "Select a standing soldier."
	if soldiers[active_soldier].get("carrying",-1) >= 0: return "Put the casualty down first."
	if soldiers[active_soldier]["ap"] < cost: return "Needs %d AP." % cost
	return ""

func pen_next_to(cell: Vector2i) -> int:
	for index in range(pens.size()):
		if not pens[index]["open"] and cohorts[index].get("penned",false) and cohorts[index]["status"] == "active" and GreyYard.distance(pens[index]["cell"],cell) == 1: return index
	return -1

func open_pen(index: int, how: String) -> void:
	pens[index]["open"] = true
	var cohort: Dictionary = cohorts[index]
	cohort["penned"] = false
	cohort["panic"] = maxi(cohort.get("panic",0),1)
	cohort["order"] = "north"
	cohort["passed"] = false
	cohort["note"] = "Freed; shaken, heading for the west exit"
	if not yard["load"].is_empty() and yard["load"]["group"] == index:
		yard["load"] = {}
	var reaction := GreyYard.provoke(yard,"pen",false)
	status_text = "%s %s pen %s. Four people out, shaken, pointed at the west exit. %s" % [soldiers[active_soldier]["name"],how,cohort["id"],reaction]

func bypass_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if active_soldier != ENGINEER: return "%s bypasses the field locks. Anyone can cut one instead." % soldiers[ENGINEER]["name"]
	if pen_next_to(soldiers[active_soldier]["cell"]) < 0: return "Stand next to a closed pen."
	if blacked_out(soldiers[active_soldier]["cell"]): return "Blackout: the lock's electronics are dead. Cut it instead."
	return ""

func bypass_lock() -> bool:
	var reason := bypass_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	open_pen(pen_next_to(soldiers[active_soldier]["cell"]),"bypasses the field lock on")
	rebuild_movement()
	return true

func cut_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if pen_next_to(soldiers[active_soldier]["cell"]) < 0: return "Stand next to a closed pen."
	return ""

## Bolt cutters: 2 AP in total, over one or two turns. Works in a blackout.
func cut_lock() -> bool:
	var reason := cut_reason()
	if reason != "": return reject(reason)
	var index := pen_next_to(soldiers[active_soldier]["cell"])
	soldiers[active_soldier]["ap"] -= 1
	pens[index]["cut"] += 1
	if pens[index]["cut"] >= CUT_AP: open_pen(index,"cuts open")
	else: status_text = "%s starts cutting pen %s: 1 more AP." % [soldiers[active_soldier]["name"],cohorts[index]["id"]]
	rebuild_movement()
	return true

func download_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if archive["state"] == "full": return "Archive already downloaded."
	if yard["withdrawn"]: return "The terminal went dark when the transport left."
	if GreyYard.distance(soldiers[active_soldier]["cell"],TERMINAL) != 1: return "Stand next to the terminal (%d,%d)." % [TERMINAL.x,TERMINAL.y]
	if blacked_out(soldiers[active_soldier]["cell"]): return "Blackout: the terminal won't talk."
	return ""

func download_archive() -> bool:
	var reason := download_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	archive["steps"] += 1
	var reaction := GreyYard.provoke(yard,"terminal",true)
	if archive["steps"] >= archive["needed"]:
		archive["state"] = "full"
		status_text = "%s pulls the whole archive: resource accounting, and files on Drover crews, Reptilian sites and human command. %s" % [soldiers[active_soldier]["name"],reaction]
	else:
		status_text = "%s starts the download (%d/%d). %s" % [soldiers[active_soldier]["name"],archive["steps"],archive["needed"],reaction]
	rebuild_movement()
	return true

func brake_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if handcar["released"]: return "Handcar already rolling." if not handcar["out"] else "Handcar recovered."
	if GreyYard.distance(soldiers[active_soldier]["cell"],handcar["cell"]) != 1: return "Stand next to the handcar (%d,%d)." % [handcar["cell"].x,handcar["cell"].y]
	return ""

func release_brake() -> bool:
	var reason := brake_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	handcar["released"] = true
	status_text = "%s kicks the brake off. The handcar starts rolling west with its generator cells." % soldiers[active_soldier]["name"]
	rebuild_movement()
	return true

func trade_offered() -> bool:
	return not yard.is_empty() and phase == GreyYard.TRADE_ROUND and yard["trade"]["state"] == "none" and not yard["withdrawn"]

func trade_reason() -> String:
	if not trade_offered(): return "No offer on the channel." if yard["trade"]["state"] == "none" else "Trade: " + yard["trade"]["state"]
	var reason := ready_reason()
	if reason != "": return reason
	if active_soldier != 0: return "Only MSG answers the channel. Select MSG."
	if blacked_out(soldiers[0]["cell"]): return "Blackout: MSG's radio is dead."
	return ""

func accept_trade() -> bool:
	var reason := trade_reason()
	if reason != "": return reject(reason)
	soldiers[0]["ap"] -= 1
	status_text = GreyYard.accept_trade(yard,phase)
	if archive["state"] == "none": archive["state"] = "partial"
	rebuild_movement()
	return true

func fire_block_reason() -> String:
	if ended: return "Operation ended."
	if not soldier_can_act(active_soldier): return "Select a standing soldier."
	var soldier: Dictionary = soldiers[active_soldier]
	if soldier.get("carrying",-1) >= 0: return "Cannot fire while carrying a casualty."
	if soldier["ap"] < 1: return "No AP left."
	if soldier["attacked"]: return "Already fired this round."
	if soldier["ammo"] < 1: return "Out of ammunition: reload."
	if GreyYard.unit_at(yard,sight_target()) < 0: return "Aim [T], then click a Grey unit to pin it."
	if not sight_preview(soldier["cell"],sight_target())["can_fire"]: return "No clear shot at that range."
	return ""

func try_fire() -> bool:
	var reason := fire_block_reason()
	if reason != "": return reject(reason)
	var soldier: Dictionary = soldiers[active_soldier]
	var target := sight_target()
	var index := GreyYard.unit_at(yard,target)
	var info := sight_preview(soldier["cell"],target)
	soldier["ap"] -= 1
	soldier["ammo"] -= 1
	soldier["attacked"] = true
	round_noise.append(soldier["cell"])
	round_noise.append(target)
	var roll := shot_rng.randi_range(1,100)
	if roll <= info["chance"]:
		status_text = "%s fires (%d%%): %s" % [soldier["name"],info["chance"],GreyYard.take_hit(yard,index,GreyYard.SHOT_DAMAGE)]
	else:
		var reaction := GreyYard.provoke(yard,"shot",true)
		status_text = "%s fires (%d%%) and misses. %s" % [soldier["name"],info["chance"],reaction]
	if GreyYard.unit_at(yard,target) < 0: pinned_target = NONE
	rebuild_movement()
	return true

# ---------------------------------------------------------------- turn

func resolve_enemy_turn() -> void:
	if last_enemy_phase == phase: return
	last_enemy_phase = phase
	var lines: Array[String] = []
	var grey_line := GreyYard.act(yard,self)
	if grey_line != "": lines.append(grey_line)
	var car := roll_handcar()
	if car != "": lines.append(car)
	enemy_message = " ".join(lines) if not lines.is_empty() else "The yard is quiet."
	rebuild_movement()
	check_recovery_failure()
	finalize_result()

func roll_handcar() -> String:
	if not handcar["released"] or handcar["out"]: return ""
	var moved := 0
	for step in range(HANDCAR_ROLL):
		var next: Vector2i = handcar["cell"]+Vector2i.LEFT
		if next.x < 1:
			handcar["out"] = true
			return "The handcar rolls out of the yard. Generator cells recovered."
		if soldier_at(next) >= 0 or cohort_at(next) >= 0 or GreyYard.unit_at(yard,next) >= 0 or WALL_CELLS.has(next):
			return "The handcar waits: something's on the track at (%d,%d)." % [next.x,next.y] if moved == 0 else "The handcar rolls %d and stops behind (%d,%d)." % [moved,next.x,next.y]
		handcar["cell"] = next
		moved += 1
	if handcar["cell"].x <= 1:
		handcar["out"] = true
		return "The handcar rolls out of the yard. Generator cells recovered."
	return ""

func begin_player_phase() -> void:
	super.begin_player_phase()
	if trade_offered(): status_text = "Round %d. The Grey channel opens: survey records for clearance of the transport, ramp and terminal for %d rounds. MSG can accept this round only." % [phase,GreyYard.TRADE_ROUNDS]
	elif not yard["withdrawn"] and not yard["load"].is_empty(): status_text = "Round %d. The Collector is loading group %s next Grey phase. Hit it or open that pen." % [phase,cohorts[yard["load"]["group"]]["id"]]
	else: status_text = "Round %d. %s" % [phase,enemy_message.left(150)]

func enemy_intent() -> String:
	if yard["withdrawn"]: return "Transport gone%s." % (" with group " + ", ".join(yard["aboard"]) if not yard["aboard"].is_empty() else "")
	var parts: Array[String] = ["Transport lifts off after round %d" % GreyYard.DEPART_ROUND]
	if not yard["load"].is_empty(): parts.append("LOADING group %s" % cohorts[yard["load"]["group"]]["id"])
	if GreyYard.trade_active(yard): parts.append("TRADE holds through round %d" % yard["trade"]["until"])
	elif yard["hostile"]: parts.append("SENTRIES HOSTILE")
	if yard["dark"] != GreyYard.NONE: parts.append("Blackout at (%d,%d)" % [yard["dark"].x,yard["dark"].y])
	return " · ".join(parts)

func danger_summary() -> String:
	if yard["withdrawn"]: return "The Greys are gone. The yard is unsafe after round %d." % deadline()
	return "The Collector marks a pen in rounds 3, 5 and 7 and takes it the round after. Violet squares go dark next round: no radio, no electronics."

func machine_outcome() -> String:
	var aboard: Array = yard["aboard"]
	if aboard.is_empty(): return "Nobody went aboard the transport."
	return "Group %s went aboard the Grey transport. Named, in custody, not erased." % ", ".join(aboard)

func feeder_result() -> String:
	var parts: Array[String] = []
	parts.append({"full":"Full archive recovered.","partial":"Survey records received in trade.","none":"No archive."}[archive["state"]])
	parts.append("Handcar supplies recovered." if handcar["out"] else "Handcar left in the yard.")
	match yard["trade"]["state"]:
		"honored": parts.append("Trade honored on both sides.")
		"active": parts.append("Trade still running when the yard closed.")
		"broken": parts.append("Trade broken by the squad (%s)." % yard["trade"]["broken_by"])
	return " ".join(parts)

func trade_result() -> String:
	var state: String = yard["trade"]["state"]
	return "honored" if state == "active" else state

func greys_down() -> Array:
	var out: Array = []
	for entry in yard["units"]:
		if entry["hp"] <= 0: out.append(entry["kind"])
	return out

func result_title() -> String:
	if retry_required(): return "ATTEMPT ENDED / RETRY REQUIRED"
	var everyone := evacuated_people() == 12
	for soldier in soldiers:
		everyone = everyone and soldier["extracted"] and soldier["condition"] != "dead"
	return "RAIL YARD / EVERYONE OUT" if everyone else "RAIL YARD / PARTIAL"

# ---------------------------------------------------------------- story

func opening_pages() -> Array:
	var names := "Two of the pens hold strangers." if river_taken.is_empty() else "Park checks the manifest against River Bridge: group %s is here, alive." % ", ".join(river_taken)
	return [
		{"speaker":"ACT II · MISSION 05: RAIL YARD","text":"The county rail yard has been turned into a Grey extraction site. Three field pens. A transport at the east end, already loading.\n\n" + names,"tag":"Free the pens · get the squad out · archive and supplies if you can"},
		{"speaker":"BELL","text":"‘The pens are field locks. I can bypass them. If they black out the area, it's bolt cutters, two minutes a pen.’\n\nOrtiz: ‘And the terminal by the transport? And the handcar full of generator cells?’","tag":"People, evidence or supplies: you won't get all three"},
		{"speaker":"PARK","text":"‘They're on a clock. That transport lifts at the end of round %d whether the pens are empty or not.’" % GreyYard.DEPART_ROUND,"tag":"The extraction clock beats territory"}]

func current_pages() -> Array:
	if scene_view == "opening": return opening_pages()
	if scene_view == "debrief": return debrief_pages()
	return log_pages()

func log_pages() -> Array:
	var pages := opening_pages()
	pages.append({"speaker":"INTELLIGENCE / RAIL YARD","text":enemy_intent()+"\n\n"+danger_summary(),"tag":"Observation, not doctrine"})
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func debrief_pages() -> Array:
	var out: Array[String] = []
	var left: Array[String] = []
	for cohort in cohorts:
		var label := "%s (%s)" % [cohort["id"],cohort.get("origin","")]
		if cohort["status"] == "extracted": out.append(label)
		elif cohort["status"] != "taken": left.append(label)
	var pages: Array = [{"speaker":"RAIL YARD / VERIFIED FIELD REPORT","text":"Freed and out: %s.\nLeft in the yard: %s.\n\n%s\n%s" % [", ".join(out) if not out.is_empty() else "none",", ".join(left) if not left.is_empty() else "none",machine_outcome(),feeder_result()],"tag":"Names stay on the record either way"}]
	if yard["trade"]["state"] != "none":
		pages.append({"speaker":"MSG / TRADE NOTE","text":"Object: the archive's survey section. Time: three rounds. Route: transport, ramp and terminal untouched.\n\nThe pens were never part of it. Nobody can trade for people who didn't agree to be traded.","tag":"An honored bargain permits exactly what it promised"})
	if archive["state"] == "full":
		pages.append({"speaker":"BELL","text":"‘It's bookkeeping. Tonnage, samples, schedules. And whole folders on the Drover crews, on sites we've never heard of, and on us.’\n\nThe Greys watch everyone.","tag":"Evidence: separate threats, and the Greys monitor all of them"})
	for cohort in cohorts:
		if cohort["status"] == "extracted" and str(cohort.get("origin","")).begins_with("River Bridge"):
			pages.append({"speaker":"ORTIZ","text":"‘We had their names. Now we have them.’","tag":"The River Bridge thread is closed"})
			break
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
	save_feedback = "Saving isn't available at the Rail Yard yet."
	status_text = save_feedback
	queue_redraw()
	return false

func load_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Loading isn't available at the Rail Yard yet."
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
	var fresh = load("res://rail_yard.tscn").instantiate()
	fresh.auto_resume = false
	fresh.record_path = record_path
	get_parent().add_child(fresh)
	queue_free()

# ---------------------------------------------------------------- drawing (HUD map layer)

func draw_mission_layer(projection, font: Font) -> void:
	var size := CELL_SIZE
	for y in [3,7,11,14]:
		for x in range(1,GRID_SIZE.x+1):
			var at: Vector2 = projection.cell_anchor(Vector2i(x,y))
			draw_line(at+Vector2(0,12),at+Vector2(size,12),Color(0.55,0.5,0.42,0.5),2)
			draw_line(at+Vector2(0,24),at+Vector2(size,24),Color(0.55,0.5,0.42,0.5),2)
	for cell in TRANSPORT:
		draw_rect(Rect2(projection.cell_anchor(cell),Vector2.ONE*size),Color("8d97a8") if not yard["withdrawn"] else Color(0.3,0.3,0.32,0.4))
	if not yard["withdrawn"]:
		draw_string(font,projection.cell_anchor(TRANSPORT[0])+Vector2(-4,-4),"TRANSPORT · lifts after r%d" % GreyYard.DEPART_ROUND,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e6e9f0"))
		draw_rect(Rect2(projection.cell_anchor(TRANSPORT_RAMP)+Vector2(2,10),Vector2(size-4,16)),Color(0.8,0.85,0.95,0.35))
	# Terminal.
	var term: Vector2 = projection.cell_anchor(TERMINAL)
	draw_rect(Rect2(term+Vector2(3,3),Vector2.ONE*(size-6)),Color("2b3a4a"))
	draw_rect(Rect2(term+Vector2(3,3),Vector2.ONE*(size-6)),Color("8be6de"),false,2)
	draw_string(font,term+Vector2(-20,-4),"ARCHIVE %s" % ({"none":"%d/%d" % [archive["steps"],archive["needed"]],"partial":"survey","full":"FULL"}[archive["state"]]),HORIZONTAL_ALIGNMENT_CENTER,76,9,Color("8be6de"))
	# Pens.
	for index in range(pens.size()):
		var pen: Dictionary = pens[index]
		var at: Vector2 = projection.cell_anchor(pen["cell"])
		var closed: bool = not pen["open"] and cohorts[index].get("penned",false)
		draw_rect(Rect2(at+Vector2(-3,-3),Vector2.ONE*(size+6)),Color("b98cff") if closed else Color(0.5,0.5,0.5,0.4),false,3)
		var tag := "PEN %s" % cohorts[index]["id"] + (" · CUT %d/%d" % [pen["cut"],CUT_AP] if closed and pen["cut"] > 0 else "") + ("" if closed else (" · ABOARD" if cohorts[index]["status"] == "taken" else " · OPEN"))
		draw_string(font,at+Vector2(-20,size+12),tag,HORIZONTAL_ALIGNMENT_CENTER,76,9,Color("d9b8ff"))
	# Handcar.
	if not handcar["out"]:
		var at: Vector2 = projection.cell_anchor(handcar["cell"])
		draw_rect(Rect2(at+Vector2(2,8),Vector2(size-4,20)),Color("7a6a3a"))
		draw_string(font,at+Vector2(-14,-3),"HANDCAR" + (" →west" if handcar["released"] else " (brake)"),HORIZONTAL_ALIGNMENT_CENTER,64,9,Color("f7cd6c"))
	if yard["withdrawn"]: return
	# Blackout: dark now, and marked for next round.
	for pair in [[yard["dark"],Color(0.05,0.05,0.08,0.55)],[yard["mark"],Color(0.6,0.3,0.95,0.25)]]:
		if pair[0] == GreyYard.NONE: continue
		for dx in range(-GreyYard.BLACKOUT_RADIUS,GreyYard.BLACKOUT_RADIUS+1):
			for dy in range(-GreyYard.BLACKOUT_RADIUS,GreyYard.BLACKOUT_RADIUS+1):
				var cell: Vector2i = pair[0]+Vector2i(dx,dy)
				if cell_is_in_bounds(cell): draw_rect(Rect2(projection.cell_anchor(cell),Vector2.ONE*size),pair[1])
	# Greys.
	for entry in yard["units"]:
		if entry["hp"] <= 0: continue
		var center: Vector2 = projection.cell_anchor(entry["cell"])+Vector2(18,18)
		draw_circle(center,12,Color("c9d3e0"))
		draw_circle(center+Vector2(-4,-3),3,Color("10141a"))
		draw_circle(center+Vector2(4,-3),3,Color("10141a"))
		draw_rect(Rect2(center+Vector2(-46,-31),Vector2(92,13)),Color(0.05,0.06,0.08,0.85))
		draw_string(font,center+Vector2(-46,-21),"%s %d HP" % [entry["kind"].to_upper(),entry["hp"]],HORIZONTAL_ALIGNMENT_CENTER,92,9,Color("ff8a80") if GreyYard.firing(yard) else Color("c9d3e0"))
		if not entry["aim"].is_empty():
			draw_line(center,projection.cell_anchor(entry["aim"]["cell"])+Vector2(18,18),Color(1,0.3,0.35,0.85),3)
			draw_rect(Rect2(projection.cell_anchor(entry["aim"]["cell"])+Vector2(2,2),Vector2.ONE*(size-4)),Color("ff5c66"),false,2)
		if sight_mode and pinned_target == entry["cell"]:
			draw_rect(Rect2(projection.cell_anchor(entry["cell"])+Vector2(1,1),Vector2.ONE*(size-2)),Color("e6a2c7"),false,2)
	if not yard["load"].is_empty():
		var cohort: Dictionary = cohorts[yard["load"]["group"]]
		var at: Vector2 = projection.cell_anchor(cohort["cell"])
		draw_rect(Rect2(at+Vector2(-6,-6),Vector2.ONE*(size+12)),Color("ff5c66"),false,3)
		draw_string(font,at+Vector2(-10,-8),"LOADING",HORIZONTAL_ALIGNMENT_CENTER,56,10,Color("ff8a80"))
