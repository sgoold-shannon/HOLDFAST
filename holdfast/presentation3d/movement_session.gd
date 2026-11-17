extends RefCounted
## Isolated practice encounter. Commands delegate to production rules; no save/load calls.
const Encounter = preload("res://encounter_controller.gd")
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
	encounter.select_soldier(index)

func move(cell: Vector2i) -> bool:
	return encounter.try_move(cell)

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
	return {"soldiers":encounter.soldiers.duplicate(true),"active":encounter.active_soldier,
		"reachable":reachable,"path":encounter.path_to(hover).duplicate(),
		"cost":reachable.get(hover,0),"status":encounter.status_text}
