extends "res://farm_road.gd"
## B2: one cohort order each player phase, safe routes, closure after civilian phase.
const TurnResolution = preload("res://systems/turn_resolution.gd")
const EvacuationRules = preload("res://systems/civilian_evacuation.gd")
var evacuation_rules: EvacuationRules
const EVAC_SLOT := "user://holdfast_b2.save"
var EXIT_CELL: Vector2i:
	get: return mission_definition().civilian_exit
var NORTH_WAYPOINT: Vector2i:
	get: return mission_definition().civilian_routes["north"]
var SOUTH_WAYPOINT: Vector2i:
	get: return mission_definition().civilian_routes["south"]
const EXIT_ORDER_RECT := Rect2(876, 510, 248, 40)
const FOLLOW_RECT := Rect2(876, 558, 248, 40)
const NORTH_RECT := Rect2(876, 654, 120, 36)
const SOUTH_RECT := Rect2(1004, 654, 120, 36)
const HOLD_RECT := Rect2(876, 606, 248, 40)
const CLOSE_RECT := Rect2(876, 936, 248, 44)
const CANCEL_RECT := Rect2(876, 988, 248, 36)
var cohorts: Array[Dictionary] = [
	{"id": "A", "cell": Vector2i.ZERO, "hp": 4, "order": "hold", "passed": false, "status": "active", "note": "Holding", "manifest": ["A-01","A-02","A-03","A-04"]},
	{"id": "B", "cell": Vector2i.ZERO, "hp": 4, "order": "hold", "passed": false, "status": "active", "note": "Holding", "manifest": ["B-01","B-02","B-03","B-04"]},
	{"id": "C", "cell": Vector2i.ZERO, "hp": 4, "order": "hold", "passed": false, "status": "active", "note": "Holding", "manifest": ["C-01","C-02","C-03","C-04"]}
]
var cohort_selected := 0
var order_used := false
var ended := false
var end_reason := ""
var close_pending := false
var last_civilian_phase := 0

func _ready() -> void:
	super._ready()
	evacuation_rules = EvacuationRules.new(civilian_safe, civilian_waypoint, civilian_exit,
		route_available, soldier_can_act, on_civilian_step)
	for index in range(cohorts.size()):
		cohorts[index]["cell"] = mission_definition().civilian_spawns[index]
	for soldier in soldiers:
		soldier["left_behind"] = false
	status_text = "Order one group each player phase. Machine → civilians → closure."
	save_feedback = "B2 save slot. Cohort manifest IDs are placeholders for named civilians."

func deadline() -> int:
	return MissionObjectives.deadline(mission_definition(),machine["collected_round"])

func remaining_civilians() -> int:
	var count := 0
	for cohort in cohorts:
		if cohort["status"] == "active":
			count += 4
	return count

func civilian_waypoint(order: String) -> Vector2i:
	return NORTH_WAYPOINT if order == "north" else SOUTH_WAYPOINT

func order_cohort(index: int, order: String) -> bool:
	close_pending = false
	if ended or order_used or index < 0 or index >= 3 or cohorts[index]["status"] != "active" or not ["hold", "north", "south", "follow"].has(order):
		status_text = "Order unavailable: one free group order per player phase."
		queue_redraw()
		return false
	if order == "follow" and not soldier_can_act(active_soldier):
		status_text = "Select a standing soldier on the map, then choose Follow Soldier."
		queue_redraw()
		return false
	cohorts[index]["leader"] = active_soldier if order == "follow" else -1
	cohorts[index]["order"] = order
	cohorts[index]["passed"] = cohorts[index]["cell"] == civilian_waypoint(order)
	cohorts[index]["note"] = "Waiting for your order" if order == "hold" else "Moves after End turn [N]"
	order_used = true
	status_text = "Group %s: %s. End turn [N] to move; this order stays active." % [cohorts[index]["id"], cohort_order_label(cohorts[index])]
	queue_redraw()
	return true

func route_label(order: String) -> String:
	return "Upper route" if order == "north" else "Lower route"

func route_available(_order: String) -> bool:
	return true

func route_preview(cohort: Dictionary, order: String) -> Array[Vector2i]:
	return evacuation_rules.route_preview(cohort, order, soldiers)

func order_exit(index: int) -> bool:
	if index < 0 or index >= cohorts.size(): return false
	var best := evacuation_rules.best_exit_route(cohorts[index], soldiers)
	if best == "":
		status_text = "No safe route to exit right now. Clear the marked hazard, then try again."
		queue_redraw()
		return false
	return order_cohort(index, best)

func cohort_order_label(cohort: Dictionary) -> String:
	if cohort["order"] == "hold": return "HOLD — needs an order"
	if cohort["order"] == "follow":
		var leader: int = cohort.get("leader", -1)
		return "Follow " + (soldiers[leader]["name"] if leader >= 0 and leader < soldiers.size() else "missing leader")
	return "To EXIT / " + route_label(cohort["order"])

func follow_path(cohort: Dictionary) -> Array[Vector2i]:
	return evacuation_rules.follow_path(cohort, soldiers)

func follow_wait_reason(cohort: Dictionary) -> String:
	return evacuation_rules.follow_wait_reason(cohort, soldiers)

func civilian_safe(cell: Vector2i) -> bool:
	return cell_is_in_bounds(cell) and not WALL_CELLS.has(cell) and not FIXTURES.has(cell) and target_at(cell) < 0 and cell != next_machine_cell() and cell != machine["pending_shot"]

func civilian_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return evacuation_rules.civilian_path(start, goal)

func on_civilian_step(_cohort: Dictionary, _cell: Vector2i) -> void:
	pass

func civilian_exit() -> Vector2i:
	return EXIT_CELL

func resolve_civilian_phase() -> void:
	if ended or last_civilian_phase == phase:
		return
	last_civilian_phase = phase
	for cohort in cohorts:
		move_cohort(cohort,3)

func move_cohort(cohort: Dictionary, budget: int) -> void:
	evacuation_rules.move_cohort(cohort, budget, soldiers)

func cell_occupied_by_people(cell: Vector2i) -> bool:
	if super.cell_occupied_by_people(cell):
		return true
	for cohort in cohorts:
		if cohort["status"] == "active" and cohort["cell"] == cell:
			return true
	return false

func damage_cell(cell: Vector2i, amount: int) -> String:
	var report := super.damage_cell(cell, amount)
	for cohort in cohorts:
		if cohort["status"] == "active" and cohort["cell"] == cell:
			cohort["hp"] = maxi(0, cohort["hp"] - amount)
			if cohort["hp"] == 0:
				cohort["status"] = "stranded"
				cohort["note"] = "Dispersed; four stranded"
			report += "; group %s -%d HP" % [cohort["id"], amount]
	return report

func finish_operation(reason: String) -> void:
	if ended:
		return
	ended = true
	end_reason = reason
	close_pending = false
	for cohort in cohorts:
		if cohort["status"] == "active":
			cohort["status"] = "stranded"
			cohort["note"] = "Road closed; four stranded" if reason == "Road closed" else "Four left stranded"
	for soldier in soldiers:
		if not soldier["extracted"]:
			soldier["left_behind"] = true
	active_soldier = -1
	selected_cell = NONE
	pinned_target = NONE
	status_text = reason + (". MSG not extracted: retry required." if not soldiers[0]["extracted"] else ". Dispositions recorded at right.")
	rebuild_movement()

func request_close() -> bool:
	if ended:
		return false
	if not soldiers[0]["extracted"]:
		status_text = "MSG must extract before you can close the operation early."
		queue_redraw()
		return false
	if not close_pending:
		close_pending = true
		queue_redraw()
		return false
	finish_operation("Operation closed early")
	return true

func next_phase() -> void:
	TurnResolution.resolve(phase, {
		"ended":func() -> bool: return ended,
		"before_machine":before_turn_resolution,
		"prepare_machine":prepare_machine_phase,
		"machine":resolve_enemy_turn,
		"civilians":resolve_civilian_phase,
		"completion":mission_completion_reason,
		"finish":finish_operation,
		"begin_player":begin_player_phase,
		"after_turn":after_turn_resolution,
	})

func before_turn_resolution() -> bool:
	return true

func prepare_machine_phase() -> void:
	close_pending = false

func after_turn_resolution() -> void:
	pass

func begin_player_phase() -> void:
	phase += 1
	order_used = false
	for index in range(soldiers.size()):
		if soldier_can_act(index):
			soldiers[index]["ap"] = 2
			soldiers[index]["attacked"] = false
	status_text = "Player phase %d: one free group order available." % phase
	if phase == 2:
		status_text = "Briefing: the buried feeder supplies occupied structures; their nature is unknown."
	elif phase == 3:
		status_text = "Briefing: external road closure confirmed at the end of round 10."
	rebuild_movement()

func fire_block_reason() -> String:
	return "Operation ended. Load a save or restart to retry." if ended else super.fire_block_reason()

func try_move(cell: Vector2i) -> bool:
	close_pending = false
	return false if ended else super.try_move(cell)

func try_reload() -> bool:
	close_pending = false
	return false if ended else super.try_reload()

func try_extract() -> bool:
	close_pending = false
	if ended:
		return false
	var success := super.try_extract()
	if success and all_extracted():
		status_text = "Squad extracted. %d civilians remain; continue turns or close operation." % remaining_civilians()
	return success

func encounter_snapshot() -> Dictionary:
	var result := super.encounter_snapshot()
	result["layout"] = "gdd3.1-b2-evac"
	result["evac"] = {"cohorts": cohorts.duplicate(true), "selected": cohort_selected,
		"order_used": order_used, "ended": ended, "reason": end_reason, "last_phase": last_civilian_phase}
	return result

func save_encounter(path: String = EVAC_SLOT) -> bool:
	if path == SaveStore.SAVE_PATH or path == FARM_SLOT:
		path = EVAC_SLOT
	var error := SaveStore.save(encounter_snapshot(), path)
	save_feedback = "B2 saved: orders, civilians, deadlines and hazards." if error == "" else error
	queue_redraw()
	return error == ""

func load_encounter(path: String = EVAC_SLOT) -> bool:
	if path == SaveStore.SAVE_PATH or path == FARM_SLOT:
		path = EVAC_SLOT
	var result := SaveStore.load_snapshot(path)
	if result["error"] != "" or result.get("snapshot", {}).get("layout") != "gdd3.1-b2-evac":
		save_feedback = result["error"] if result["error"] != "" else "Save belongs to an earlier encounter."
		queue_redraw()
		return false
	var snapshot: Dictionary = result["snapshot"]
	var evac: Dictionary = snapshot["evac"]
	cohorts.assign(evac["cohorts"].duplicate(true))
	cohort_selected = evac["selected"]
	order_used = evac["order_used"]
	ended = evac["ended"]
	end_reason = evac["reason"]
	last_civilian_phase = evac["last_phase"]
	close_pending = false
	machine = snapshot["machine"].duplicate(true)
	var ui: Dictionary = snapshot["ui"]
	active_soldier = ui["active"]
	restore_combat(snapshot["combat"])
	selected_cell = ui["selected"]
	pinned_target = ui["pinned"]
	sight_mode = ui["sight"]
	status_text = ui["status"]
	hovered_cell = NONE
	save_feedback = "B2 loaded: all civilian orders and closure state restored."
	queue_redraw()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if EXIT_ORDER_RECT.has_point(point):
			order_exit(cohort_selected)
			return
		if FOLLOW_RECT.has_point(point):
			order_cohort(cohort_selected, "follow")
			return
		var clicked_cell := local_to_cell(point)
		if soldier_at(clicked_cell) < 0 and not sight_mode:
			for index in range(3):
				if cohorts[index]["status"] == "active" and cohorts[index]["cell"] == clicked_cell:
					cohort_selected = index
					status_text = "Group %s selected. Choose Move to Exit or Follow Soldier at right." % cohorts[index]["id"]
					queue_redraw()
					return
		for index in range(3):
			if Rect2(876, 132 + index * 112, 248, 100).has_point(point):
				cohort_selected = index
				queue_redraw()
				return
		if NORTH_RECT.has_point(point):
			order_cohort(cohort_selected, "north")
			return
		if SOUTH_RECT.has_point(point):
			order_cohort(cohort_selected, "south")
			return
		if HOLD_RECT.has_point(point):
			order_cohort(cohort_selected, "hold")
			return
		if CLOSE_RECT.has_point(point):
			request_close()
			return
		if CANCEL_RECT.has_point(point):
			close_pending = false
			queue_redraw()
			return
	if ended:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_K:
				save_encounter()
			elif event.keycode == KEY_L:
				load_encounter()
		if event is InputEventMouseButton and event.pressed:
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			if SAVE_RECT.has_point(point):
				save_encounter()
			elif LOAD_RECT.has_point(point):
				load_encounter()
		return
	super._unhandled_input(event)

func _draw() -> void:
	super._draw()
	draw_rect(Rect2(35, 10, 790, 34), Color("0e1412"))
	draw_string(font, Vector2(40, 36), "HOLDFAST / B2 CIVILIAN EVACUATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e5e9e7"))
	draw_rect(Rect2(35,46,800,28),Color("0e1412"))
	draw_string(font,Vector2(40,66),"RESCUE A + B + C: choose a group → Move to EXIT → End turn [N].",HORIZONTAL_ALIGNMENT_LEFT,790,18,Color("8be6de"))
	for waypoint in [civilian_waypoint("north"), civilian_waypoint("south")]:
		draw_rect(Rect2(cell_to_local(waypoint) + Vector2(2,2), Vector2(32,32)), Color("aabbe5"), false, 2)
	var selected_group: Dictionary = cohorts[cohort_selected]
	if selected_group["status"] == "active":
		var route := route_preview(selected_group, selected_group["order"])
		var previous: Vector2i = selected_group["cell"]
		for step in route:
			var a := cell_to_local(previous) + Vector2(18,18)
			var b := cell_to_local(step) + Vector2(18,18)
			draw_line(a, b, Color("8be6de"), 3)
			draw_circle(b, 3, Color("8be6de"))
			previous = step
	var exit_origin := cell_to_local(civilian_exit())
	draw_rect(Rect2(exit_origin, Vector2(36,36)), Color("178675"))
	draw_rect(Rect2(exit_origin, Vector2(36,36)), Color.WHITE, false, 3)
	draw_string(font, exit_origin + Vector2(0,24), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, 36, 13, Color.WHITE)
	for index in range(3):
		var cohort: Dictionary = cohorts[index]
		if cohort["status"] == "active":
			if index == cohort_selected:
				draw_rect(Rect2(cell_to_local(cohort["cell"])+Vector2(1,1),Vector2(34,34)), Color("8be6de"), false, 3)

			# Corner badges remain distinguishable when groups share a cell or soldier.
			var offset := Vector2(2 + index * 11, 2)
			draw_rect(Rect2(cell_to_local(cohort["cell"]) + offset, Vector2(11,14)), Color("aabbe5"))
			draw_string(font, cell_to_local(cohort["cell"]) + offset + Vector2(0,11), cohort["id"], HORIZONTAL_ALIGNMENT_CENTER, 11, 11, Color("17202a"))
	draw_rect(Rect2(858, 86, 280, 1028), Color("18231f"))
	draw_string(font, Vector2(876, 115), "CIVILIANS / 12 PEOPLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
	for index in range(3):
		var cohort: Dictionary = cohorts[index]
		var origin := Vector2(876, 132 + index * 112)
		draw_rect(Rect2(origin, Vector2(248,100)), Color("34473e") if index == cohort_selected else Color("22312a"))
		draw_string(font, origin + Vector2(10,24), "%s | 4 people | HP %d/4" % [cohort["id"],cohort["hp"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		draw_string(font, origin + Vector2(10,47), cohort_order_label(cohort) if cohort["status"] == "active" else cohort["status"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("aabbe5"))
		draw_string(font, origin + Vector2(10,70), (follow_wait_reason(cohort) if cohort["status"] == "active" and cohort["order"] == "follow" and follow_path(cohort).is_empty() else ("Waiting for your order" if cohort["order"] == "hold" and cohort["status"] == "active" else cohort["note"])), HORIZONTAL_ALIGNMENT_LEFT, 230, 13, Color("d4dfd8"))
		draw_string(font, origin + Vector2(10,90), "%s through %s" % [cohort["manifest"][0],cohort["manifest"][3]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9eaea4"))
	draw_string(font, Vector2(876, 493), "Operation ended" if ended else ("Order spent this phase" if order_used else "One free group order available"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f7cd6c"))
	var leader_name: String = soldiers[active_soldier]["name"] if soldier_can_act(active_soldier) else "select soldier"
	for item in [[EXIT_ORDER_RECT,"Move to EXIT"],[FOLLOW_RECT,"Follow: " + leader_name],[HOLD_RECT,"Hold position"],[NORTH_RECT,route_label("north")],[SOUTH_RECT,route_label("south")]]:
		draw_rect(item[0], Color("343b38") if order_used or ended or (item[0] == NORTH_RECT and not route_available("north")) else Color("304965"))
		draw_string(font, item[0].position + Vector2(0,26), item[1], HORIZONTAL_ALIGNMENT_CENTER, item[0].size.x, 16, Color.WHITE)
	for line in [[714,"1. Select group A, B or C."],[736,"2. Move to EXIT, or follow a soldier."],[758,"3. End turn [N]: groups move 3 cells."],[780,"Orders persist. Order B/C next turns."]]:
		draw_string(font,Vector2(876,line[0]),line[1],HORIZONTAL_ALIGNMENT_LEFT,248,13,Color("d4dfd8"))
	draw_string(font,Vector2(876,807),"EXIT %s: automatic rescue" % civilian_exit(),HORIZONTAL_ALIGNMENT_LEFT,248,14,Color("8be6de"))
	draw_string(font,Vector2(876,831),"Road closes after round %d" % deadline(),HORIZONTAL_ALIGNMENT_LEFT,248,16,Color("f7cd6c"))
	var evacuated := 0
	var stranded := 0
	for cohort in cohorts:
		evacuated += 4 if cohort["status"] == "extracted" else 0
		stranded += 4 if cohort["status"] == "stranded" else 0
	draw_string(font, Vector2(876, 855), "Evacuated %d | Stranded %d" % [evacuated,stranded], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	var left := 0
	for soldier in soldiers:
		left += 0 if soldier["extracted"] else 1
	if ended:
		draw_string(font, Vector2(876, 878), end_reason, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f7cd6c"))
		draw_string(font, Vector2(876, 900), "Squad: %d out / %d left behind" % [4-left,left], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_string(font, Vector2(876, 922), "MSG missing: retry required" if not soldiers[0]["extracted"] else "MSG extracted", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f7cd6c"))
	elif close_pending:
		draw_string(font, Vector2(876, 878), "Close operation now?", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f7cd6c"))
		draw_string(font, Vector2(876, 900), "%d civilians will be stranded." % remaining_civilians(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		draw_string(font, Vector2(876, 922), "%d soldiers will be left behind." % left, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_rect(CLOSE_RECT, Color("713f36") if close_pending else Color("343b38"))
	draw_string(font, CLOSE_RECT.position + Vector2(0,28), "Confirm: leave them behind" if close_pending else "Close operation early", HORIZONTAL_ALIGNMENT_CENTER,248,15,Color.WHITE)
	if close_pending:
		draw_rect(CANCEL_RECT,Color("304965"))
		draw_string(font,CANCEL_RECT.position+Vector2(0,24),"Cancel",HORIZONTAL_ALIGNMENT_CENTER,248,15,Color.WHITE)
	draw_rect(Rect2(35,1070,800,47),Color("0e1412"))
	var forecast := str(machine["collected_round"] + 1) if machine["collected_round"] > 0 else (str(phase + 4 - machine["stage"]) if machine_present() else "none")
	draw_string(font,Vector2(40,1088),"External closure 10 | Machine forecast %s | Current deadline %d" % [forecast,deadline()],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))
	draw_string(font,Vector2(40,1109),save_feedback,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))

func mission_completion_reason(round_number: int) -> String:
	return MissionObjectives.completion_reason(mission_definition(),round_number,
		machine["collected_round"],all_extracted(),remaining_civilians())
