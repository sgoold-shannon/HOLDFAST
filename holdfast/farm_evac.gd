extends "res://farm_road.gd"
const EvacuationState = preload("res://state/evacuation_state.gd")
var evacuation_state := EvacuationState.new()
const CivilianPanel = preload("res://presentation/civilian_panel.gd")
const CivilianView = preload("res://presentation/civilian_view.gd")
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
var cohorts: Array[Dictionary]:
	get: return evacuation_state.cohorts
	set(value): evacuation_state.cohorts = value
var cohort_selected := 0
var order_used: bool:
	get: return evacuation_state.order_used
	set(value): evacuation_state.order_used = value
var ended: bool:
	get: return evacuation_state.ended
	set(value): evacuation_state.ended = value
var end_reason: String:
	get: return evacuation_state.end_reason
	set(value): evacuation_state.end_reason = value
var close_pending := false
var last_civilian_phase: int:
	get: return evacuation_state.last_civilian_phase
	set(value): evacuation_state.last_civilian_phase = value

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
	result["evac"] = evac_state_snapshot()
	return result

func save_encounter(path: String = EVAC_SLOT) -> bool:
	if path == SaveStore.SAVE_PATH or path == FARM_SLOT:
		path = EVAC_SLOT
	var error := Persistence.write(encounter_snapshot(), path)
	save_feedback = "B2 saved: orders, civilians, deadlines and hazards." if error == "" else error
	queue_redraw()
	return error == ""

func load_encounter(path: String = EVAC_SLOT) -> bool:
	if path == SaveStore.SAVE_PATH or path == FARM_SLOT:
		path = EVAC_SLOT
	var error := Persistence.restore(path,"gdd3.1-b2-evac","Save belongs to an earlier encounter.",apply_loaded_encounter)
	if error != "":
		save_feedback = error
		queue_redraw()
		return false
	save_feedback = "B2 loaded: all civilian orders and closure state restored."
	queue_redraw()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		var action := interaction_command(event,{}, {"exit":EXIT_ORDER_RECT,"follow":FOLLOW_RECT})
		if action == "exit":
			order_exit(cohort_selected)
			return
		if action == "follow":
			order_cohort(cohort_selected,"follow")
			return
		var clicked_cell := local_to_cell(point)
		if soldier_at(clicked_cell) < 0 and not sight_mode:
			for index in range(3):
				if cohorts[index]["status"] == "active" and cohorts[index]["cell"] == clicked_cell:
					cohort_selected = index
					status_text = "Group %s selected. Choose Move to Exit or Follow Soldier at right." % cohorts[index]["id"]
					queue_redraw()
					return
		var rows := []
		for index in range(3): rows.append(Rect2(876,132+index*112,248,100))
		# Cards retain priority over the route/closure controls.
		action = interaction_command(event,{}, {},rows)
		if action.begins_with("row:"):
			cohort_selected = int(action.get_slice(":",1))
			queue_redraw()
			return
		action = interaction_command(event,{}, {"north":NORTH_RECT,"south":SOUTH_RECT,"hold":HOLD_RECT,"close":CLOSE_RECT,"cancel":CANCEL_RECT})
		if action in ["north","south","hold"]: order_cohort(cohort_selected,action)
		elif action == "close": request_close()
		elif action == "cancel":
			close_pending = false
			queue_redraw()
		if action != "": return
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
	draw_civilian_layer()

func draw_civilian_layer() -> void:
	SceneChrome.header(self,font,"HOLDFAST / B2 CIVILIAN EVACUATION",790,Color("e5e9e7"))
	SceneChrome.rescue_guide(self,font)
	CivilianView.render(self,font,board_projection,civilian_view_snapshot())
	CivilianPanel.render(self,font,board_projection,civilian_panel_snapshot())

func mission_completion_reason(round_number: int) -> String:
	return MissionObjectives.completion_reason(mission_definition(),round_number,
		machine["collected_round"],all_extracted(),remaining_civilians())

func civilian_view_snapshot() -> Dictionary:
	return {
		"cohorts":cohorts.duplicate(true),
		"cohort_selected":cohort_selected,
		"waypoints":[civilian_waypoint("north"),civilian_waypoint("south")],
		"route":route_preview(cohorts[cohort_selected],cohorts[cohort_selected]["order"]).duplicate() if cohorts[cohort_selected]["status"] == "active" else [],
		"exit":civilian_exit()}

func civilian_panel_snapshot() -> Dictionary:
	var labels := []
	var notes := []
	for cohort in cohorts:
		labels.append(cohort_order_label(cohort))
		notes.append(follow_wait_reason(cohort) if cohort["status"] == "active" and cohort["order"] == "follow" and follow_path(cohort).is_empty() else ("Waiting for your order" if cohort["order"] == "hold" and cohort["status"] == "active" else cohort["note"]))
	return {
		"cohort_selected":cohort_selected,
		"ended":ended,
		"order_used":order_used,
		"close_pending":close_pending,
		"end_reason":end_reason,
		"phase":phase,
		"save_feedback":save_feedback,
		"EXIT_ORDER_RECT":EXIT_ORDER_RECT,
		"FOLLOW_RECT":FOLLOW_RECT,
		"HOLD_RECT":HOLD_RECT,
		"NORTH_RECT":NORTH_RECT,
		"SOUTH_RECT":SOUTH_RECT,
		"CLOSE_RECT":CLOSE_RECT,
		"CANCEL_RECT":CANCEL_RECT,
		"cohorts":cohorts.duplicate(true),
		"soldiers":soldiers.duplicate(true),
		"machine":machine.duplicate(true),
		"labels":labels,
		"notes":notes,
		"leader":soldiers[active_soldier]["name"] if soldier_can_act(active_soldier) else "select soldier",
		"north_label":route_label("north"),
		"south_label":route_label("south"),
		"north_available":route_available("north"),
		"exit":civilian_exit(),
		"deadline":deadline(),
		"remaining":remaining_civilians(),
		"present":machine_present()}

func apply_loaded_encounter(snapshot: Dictionary) -> void:
	EncounterRestore.apply(snapshot,{"evac":restore_evac_section,"machine":restore_machine_section,"tactical":restore_tactical_section})

func evac_state_snapshot() -> Dictionary:
	return {"cohorts": cohorts.duplicate(true), "selected": cohort_selected,
		"order_used": order_used, "ended": ended, "reason": end_reason, "last_phase": last_civilian_phase}

func restore_evac_section(snapshot: Dictionary) -> void:
	var evac: Dictionary = snapshot["evac"]
	evacuation_state.restore(evac)
	cohort_selected = evac["selected"]
	close_pending = false
