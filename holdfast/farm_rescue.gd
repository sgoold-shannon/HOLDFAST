extends "res://farm_protocol.gd"
const RescuePanel = preload("res://presentation/rescue_panel.gd")
## B5 casualty rules; critical_epoch is the round in which the wound occurred.
const RESCUE_SLOT := "user://holdfast_b5.save"
const CASUALTY_RECT := Rect2(876,1032,248,32)
const STABILIZE_RECT := Rect2(876,1072,248,34)
const PICKUP_RECT := Rect2(876,1114,248,34)
const DROP_RECT := Rect2(876,1156,248,34)
var rescue_target := -1
var drop_mode := false

func _ready() -> void:
	super._ready()
	initialize_rescue()

func initialize_rescue() -> void:
	for index in range(soldiers.size()):
		soldiers[index].merge({"condition":"active","bleed":0,"critical_epoch":0,
			"medical":2 if index == 1 else 0,"carrying":-1,"carried_by":-1})
	status_text = "Rescue: select a rescuer, then click a casualty. S stabilize, U pick up, J put down."
	save_feedback = "B5 save slot. V cycles casualties. Critical timer counts three subsequent player phases."

func soldier_can_act(index: int) -> bool:
	return super.soldier_can_act(index) and soldiers[index].get("condition","active") == "active" and soldiers[index].get("carried_by",-1) == -1

func soldier_visible(index: int) -> bool:
	return not soldiers[index]["extracted"] and soldiers[index].get("carried_by",-1) == -1

func soldier_at(cell: Vector2i) -> int:
	for index in range(soldiers.size()):
		if soldier_visible(index) and soldiers[index].get("condition","active") != "dead" and soldiers[index]["cell"] == cell:
			return index
	return -1

func is_walkable(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell) or target_at(cell) >= 0:
		return false
	for index in range(soldiers.size()):
		if soldier_visible(index) and ["critical","stable"].has(soldiers[index].get("condition","active")) and soldiers[index]["cell"] == cell:
			return false
	return true

func all_extracted() -> bool:
	for soldier in soldiers:
		if not soldier["extracted"] and soldier.get("condition","active") != "dead":
			return false
	return true

func kill_soldier(index: int) -> void:
	var soldier: Dictionary = soldiers[index]
	soldier["condition"] = "dead"
	soldier["ap"] = 0
	soldier["bleed"] = 0
	var passenger: int = soldier["carrying"]
	if passenger >= 0:
		soldiers[passenger]["carried_by"] = -1
		soldier["carrying"] = -1
	var host: int = soldier["carried_by"]
	if host >= 0:
		soldiers[host]["carrying"] = -1
		soldier["carried_by"] = -1
	if active_soldier == index:
		active_soldier = -1
		selected_cell = NONE

func damage_cell(cell: Vector2i, amount: int) -> String:
	return apply_casualty_damage(cell,amount)

func apply_casualty_damage(cell: Vector2i, amount: int) -> String:
	var reports: Array[String] = []
	for index in range(soldiers.size()):
		var soldier: Dictionary = soldiers[index]
		if soldier["extracted"] or soldier["condition"] == "dead" or soldier["cell"] != cell:
			continue
		var new_hp: int = soldier["hp"] - amount
		soldier["hp"] = maxi(-4,new_hp)
		if new_hp <= -4:
			kill_soldier(index)
		elif new_hp <= 0:
			if soldier["condition"] != "critical":
				soldier["bleed"] = 3
				soldier["critical_epoch"] = phase
			soldier["condition"] = "critical"
			soldier["ap"] = 0
			if active_soldier == index:
				active_soldier = -1
				selected_cell = NONE
		reports.append("%s -%d HP (%s)" % [soldier["name"],amount,soldier["condition"]])
	for cohort in cohorts:
		if cohort["status"] == "active" and cohort["cell"] == cell:
			cohort["hp"] = maxi(0,cohort["hp"]-amount)
			if cohort["hp"] == 0:
				cohort["status"] = "stranded"
				cohort["note"] = "Dispersed; four stranded"
			reports.append("group %s -%d HP" % [cohort["id"],amount])
	if soldiers[0]["condition"] == "dead" and not ended:
		finish_operation("MSG killed: retry required")
	return "empty cell" if reports.is_empty() else "; ".join(reports)

func before_turn_resolution() -> bool:
	drop_mode = false
	for index in range(soldiers.size()):
		var soldier: Dictionary = soldiers[index]
		if soldier["condition"] == "critical" and not soldier["extracted"] and phase > soldier["critical_epoch"]:
			soldier["bleed"] -= 1
			if soldier["bleed"] == 0:
				kill_soldier(index)
	if soldiers[0]["condition"] == "dead":
		finish_operation("MSG bled out: retry required")
		return false
	return super.before_turn_resolution()

func casualty_available(index: int) -> bool:
	return index >= 0 and index < soldiers.size() and not soldiers[index]["extracted"] and ["critical","stable"].has(soldiers[index]["condition"])

func casualty_in_reach(index: int) -> bool:
	if not soldier_can_act(active_soldier) or not casualty_available(index):
		return false
	if soldiers[active_soldier]["carrying"] == index:
		return true
	var delta: Vector2i = soldiers[active_soldier]["cell"] - soldiers[index]["cell"]
	return absi(delta.x)+absi(delta.y) == 1

func target_for_rescue() -> int:
	if active_soldier >= 0 and soldiers[active_soldier]["carrying"] >= 0:
		return soldiers[active_soldier]["carrying"]
	return rescue_target

func try_stabilize() -> bool:
	return stabilize_casualty()

func stabilize_casualty() -> bool:
	var target := target_for_rescue()
	if ended or not casualty_in_reach(target) or soldiers[active_soldier]["ap"] < 1:
		status_text = "Stabilize: select a rescuer with 1 AP and an adjacent or carried casualty."
	elif soldiers[target]["condition"] != "critical":
		status_text = "Casualty already stable."
	elif soldiers[active_soldier]["medical"] < 1:
		status_text = "No medical charges. The deployed medic starts with two."
	else:
		soldiers[active_soldier]["ap"] -= 1
		soldiers[active_soldier]["medical"] -= 1
		soldiers[target]["hp"] = 1
		soldiers[target]["condition"] = "stable"
		soldiers[target]["bleed"] = 0
		status_text = "%s stabilized %s: 1 HP, bleeding stopped, still incapacitated." % [soldiers[active_soldier]["name"],soldiers[target]["name"]]
		rebuild_movement()
		return true
	queue_redraw()
	return false

func try_pickup() -> bool:
	return pick_up_casualty()

func pick_up_casualty() -> bool:
	var target := rescue_target
	if ended or not casualty_in_reach(target) or soldiers[active_soldier]["ap"] < 1:
		status_text = "Pick up: select a rescuer with 1 AP and an adjacent casualty."
	elif soldiers[active_soldier]["carrying"] >= 0:
		status_text = "Already carrying a casualty."
	elif soldiers[target]["carrying"] >= 0:
		status_text = "This fallen carrier has a casualty. Rescue their passenger first (V cycles)."
	elif soldiers[target]["carried_by"] >= 0 and soldier_can_act(soldiers[target]["carried_by"]):
		status_text = "Another active soldier is carrying this casualty. Put them down first."
	else:
		var old_host: int = soldiers[target]["carried_by"]
		if old_host >= 0:
			soldiers[old_host]["carrying"] = -1
		soldiers[active_soldier]["ap"] -= 1
		soldiers[active_soldier]["carrying"] = target
		soldiers[target]["carried_by"] = active_soldier
		soldiers[target]["cell"] = soldiers[active_soldier]["cell"]
		status_text = "%s picked up %s. Move ≤2 squares; no firing or machinery." % [soldiers[active_soldier]["name"],soldiers[target]["name"]]
		rebuild_movement()
		return true
	queue_redraw()
	return false

func request_drop() -> void:
	if ended or not soldier_can_act(active_soldier) or soldiers[active_soldier]["carrying"] < 0 or soldiers[active_soldier]["ap"] < 1:
		status_text = "Put down requires a carrier with 1 AP."
	else:
		drop_mode = true
		status_text = "Click a free adjacent cell to put down the casualty. Esc cancels."
	queue_redraw()

func try_drop(cell: Vector2i) -> bool:
	if ended or not soldier_can_act(active_soldier) or soldiers[active_soldier]["carrying"] < 0 or soldiers[active_soldier]["ap"] < 1:
		return false
	var delta: Vector2i = cell - soldiers[active_soldier]["cell"]
	if absi(delta.x)+absi(delta.y) != 1 or not is_walkable(cell) or soldier_at(cell) >= 0 or cell_occupied_by_people(cell):
		status_text = "Choose a free adjacent ground cell."
		queue_redraw()
		return false
	var target: int = soldiers[active_soldier]["carrying"]
	soldiers[active_soldier]["ap"] -= 1
	soldiers[active_soldier]["carrying"] = -1
	soldiers[target]["carried_by"] = -1
	soldiers[target]["cell"] = cell
	drop_mode = false
	status_text = "%s put down at (%d,%d) for 1 AP." % [soldiers[target]["name"],cell.x,cell.y]
	rebuild_movement()
	return true

func rebuild_movement() -> void:
	super.rebuild_movement()
	if soldier_can_act(active_soldier) and soldiers[active_soldier].get("carrying",-1) >= 0:
		for cell in distances.keys():
			if distances[cell] > 2:
				distances.erase(cell)
	queue_redraw()

func try_move(cell: Vector2i) -> bool:
	var index := active_soldier
	var success := super.try_move(cell)
	if success and soldiers[index]["carrying"] >= 0:
		soldiers[soldiers[index]["carrying"]]["cell"] = cell
	return success

func fire_block_reason() -> String:
	if soldier_can_act(active_soldier) and soldiers[active_soldier].get("carrying",-1) >= 0:
		return "Cannot fire while carrying a casualty."
	return super.fire_block_reason()

func breaker_reason() -> String:
	if soldier_can_act(active_soldier) and soldiers[active_soldier].get("carrying",-1) >= 0:
		return "Cannot operate the breaker while carrying."
	return super.breaker_reason()

func protocol_reason(action: String) -> String:
	if ["authenticate","divert"].has(action) and soldier_can_act(active_soldier) and soldiers[active_soldier].get("carrying",-1) >= 0:
		return "Cannot operate the console while carrying."
	return super.protocol_reason(action)

func try_extract() -> bool:
	var index := active_soldier
	var passenger: int = soldiers[index]["carrying"] if index >= 0 else -1
	var success := super.try_extract()
	if success and passenger >= 0:
		soldiers[passenger]["extracted"] = true
		soldiers[passenger]["carried_by"] = -1
		soldiers[index]["carrying"] = -1
		status_text = "%s and %s extracted together for 1 AP." % [soldiers[index]["name"],soldiers[passenger]["name"]]
	return success

func finish_operation(reason: String) -> void:
	super.finish_operation(reason)
	close_rescue()

func close_rescue() -> void:
	for soldier in soldiers:
		if soldier.get("condition","active") == "dead":
			soldier["left_behind"] = false
	drop_mode = false

func cycle_casualty() -> void:
	for offset in range(1,5):
		var index := (rescue_target+offset) % 4
		if casualty_available(index):
			rescue_target = index
			queue_redraw()
			return
	rescue_target = -1
	queue_redraw()

func rescue_layout() -> String:
	return "gdd3.1-b5-rescue"

func rescue_slot() -> String:
	return RESCUE_SLOT

func restore_extra_snapshot(_snapshot: Dictionary) -> void:
	pass

func encounter_snapshot() -> Dictionary:
	var result := super.encounter_snapshot()
	result["layout"] = rescue_layout()
	result["rescue_target"] = rescue_target
	return result

func save_encounter(path: String = RESCUE_SLOT) -> bool:
	if [SaveStore.SAVE_PATH,FARM_SLOT,EVAC_SLOT,OPTIONS_SLOT,PROTOCOL_SLOT,RESCUE_SLOT].has(path):
		path = rescue_slot()
	var error := Persistence.write(encounter_snapshot(),path)
	save_feedback = "B5 saved: wounds, timers, medical charges and carried casualties." if error == "" else error
	queue_redraw()
	return error == ""

func load_encounter(path: String = RESCUE_SLOT) -> bool:
	if [SaveStore.SAVE_PATH,FARM_SLOT,EVAC_SLOT,OPTIONS_SLOT,PROTOCOL_SLOT,RESCUE_SLOT].has(path):
		path = rescue_slot()
	var error := Persistence.restore(path,rescue_layout(),"Save belongs to another encounter.",apply_loaded_encounter)
	if error != "":
		save_feedback = error
		queue_redraw()
		return false
	save_feedback = "B5 loaded: casualty timers and carrier links restored."
	queue_redraw()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not handle_rescue_input(event): super._unhandled_input(event)

func handle_rescue_input(event: InputEvent) -> bool:
	if isolate_pending:
		return false
	if drop_mode:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			drop_mode = false
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
			try_drop(local_to_cell(point))
		queue_redraw()
		return true
	var action := interaction_command(event,
		{KEY_S:"stabilize",KEY_U:"pickup",KEY_J:"drop",KEY_V:"cycle"},
		{"cycle":CASUALTY_RECT,"stabilize":STABILIZE_RECT,"pickup":PICKUP_RECT,"drop":DROP_RECT})
	match action:
		"stabilize": try_stabilize()
		"pickup": try_pickup()
		"drop": request_drop()
		"cycle": cycle_casualty()
	if action != "": return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
		var index := soldier_at(local_to_cell(point))
		if casualty_available(index) and not ended:
			rescue_target = index
			status_text = "%s selected for rescue. Choose an adjacent rescuer, then S or U." % soldiers[index]["name"]
			queue_redraw()
			return true
	return false

func _draw() -> void:
	super._draw()
	draw_rescue_layer()

func draw_rescue_layer() -> void:
	RescuePanel.render(self,font,board_projection,rescue_panel_snapshot())

func rescue_panel_snapshot() -> Dictionary:
	var visible := []
	for index in range(soldiers.size()): visible.append(soldier_visible(index))
	var target := target_for_rescue()
	return {
		"active_soldier":active_soldier,
		"close_pending":close_pending,
		"ended":ended,
		"CASUALTY_RECT":CASUALTY_RECT,
		"STABILIZE_RECT":STABILIZE_RECT,
		"PICKUP_RECT":PICKUP_RECT,
		"DROP_RECT":DROP_RECT,
		"soldiers":soldiers.duplicate(true),
		"visible":visible,
		"target":target,
		"target_available":casualty_available(target),
		"can_act":soldier_can_act(active_soldier)}

func apply_loaded_encounter(snapshot: Dictionary) -> void:
	EncounterRestore.apply(snapshot,{"extra":restore_extra_snapshot,"rescue":restore_rescue_section,"protocol":restore_protocol_section,"breaker":restore_breaker_section,"evac":restore_evac_section,"machine":restore_machine_section,"tactical":restore_tactical_section})

func restore_rescue_section(snapshot: Dictionary) -> void:
	rescue_target = snapshot["rescue_target"]
	drop_mode = false
