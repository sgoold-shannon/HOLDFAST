extends RefCounted
## Isolated practice encounter. Commands delegate to production rules; no save/load calls.
const Encounter = preload("res://presentation3d/practice_encounter.gd")
var encounter: Node2D
var initial: Dictionary

func setup(parent: Node) -> void:
	encounter = Encounter.new()
	encounter.auto_resume = false
	parent.add_child(encounter)
	encounter.hide()
	encounter.set_process_unhandled_input(false)
	encounter.process_mode = Node.PROCESS_MODE_DISABLED
	encounter.finish_opening()
	initial = encounter.encounter_snapshot()

func select(index: int) -> void:
	if encounter.casualty_available(index):
		encounter.rescue_target = index
	else:
		encounter.select_soldier(index)

func move(cell: Vector2i) -> bool:
	return encounter.try_move(cell)

func command(action: String, group: int = 0) -> void:
	if encounter.ended: return
	match action:
		"target":
			encounter.sight_mode = true
			encounter.pinned_target = encounter.enemies[0]["cell"] if encounter.machine_present() else encounter.NONE
		"fire": encounter.try_fire()
		"reload": encounter.try_reload()
		"stabilize": encounter.try_stabilize()
		"pickup": encounter.try_pickup()
		"drop": encounter.request_drop()
		"cancel_drop": encounter.drop_mode = false
		"turn": encounter.next_phase()
		"extract": encounter.try_extract()
		"exit": encounter.order_exit(group)
		"hold", "follow", "north", "south": encounter.order_cohort(group,action)

func reset() -> void:
	encounter.apply_loaded_encounter(initial.duplicate(true))

func actor_at(cell: Vector2i) -> int:
	return encounter.soldier_at(cell)

func view(hover: Vector2i = Vector2i(-1,-1)) -> Dictionary:
	var reachable := {}
	for cell in encounter.distances:
		var cost: int = encounter.move_cost(cell)
		if cost>0 and cost<=encounter.soldiers[encounter.active_soldier]["ap"]:
			reachable[cell] = cost
	var chance := -1
	if encounter.soldier_can_act(encounter.active_soldier) and encounter.target_at(encounter.pinned_target)>=0:
		var sight: Dictionary = encounter.sight_preview(encounter.soldiers[encounter.active_soldier]["cell"],encounter.pinned_target)
		if sight["clear"] and sight["can_fire"]: chance = clampi(75+sight["range_modifier"],5,95)
	return {"soldiers":encounter.soldiers.duplicate(true),"active":encounter.active_soldier,
		"reachable":reachable,"path":encounter.path_to(hover).duplicate(),
		"cost":reachable.get(hover,0),"status":encounter.status_text,
		"cohorts":encounter.cohorts.duplicate(true),"machine":encounter.machine_view_snapshot(),
		"intent":encounter.enemy_intent(),"phase":encounter.phase,"ended":encounter.ended,
		"reason":encounter.end_reason,"order_used":encounter.order_used,
		"rescue_target":encounter.target_for_rescue(),"drop_mode":encounter.drop_mode,
		"fire_reason":encounter.fire_block_reason(),"chance":chance,"target":encounter.pinned_target,
		"danger":encounter.danger_summary(),"deadline":encounter.deadline(),"evacuated":encounter.evacuated_people()}
