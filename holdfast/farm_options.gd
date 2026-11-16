extends "res://farm_evac.gd"
const BreakerPanel = preload("res://presentation/breaker_panel.gd")
## B3: persistent two-action breaker and explicit destroy/disable consequences.
const OPTIONS_SLOT := "user://holdfast_b3.save"
var BREAKER_CELL: Vector2i:
	get: return mission_definition().breaker_cell
var GATES: Array[Vector2i]:
	get: return mission_definition().gates
const BREAKER_RECT := Rect2(40, 773, 250, 48)
const CONFIRM_RECT := Rect2(160, 490, 260, 46)
const ABORT_RECT := Rect2(440, 490, 260, 46)
var breaker_progress: int:
	get: return machine_state.breaker_progress
	set(value): machine_state.breaker_progress = value
var isolate_pending := false

func _ready() -> void:
	super._ready()
	initialize_breaker()

func initialize_breaker() -> void:
	status_text = "Breaker (9,4): stand adjacent, then I to open for 1 AP. I again previews isolation."
	save_feedback = "B3 save slot. Destroy: blast + lost cooling. Disable: locked civilian gates."

func disabled() -> bool:
	return breaker_progress == 2

func breaker_reason() -> String:
	return origin_breaker_reason()

func origin_breaker_reason() -> String:
	if ended:
		return "Operation ended."
	if not machine_present():
		return "Machine destroyed or departed; breaker unavailable."
	if disabled():
		return "Drive already isolated."
	if not soldier_can_act(active_soldier):
		return "Select an active soldier."
	var delta: Vector2i = soldiers[active_soldier]["cell"] - BREAKER_CELL
	if absi(delta.x) + absi(delta.y) != 1:
		return "Stand adjacent to breaker (9,4)."
	if soldiers[active_soldier]["ap"] < 1:
		return "Breaker action needs 1 AP."
	return ""

func try_breaker(confirm: bool = false) -> bool:
	return operate_origin_breaker(confirm)

func operate_origin_breaker(confirm: bool = false) -> bool:
	var reason := breaker_reason()
	if reason != "":
		status_text = reason
		isolate_pending = false
		queue_redraw()
		return false
	close_pending = false
	if breaker_progress == 0:
		soldiers[active_soldier]["ap"] -= 1
		breaker_progress = 1
		status_text = "%s opened the breaker for 1 AP. Housing stays open." % soldiers[active_soldier]["name"]
		rebuild_movement()
		return true
	if not confirm or not isolate_pending:
		isolate_pending = true
		queue_redraw()
		return false
	soldiers[active_soldier]["ap"] -= 1
	breaker_progress = 2
	isolate_pending = false
	machine["pending_shot"] = NONE
	for cohort in cohorts:
		if cohort["status"] == "active" and cohort["order"] in ["north", "south"] and not cohort["passed"]:
			cohort["passed"] = cohort["cell"] == civilian_waypoint(cohort["order"])
			cohort["note"] = "Using confirmed bypass"
	status_text = "Drive isolated for 1 AP. Machine stopped; civilian gates locked; bypasses applied."
	enemy_message = "Feeder unpowered. Machine retained for later repair."
	rebuild_movement()
	return true




func enemy_intent() -> String:
	return "DISABLED | No movement or shot | Feeder unpowered" if disabled() and machine_present() else super.enemy_intent()

func civilian_waypoint(order: String) -> Vector2i:
	if disabled():
		return mission_definition().disabled_routes["north" if order == "north" else "south"]
	return super.civilian_waypoint(order)

func civilian_safe(cell: Vector2i) -> bool:
	return not (disabled() and GATES.has(cell)) and super.civilian_safe(cell)

func blast_victims() -> String:
	var names: Array[String] = []
	for soldier in soldiers:
		var delta: Vector2i = soldier["cell"] - enemies[0]["cell"]
		if not soldier["extracted"] and absi(delta.x) + absi(delta.y) <= 1:
			names.append(soldier["name"])
	for cohort in cohorts:
		var delta: Vector2i = cohort["cell"] - enemies[0]["cell"]
		if cohort["status"] == "active" and absi(delta.x) + absi(delta.y) <= 1:
			names.append("group " + cohort["id"])
	return "none" if names.is_empty() else ", ".join(names)

func machine_outcome() -> String:
	if enemies[0]["hp"] <= 0:
		return "Destroyed | cooling lost | " + ("skid recoverable" if machine["collected_round"] == 0 else "collected skid not restored")
	if disabled():
		return "Disabled: machine retained; feeder outage; civilian gates locked."
	if machine["departed"]:
		return "Departed unresolved: machine and cooling unit unavailable."
	return "Active: no intervention completed."

func encounter_snapshot() -> Dictionary:
	var result := super.encounter_snapshot()
	result["layout"] = "gdd3.1-b3-options"
	result["breaker"] = breaker_progress
	return result

func save_encounter(path: String = OPTIONS_SLOT) -> bool:
	if [SaveStore.SAVE_PATH,FARM_SLOT,EVAC_SLOT].has(path):
		path = OPTIONS_SLOT
	var error := Persistence.write(encounter_snapshot(),path)
	save_feedback = "B3 saved, including breaker progress and civilian bypasses." if error == "" else error
	queue_redraw()
	return error == ""

func load_encounter(path: String = OPTIONS_SLOT) -> bool:
	if [SaveStore.SAVE_PATH,FARM_SLOT,EVAC_SLOT].has(path):
		path = OPTIONS_SLOT
	var error := Persistence.restore(path,"gdd3.1-b3-options","Save belongs to an earlier encounter.",apply_loaded_encounter)
	if error != "":
		save_feedback = error
		queue_redraw()
		return false
	save_feedback = "B3 loaded: breaker, gates, hazards and civilian routes restored."
	queue_redraw()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not handle_breaker_input(event): super._unhandled_input(event)

func handle_breaker_input(event: InputEvent) -> bool:
	if isolate_pending:
		var action := interaction_command(event,{KEY_I:"confirm",KEY_ESCAPE:"cancel"},{"confirm":CONFIRM_RECT,"cancel":ABORT_RECT})
		if action == "confirm": try_breaker(true)
		elif action == "cancel": isolate_pending = false
		queue_redraw()
		return true
	var buttons := {} if sight_mode else {"breaker":BREAKER_RECT}
	if interaction_command(event,{KEY_I:"breaker"},buttons) == "breaker":
		try_breaker()
		return true
	return false

func _draw() -> void:
	super._draw()
	draw_breaker_layer()

func draw_breaker_layer() -> void:
	BreakerPanel.render(self,font,board_projection,breaker_panel_snapshot())

func machine_plan() -> Dictionary:
	var plan := super.machine_plan()
	plan["disabled"] = disabled()
	return plan

func breaker_panel_snapshot() -> Dictionary:
	return {
		"sight_mode":sight_mode,
		"breaker_progress":breaker_progress,
		"pinned_target":pinned_target,
		"isolate_pending":isolate_pending,
		"BREAKER_RECT":BREAKER_RECT,
		"CONFIRM_RECT":CONFIRM_RECT,
		"ABORT_RECT":ABORT_RECT,
		"save_feedback":save_feedback,
		"GATES":GATES.duplicate(),
		"enemies":enemies.duplicate(true),
		"disabled":disabled(),
		"reason":breaker_reason(),
		"present":machine_present(),
		"victims":blast_victims(),
		"outcome":machine_outcome(),
		"deadline":deadline()}

func apply_loaded_encounter(snapshot: Dictionary) -> void:
	EncounterRestore.apply(snapshot,{"breaker":restore_breaker_section,"evac":restore_evac_section,"machine":restore_machine_section,"tactical":restore_tactical_section})

func restore_breaker_section(snapshot: Dictionary) -> void:
	breaker_progress = snapshot["breaker"]
	isolate_pending = false
