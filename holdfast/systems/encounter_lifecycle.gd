extends RefCounted
## Encounter setup and persistence: each area's starting state, saving and loading the
## encounter, and restoring sections from a save.
## Moved out of encounter_controller.gd; the controller keeps one-line wrappers.
const Persistence = preload("res://systems/encounter_persistence.gd")
const GridProjection = preload("res://presentation/grid_projection.gd")
const MachineActivation = preload("res://systems/machine_activation.gd")
const EvacuationRules = preload("res://systems/civilian_evacuation.gd")
const Roster = preload("res://campaign_roster.gd")
const SaveMigration = preload("res://systems/save_migration.gd")

static func initialize_tactical(board) -> void:
	board.shot_rng.seed = board.COMBAT_SEED
	board.board_projection = GridProjection.new(board.GRID_ORIGIN,Vector2(board.CELL_SIZE,0),Vector2(0,board.CELL_SIZE))
	for index in range(board.soldiers.size()):
		board.soldiers[index]["cell"] = board.mission_definition().squad_spawns[index]
	board.enemies[0]["cell"] = board.mission_definition().machine_spawn
	board.enemies[0]["hp"] = board.mission_definition().machine_hp

static func save_encounter(board, path: String) -> bool:
	var error = Persistence.write(board.encounter_snapshot(),board.encounter_slot(path))
	if error != "":
		board.save_feedback = error
		board.queue_redraw()
		return false
	# Preserve the existing contract: the requested slot succeeded even if its
	# separate campaign checkpoint fails. Feedback reports the checkpoint error.
	var problem = board.checkpoint()
	board.save_feedback = "C2 saved: deployment, roster, service history and current actions." if problem == "" else problem
	board.queue_redraw()
	return true

static func load_encounter(board, path: String) -> bool:
	# Migration historically examines the requested source before lower-gate
	# aliases are mapped. Keep that order for existing legacy saves.
	if [board.TACTICAL_SLOT,board.STORY_SLOT,board.RESULT_SLOT].has(path): path = board.RETURN_SLOT
	var migration = SaveMigration.return_slot(path,board.campaign_path,board.rescue_layout())
	if migration["error"] != "":
		board.save_feedback = migration["error"]
		return false
	var error = Persistence.restore(board.encounter_slot(migration["path"]),board.rescue_layout(),
		"Save belongs to another encounter.",board.apply_loaded_encounter)
	if error != "":
		board.save_feedback = error
		board.result_feedback = error
		board.queue_redraw()
		return false
	board.save_feedback = "D1 restored: original outcome, repair progress and one-use cooling record."
	board.queue_redraw()
	return true

static func restore_tactical_section(board, snapshot: Dictionary) -> void:
	var ui: Dictionary = snapshot["ui"]
	board.active_soldier = ui["active"]
	board.restore_combat(snapshot["combat"])
	board.selected_cell = ui["selected"]
	board.pinned_target = ui["pinned"]
	board.sight_mode = ui["sight"]
	board.status_text = ui["status"]
	board.hovered_cell = board.NONE

static func initialize_machine(board) -> void:
	board.machine_behavior = MachineActivation.new(board.next_machine_cell, board.enemy_target, board.cell_occupied_by_people, board.damage_cell, board.machine_path)
	board.enemies.assign([{"cell": board.mission_definition().machine_spawn, "hp": board.mission_definition().machine_hp, "ammo": 4}])
	board.status_text = "Farm Road: neutral machine. Orange = next movement; red = charged shot."
	board.enemy_message = "Observed route: (10,8) → (9,8) → (8,8) → skid (7,8), then return."
	board.save_feedback = "B1 has its own save slot. Gate A scene and save remain available."

static func initialize_evacuation(board) -> void:
	board.evacuation_rules = EvacuationRules.new(board.civilian_safe, board.civilian_waypoint, board.civilian_exit,
		board.route_available, board.soldier_can_act, board.on_civilian_step)
	for index in range(board.cohorts.size()):
		board.cohorts[index]["cell"] = board.mission_definition().civilian_spawns[index]
	for soldier in board.soldiers:
		soldier["left_behind"] = false
	board.status_text = "Order one group each player phase. Machine → civilians → closure."
	board.save_feedback = "B2 save slot. Cohort manifest IDs are placeholders for named civilians."

static func restore_evac_section(board, snapshot: Dictionary) -> void:
	var evac: Dictionary = snapshot["evac"]
	board.evacuation_state.restore(evac)
	board.cohort_selected = evac["selected"]
	board.close_pending = false

static func initialize_rescue(board) -> void:
	for index in range(board.soldiers.size()):
		board.soldiers[index].merge({"condition":"active","bleed":0,"critical_epoch":0,
			"medical":2 if index == 1 else 0,"carrying":-1,"carried_by":-1})
	board.status_text = "Rescue: select a rescuer, then click a casualty. S stabilize, U pick up, J put down."
	board.save_feedback = "B5 save slot. V cycles casualties. Critical timer counts three subsequent player phases."

static func restore_story_state(board, snapshot: Dictionary) -> void:
	board.story_state.restore(snapshot["story"])
	board.scene_view = "" if board.opening_done else "opening"
	board.scene_page = board.opening_step
	board.return_view = ""

static func initialize_roster(board, resume: bool) -> void:
	board.report_path = "user://holdfast_c2_result.save"
	board.completion_path = "user://holdfast_c2_completed.save"
	if board.campaign.is_empty(): board.campaign = Roster.initial()
	board.apply_assignments()
	if board.campaign["deployment"] == 2:
		board.opening_done = true
		board.opening_step = 2
		board.scene_view = ""
		board.status_text = "Deployment 2 roster test: same map, new civilian manifest. Existing wounds remain."
	board.save_feedback = "C2: K save / L load. G roster after resolution. Campaign resumes saved progress."
	if resume and FileAccess.file_exists(board.campaign_path):
		load_encounter(board, board.campaign_path)

static func initialize_return(board, resume: bool) -> void:
	board.report_path = "user://holdfast_d1_result.save"
	board.completion_path = "user://holdfast_d1_completed.save"
	if board.return_state["active"]: board.configure_return()
	if resume:
		if FileAccess.file_exists(board.campaign_path): load_encounter(board, board.campaign_path)
		elif FileAccess.file_exists(board.CAMPAIGN_SLOT): load_encounter(board, board.CAMPAIGN_SLOT)
	board.save_feedback = "D1: K save / L load. G roster; return map uses the original machine outcome."
