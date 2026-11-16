extends "res://battlefield.gd"
const MachineState = preload("res://state/machine_state.gd")
var machine_state := MachineState.new()
const MachineStatus = preload("res://presentation/machine_status.gd")
const MachineView = preload("res://presentation/machine_view.gd")
## B1: route, occupied-cell impacts, and fixed-cell defensive shots.
const MachineActivation = preload("res://systems/machine_activation.gd")
var machine_behavior: MachineActivation
const FarmRoadMission = preload("res://missions/farm_road.tres")
const FARM_SLOT := "user://holdfast_b1.save"
var ROUTE: Array[Vector2i]:
	get: return mission_definition().machine_patrol
var FIXTURES: Array[Vector2i]:
	get: return mission_definition().fixtures
var machine: Dictionary:
	get: return machine_state.machine
	set(value): machine_state.machine = value

func _ready() -> void:
	super._ready()
	machine_behavior = MachineActivation.new(next_machine_cell, enemy_target, cell_occupied_by_people, damage_cell, machine_path)
	enemies.assign([{"cell": mission_definition().machine_spawn, "hp": mission_definition().machine_hp, "ammo": 4}])
	status_text = "Farm Road: neutral machine. Orange = next movement; red = charged shot."
	enemy_message = "Observed route: (10,8) → (9,8) → (8,8) → skid (7,8), then return."
	save_feedback = "B1 has its own save slot. Gate A scene and save remain available."

func machine_present() -> bool:
	return enemies[0]["hp"] > 0 and not machine["departed"]

func next_machine_cell() -> Vector2i:
	return machine_behavior.next_cell(machine,enemies[0],ROUTE,machine_plan())

func target_at(cell: Vector2i) -> int:
	return 0 if machine_present() and enemies[0]["cell"] == cell else -1

func is_walkable(cell: Vector2i) -> bool:
	return not FIXTURES.has(cell) and super.is_walkable(cell)

func enemy_target() -> int:
	return machine_behavior.nearest_target(machine,enemies[0],soldiers,machine_plan(),soldier_can_act,sight_preview)

func enemy_intent() -> String:
	if machine["departed"]:
		return "Machine departed unresolved."
	if not machine_present():
		return "Machine destroyed. Route and pending shot cleared."
	var next := next_machine_cell()
	var action := "collect skid" if machine["stage"] == 3 else ("depart" if machine["stage"] == 8 else "move to (%d,%d)" % [next.x, next.y])
	var shot: Vector2i = machine["pending_shot"]
	return "%s | Next: %s%s" % ["HOSTILE" if machine["hostile"] else "NEUTRAL", action, " | SHOT (%d,%d): 4 damage" % [shot.x, shot.y] if shot != NONE else ""]

func danger_summary() -> String:
	if not machine_present(): return "Machine gone. Civilian rescue still needs orders and End turn [N]."
	if next_machine_cell() == NONE and machine["pending_shot"] == NONE:
		return enemy_intent()
	if machine["pending_shot"] != NONE:
		return "DANGER: red X takes 4 damage next machine turn. Move off it before [N]."
	if machine["hostile"]:
		return "HOSTILE: charges after its move if a soldier is visible within 6 cells; fires next turn."
	return "NEUTRAL: orange cell takes 4 damage if occupied. Firing makes it hostile."

func cell_occupied_by_people(cell: Vector2i) -> bool:
	return soldier_at(cell) >= 0

func damage_cell(cell: Vector2i, amount: int) -> String:
	var index := soldier_at(cell)
	if index < 0:
		return "empty cell"
	soldiers[index]["hp"] = maxi(0, soldiers[index]["hp"] - amount)
	if soldiers[index]["hp"] == 0:
		soldiers[index]["ap"] = 0
		if active_soldier == index:
			active_soldier = -1
			selected_cell = NONE
	return "%s -%d HP" % [soldiers[index]["name"], amount]

func resolve_enemy_turn() -> void:
	if last_enemy_phase == phase: return
	last_enemy_phase = phase
	var outcome := machine_behavior.activate(machine,enemies[0],soldiers,phase,machine_plan())
	enemy_message = outcome["message"]
	if outcome["rebuild"]: rebuild_movement()

func fire_block_reason() -> String:
	var reason := super.fire_block_reason()
	return reason.replace("enemy (red E)", "machine (D)").replace("enemy", "machine")

func try_fire() -> bool:
	var reason := fire_block_reason()
	if reason != "":
		status_text = reason
		queue_redraw()
		return false
	var soldier: Dictionary = soldiers[active_soldier]
	var info := sight_preview(soldier["cell"], pinned_target)
	# The machine never receives low-cover protection.
	var chance := clampi(75 + info["range_modifier"], 5, 95)
	var before := shot_rng.state
	var roll := shot_rng.randi_range(1, 100)
	var damage := 4 if roll <= chance else 0
	soldier["ap"] -= 1
	soldier["ammo"] -= 1
	soldier["attacked"] = true
	machine["hostile"] = true
	enemies[0]["hp"] = maxi(0, enemies[0]["hp"] - damage)
	shot_history.append({"phase": phase, "soldier": active_soldier, "target": pinned_target,
		"chance": chance, "roll": roll, "damage": damage, "rng_before": before, "rng_after": shot_rng.state})
	status_text = "%s: %s (roll %d/%d%%), %d damage. Machine HP %d/16." % [soldier["name"], "HIT" if damage > 0 else "MISS", roll, chance, damage, enemies[0]["hp"]]
	if enemies[0]["hp"] == 0:
		machine["pending_shot"] = NONE
		for direction in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			damage_cell(enemies[0]["cell"] + direction, 4)
		status_text += " Blast: 4 damage nearby. Destroyed before any further response."
	rebuild_movement()
	return true

func encounter_snapshot() -> Dictionary:
	var snapshot := super.encounter_snapshot()
	snapshot["layout"] = "gdd3.1-b1-farm-road"
	snapshot["machine"] = machine.duplicate(true)
	return snapshot

func save_encounter(path: String = FARM_SLOT) -> bool:
	return super.save_encounter(FARM_SLOT if path == SaveStore.SAVE_PATH else path)

func load_encounter(path: String = FARM_SLOT) -> bool:
	path = FARM_SLOT if path == SaveStore.SAVE_PATH else path
	var error := Persistence.restore(path,"gdd3.1-b1-farm-road","This save belongs to Gate A. Open battlefield.tscn to load it.",apply_loaded_encounter)
	if error != "":
		save_feedback = error
		queue_redraw()
		return false
	save_feedback = "Loaded Farm Road phase %d, including pending hazards." % phase
	queue_redraw()
	return true

func machine_track() -> Array[Vector2i]:
	return mission_definition().machine_display_track

func skid_visible() -> bool:
	return machine["collected_round"] == 0

func _draw() -> void:
	super._draw()
	draw_machine_layer()

func draw_machine_layer() -> void:
	# Scene-specific title and footer replace the Gate A test labels.
	SceneChrome.header(self,font,"HOLDFAST / B1 FARM ROAD MACHINE",790,Color("e5e9e7"))
	MachineView.render(self,font,board_projection,machine_view_snapshot())
	MachineStatus.render(self,font,board_projection,machine_status_snapshot())

func draw_targets() -> void:
	pass # Farm Road draws its machine after hazard overlays.

func machine_plan() -> Dictionary:
	return {"collect_stage":mission_definition().machine_collect_stage,"depart_stage":ROUTE.size()-1,"disabled":false,
		"protocol":{},"skid":NONE,"diversion":[]}

func machine_path(_start: Vector2i, _goal: Vector2i, _avoid_people: bool) -> Array[Vector2i]:
	return [] # Patrol-only gates do not request navigation; protocol supplies mission terrain.

func mission_definition() -> Resource:
	return mission_override if mission_override != null else FarmRoadMission

func machine_view_snapshot() -> Dictionary:
	return {
		"track":machine_track().duplicate(),
		"FIXTURES":FIXTURES.duplicate(),
		"breaker":mission_definition().breaker_cell,
		"skid":mission_definition().skid_cell,
		"skid_visible":skid_visible(),
		"next":next_machine_cell(),
		"present":machine_present(),
		"machine":machine.duplicate(true),
		"enemies":enemies.duplicate(true),
		"sight_mode":sight_mode,
		"pinned_target":pinned_target,
		"NONE":NONE}

func machine_status_snapshot() -> Dictionary:
	return {
		"phase":phase,
		"enemy_message":enemy_message,
		"save_feedback":save_feedback,
		"sight_mode":sight_mode,
		"pinned_target":pinned_target,
		"machine":machine.duplicate(true),
		"enemies":enemies.duplicate(true),
		"danger":danger_summary(),
		"present":machine_present(),
		"intent":enemy_intent()}

func apply_loaded_encounter(snapshot: Dictionary) -> void:
	EncounterRestore.apply(snapshot,{"machine":restore_machine_section,"tactical":restore_tactical_section})

func restore_machine_section(snapshot: Dictionary) -> void:
	machine_state.restore_machine(snapshot["machine"])
