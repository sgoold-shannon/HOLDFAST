extends "res://farm_evac.gd"
## B3: persistent two-action breaker and explicit destroy/disable consequences.
const OPTIONS_SLOT := "user://holdfast_b3.save"
const BREAKER_CELL := Vector2i(9,4)
const GATES: Array[Vector2i] = [Vector2i(11,7),Vector2i(11,10)]
const BREAKER_RECT := Rect2(40, 773, 250, 48)
const CONFIRM_RECT := Rect2(160, 490, 260, 46)
const ABORT_RECT := Rect2(440, 490, 260, 46)
var breaker_progress := 0
var isolate_pending := false

func _ready() -> void:
	super._ready()
	status_text = "Breaker (9,4): stand adjacent, then I to open for 1 AP. I again previews isolation."
	save_feedback = "B3 save slot. Destroy: blast + lost cooling. Disable: locked civilian gates."

func disabled() -> bool:
	return breaker_progress == 2

func breaker_reason() -> String:
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
		return Vector2i(11,4) if order == "north" else Vector2i(11,11)
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
	var error := SaveStore.save(encounter_snapshot(),path)
	save_feedback = "B3 saved, including breaker progress and civilian bypasses." if error == "" else error
	queue_redraw()
	return error == ""

func load_encounter(path: String = OPTIONS_SLOT) -> bool:
	if [SaveStore.SAVE_PATH,FARM_SLOT,EVAC_SLOT].has(path):
		path = OPTIONS_SLOT
	var result := SaveStore.load_snapshot(path)
	if result["error"] != "" or result.get("snapshot",{}).get("layout") != "gdd3.1-b3-options":
		save_feedback = result["error"] if result["error"] != "" else "Save belongs to an earlier encounter."
		queue_redraw()
		return false
	var snapshot: Dictionary = result["snapshot"]
	breaker_progress = snapshot["breaker"]
	isolate_pending = false
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
	save_feedback = "B3 loaded: breaker, gates, hazards and civilian routes restored."
	queue_redraw()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if isolate_pending:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_I:
				try_breaker(true)
			elif event.keycode == KEY_ESCAPE:
				isolate_pending = false
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			if CONFIRM_RECT.has_point(point):
				try_breaker(true)
			elif ABORT_RECT.has_point(point):
				isolate_pending = false
		queue_redraw()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		try_breaker()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not sight_mode:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if BREAKER_RECT.has_point(point):
			try_breaker()
			return
	super._unhandled_input(event)

func _draw() -> void:
	super._draw()
	draw_rect(Rect2(35,10,790,34),Color("0e1412"))
	draw_string(font,Vector2(40,36),"HOLDFAST / B3 DESTROY OR DISABLE",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	if disabled():
		for gate in GATES:
			var origin := cell_to_local(gate)
			draw_rect(Rect2(origin+Vector2(2,2),Vector2(32,32)),Color("ea9670"),false,2)
			draw_string(font,origin+Vector2(0,24),"LOCK",HORIZONTAL_ALIGNMENT_CENTER,36,10,Color("ea9670"))
	if not sight_mode:
		draw_rect(BREAKER_RECT,Color("315b50") if breaker_reason() == "" else Color("343b38"))
		draw_string(font,BREAKER_RECT.position+Vector2(0,29),"Open breaker [I] · 1 AP" if breaker_progress == 0 else ("Preview isolation [I]" if breaker_progress == 1 else "Drive isolated"),HORIZONTAL_ALIGNMENT_CENTER,250,16,Color.WHITE)
		draw_string(font,Vector2(308,792),"Breaker (9,4): %d/2 steps" % breaker_progress,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f7cd6c"))
		draw_string(font,Vector2(308,816),breaker_reason() if breaker_reason() != "" else "Progress persists; any adjacent soldier may finish.",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))
	elif pinned_target == enemies[0]["cell"] and machine_present():
		draw_rect(Rect2(35,803,800,28),Color("0e1412"))
		draw_string(font,Vector2(40,821),"HP %d/16 | Destruction: 4 damage to %s. Cooling lost." % [enemies[0]["hp"], blast_victims()],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e6a2c7"))
	draw_rect(Rect2(35,1070,800,47),Color("0e1412"))
	draw_string(font,Vector2(40,1088),machine_outcome()+" Closure: round %d." % deadline(),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))
	draw_string(font,Vector2(40,1109),save_feedback,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))
	if isolate_pending:
		draw_rect(Rect2(110,240,640,320),Color("111b17"))
		draw_rect(Rect2(110,240,640,320),Color("f7cd6c"),false,2)
		var lines := ["ISOLATE DRIVE? 1 AP", "Stops the machine and clears its charged shot.", "Feeder loses power. Civilian gates (11,7) and (11,10) lock.", "North route: (11,7) → (11,4). South: (11,10) → (11,11).", "Existing groups still approaching their waypoint use the bypass.", "Soldiers retain manual access. Machine retained for later repair.", "A collected skid and an advanced deadline are NOT reversed."]
		for index in range(lines.size()):
			draw_string(font,Vector2(134,275+index*29),lines[index],HORIZONTAL_ALIGNMENT_LEFT,-1,18 if index == 0 else 15,Color("f7cd6c") if index == 0 else Color.WHITE)
		draw_rect(CONFIRM_RECT,Color("713f36"))
		draw_rect(ABORT_RECT,Color("304965"))
		draw_string(font,CONFIRM_RECT.position+Vector2(0,29),"Confirm isolate [I]",HORIZONTAL_ALIGNMENT_CENTER,260,16,Color.WHITE)
		draw_string(font,ABORT_RECT.position+Vector2(0,29),"Cancel [Esc]",HORIZONTAL_ALIGNMENT_CENTER,260,16,Color.WHITE)

func machine_plan() -> Dictionary:
	var plan := super.machine_plan()
	plan["disabled"] = disabled()
	return plan
