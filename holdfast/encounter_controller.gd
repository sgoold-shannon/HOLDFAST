extends Node2D
## Standalone active encounter. Prototype gate scenes are compatibility fixtures only.
## Simulation, state, presentation and persistence use the composed components below.

const MovementSearch = preload("res://systems/movement_search.gd")
const CombatState = preload("res://state/combat_state.gd")
var combat_state := CombatState.new()
var shot_rng: RandomNumberGenerator:
	get: return combat_state.shot_rng
	set(value): combat_state.shot_rng = value
var shot_history: Array[Dictionary]:
	get: return combat_state.shot_history
	set(value): combat_state.shot_history = value
var enemies: Array[Dictionary]:
	get: return combat_state.enemies
	set(value): combat_state.enemies = value
var last_enemy_phase: int:
	get: return combat_state.last_enemy_phase
	set(value): combat_state.last_enemy_phase = value
var enemy_message: String:
	get: return combat_state.enemy_message
	set(value): combat_state.enemy_message = value
var soldiers: Array[Dictionary]:
	get: return combat_state.soldiers
	set(value): combat_state.soldiers = value
var phase: int:
	get: return combat_state.phase
	set(value): combat_state.phase = value
const EncounterRestore = preload("res://systems/encounter_restore.gd")
const Persistence = preload("res://systems/encounter_persistence.gd")
const SceneChrome = preload("res://presentation/scene_chrome.gd")
const InteractionInput = preload("res://presentation/modal_input.gd")
const TacticalPanel = preload("res://presentation/tactical_panel.gd")
## HOLDFAST A6. Public cell coordinates follow GDD v3.1 section 26 (one-based).
const SandboxMission = preload("res://missions/tactical_sandbox.tres")
const MissionObjectives = preload("res://systems/mission_objectives.gd")
const ActorView = preload("res://presentation/actor_view.gd")
const OverlayView = preload("res://presentation/tactical_overlay.gd")
const BoardView = preload("res://presentation/board_view.gd")
const TacticalInput = preload("res://presentation/tactical_input.gd")
const GridProjection = preload("res://presentation/grid_projection.gd")
var mission_override: Resource
var board_projection: GridProjection
const SaveStore = preload("res://encounter_save.gd")
const SAVE_RECT := Rect2(250, 1020, 180, 40)
const LOAD_RECT := Rect2(440, 1020, 180, 40)
var save_feedback := "One local slot | K: save | L: load"
const Rules = preload("res://tactical_rules.gd")
const FIRE_RECT := Rect2(40, 880, 200, 40)
const RELOAD_RECT := Rect2(250, 880, 220, 40)
const COMBAT_SEED := 3104


# A5 test enemy: stationary, nearest visible active target, roster-order ties.



const EXTRACT_RECT := Rect2(40, 1020, 200, 40)

var sight_mode := false
var pinned_target := Vector2i(-1, -1)
const MODE_RECT := Rect2(480, 880, 178, 40)
var GRID_SIZE: Vector2i:
	get: return mission_definition().grid_size
const CELL_SIZE := 36.0
const GRID_ORIGIN := Vector2(72, 96)
var WALL_CELLS: Array[Vector2i]:
	get: return mission_definition().walls
const NONE := Vector2i(-1, -1)
var selected_cell := NONE
var status_text := "Click a ground cell to select it."
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]

var active_soldier := -1
var hovered_cell := NONE
var distances: Dictionary = {}
var parents: Dictionary = {}

const NEXT_PHASE_RECT := Rect2(668, 880, 156, 40)
var font: Font = ThemeDB.fallback_font

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

const ProtocolPanel = preload("res://presentation/protocol_panel.gd")
## B4 communication actions are deterministic; the pause is single-use.
const PROTOCOL_SLOT := "user://holdfast_b4.save"
var CONSOLE_CELL: Vector2i:
	get: return mission_definition().console_cell
var SKID_CELL: Vector2i:
	get: return mission_definition().skid_cell
var DIVERSION: Array[Vector2i]:
	get: return mission_definition().diversion
const OBSERVE_RECT := Rect2(40,1136,180,40)
const TRANSMIT_RECT := Rect2(230,1136,180,40)
const AUTH_RECT := Rect2(420,1136,190,40)
const DIVERT_RECT := Rect2(620,1136,204,40)
var protocol: Dictionary:
	get: return machine_state.protocol
	set(value): machine_state.protocol = value

const RescuePanel = preload("res://presentation/rescue_panel.gd")
## B5 casualty rules; critical_epoch is the round in which the wound occurred.
const RESCUE_SLOT := "user://holdfast_b5.save"
const CASUALTY_RECT := Rect2(876,1032,248,32)
const STABILIZE_RECT := Rect2(876,1072,248,34)
const PICKUP_RECT := Rect2(876,1114,248,34)
const DROP_RECT := Rect2(876,1156,248,34)
var rescue_target := -1
var drop_mode := false

const Completion = preload("res://systems/encounter_completion.gd")
const ResultState = preload("res://state/result_state.gd")
var result_state := ResultState.new()
const CampaignPersistence = preload("res://systems/campaign_persistence.gd")
const ResultInput = preload("res://presentation/modal_input.gd")
const ResultsPanel = preload("res://presentation/results_panel.gd")
## B6 derives results from the resolved encounter, never from predicted outcomes.
const RESULT_SLOT := "user://holdfast_b6.save"
const REPORT_SLOT := "user://holdfast_b6_result.save"
const COMPLETION_SLOT := "user://holdfast_b6_completed.save"
const RETRY_RECT := Rect2(60,1080,320,54)
const RESUME_RECT := Rect2(402,1080,320,54)
const RECORD_RECT := Rect2(744,1080,320,54)
var rescue_events: Array:
	get: return result_state.rescue_events
	set(value): result_state.rescue_events = value
var result_ready: bool:
	get: return result_state.result_ready
	set(value): result_state.result_ready = value
var pending_finish_reason: String:
	get: return result_state.pending_finish_reason
	set(value): result_state.pending_finish_reason = value
var result_feedback := ""
var report_path := REPORT_SLOT
var completion_path := COMPLETION_SLOT

const StoryState = preload("res://state/story_state.gd")
var story_state := StoryState.new()
const ModalInput = preload("res://presentation/modal_input.gd")
const StoryPanel = preload("res://presentation/story_panel.gd")
## C1: authored scenes consume recorded facts; dialogue never changes combat values.
const STORY_SLOT := "user://holdfast_c1.save"
const DEBRIEF_RECT := Rect2(744,945,320,40)
const NEXT_RECT := Rect2(60,1030,480,58)
const SKIP_RECT := Rect2(560,1030,480,58)
const LOG_RECT := Rect2(560,1110,480,48)
var opening_done: bool:
	get: return story_state.opening_done
	set(value): story_state.opening_done = value
var opening_step: int:
	get: return story_state.opening_step
	set(value): story_state.opening_step = value
var preference: String:
	get: return story_state.preference
	set(value): story_state.preference = value
var debrief_response: String:
	get: return story_state.debrief_response
	set(value): story_state.debrief_response = value
var closure_warning: bool:
	get: return story_state.closure_warning
	set(value): story_state.closure_warning = value
var powered_gate_groups: Array:
	get: return story_state.powered_gate_groups
	set(value): story_state.powered_gate_groups = value
var knowledge: Array:
	get: return story_state.knowledge
	set(value): story_state.knowledge = value
var scene_view := "opening"
var scene_page := 0
var return_view := ""
var return_page := 0

const CampaignState = preload("res://state/campaign_state.gd")
var campaign_state := CampaignState.new()
const RosterPanel = preload("res://presentation/roster_panel.gd")
const Roster = preload("res://campaign_roster.gd")
const CAMPAIGN_SLOT := "user://holdfast_c2_campaign.save"
const TACTICAL_SLOT := "user://holdfast_c2.save"
const ROSTER_RECT := Rect2(402,945,320,40)
const DEPLOY_RECT := Rect2(60,1080,480,58)
const BACK_RECT := Rect2(560,1080,480,58)
const CARE_RECT := Rect2(60,1002,1024,48)
var campaign: Dictionary:
	get: return campaign_state.campaign
	set(value): campaign_state.campaign = value
var auto_resume := true
var campaign_path := CAMPAIGN_SLOT
var roster_open := false
var roster_index := 0
var history_page := 0

const SaveMigration = preload("res://systems/save_migration.gd")
const ReturnOverlay = preload("res://presentation/return_overlay.gd")
const NorthboundMission = preload("res://missions/northbound_return.tres")
const ReturnRules = preload("res://return_rules.gd")
const RETURN_SLOT := "user://holdfast_d1.save"
const RETURN_CAMPAIGN := "user://holdfast_d1_campaign.save"
var TUNNEL: Vector2i:
	get: return NorthboundMission.civilian_exit
var REPAIR_CELL: Vector2i:
	get: return mission_definition().repair_cell
const COOLING_BUTTON := Rect2(40,1136,784,40)
var return_state: Dictionary:
	get: return campaign_state.return_state
	set(value): campaign_state.return_state = value

const InputRouter = preload("res://systems/encounter_input.gd")
const Snapshot = preload("res://systems/encounter_snapshot.gd")
const ViewRouter = preload("res://presentation/view_router.gd")
const EndingOverlay = preload("res://presentation/ending_overlay.gd")
const ENDING_RECT := Rect2(60,945,320,40)
const HudMapLayer = preload("res://presentation/hud/map_layer.gd")
const LegacyScreen = preload("res://presentation/legacy_screen.gd")
const CivilianCommand = preload("res://systems/civilian_command.gd")
const ViewModels = preload("res://presentation/view_models.gd")
## "phase": one free group order per turn (original rule, used by the legacy layout and tests).
## "authority": MSG's voice range, 1 AP orders from nearby soldiers, and panic (desktop game).
var command_model := "phase"
## Gunfire this round; scares civilians nearby at the end of the round (authority model).
var round_noise: Array[Vector2i] = []
## Desktop HUD (game.tscn) sets this: the board then draws only the map and
## leaves mouse input to the HUD. Keyboard shortcuts keep working unchanged.
var hud_mode := false

func _ready() -> void:
	prepare_return_startup()
	initialize_tactical()
	initialize_machine()
	initialize_evacuation()
	initialize_breaker()
	initialize_protocol()
	initialize_rescue()
	initialize_results()
	initialize_story()
	# Restore only after roster assignment and return configuration are ready.
	initialize_roster(false)
	initialize_return(auto_resume)

func initialize_tactical() -> void:
	shot_rng.seed = COMBAT_SEED
	board_projection = GridProjection.new(GRID_ORIGIN,Vector2(CELL_SIZE,0),Vector2(0,CELL_SIZE))
	for index in range(soldiers.size()):
		soldiers[index]["cell"] = mission_definition().squad_spawns[index]
	enemies[0]["cell"] = mission_definition().machine_spawn
	enemies[0]["hp"] = mission_definition().machine_hp

func encounter_snapshot() -> Dictionary:
	return Snapshot.assemble(rescue_layout(),{
		"combat":combat_snapshot(),"ui":ui_state_snapshot(),"machine":machine,
		"evac":evac_state_snapshot(),"breaker":breaker_progress,"protocol":protocol,
		"rescue_target":rescue_target,"rescue_events":rescue_events,"story":story_state_snapshot(),
		"campaign":campaign,"return_map":return_state})

func save_encounter(path: String = RETURN_SLOT) -> bool:
	var error := Persistence.write(encounter_snapshot(),encounter_slot(path))
	if error != "":
		save_feedback = error
		queue_redraw()
		return false
	# Preserve the existing contract: the requested slot succeeded even if its
	# separate campaign checkpoint fails. Feedback reports the checkpoint error.
	var problem := checkpoint()
	save_feedback = "C2 saved: deployment, roster, service history and current actions." if problem == "" else problem
	queue_redraw()
	return true

func load_encounter(path: String = RETURN_SLOT) -> bool:
	# Migration historically examines the requested source before lower-gate
	# aliases are mapped. Keep that order for existing legacy saves.
	if [TACTICAL_SLOT,STORY_SLOT,RESULT_SLOT].has(path): path = RETURN_SLOT
	var migration := SaveMigration.return_slot(path,campaign_path,rescue_layout())
	if migration["error"] != "":
		save_feedback = migration["error"]
		return false
	var error := Persistence.restore(encounter_slot(migration["path"]),rescue_layout(),
		"Save belongs to another encounter.",apply_loaded_encounter)
	if error != "":
		save_feedback = error
		result_feedback = error
		queue_redraw()
		return false
	save_feedback = "D1 restored: original outcome, repair progress and one-use cooling record."
	queue_redraw()
	return true

func soldier_can_act(index: int) -> bool:
	return index >= 0 and index < soldiers.size() and not soldiers[index]["extracted"] and soldiers[index]["hp"] > 0 and soldiers[index].get("condition","active") == "active" and soldiers[index].get("carried_by",-1) == -1

func all_extracted() -> bool:
	for soldier in soldiers:
		if not soldier["extracted"] and soldier.get("condition","active") != "dead":
			return false
	return true

func extraction_cell(cell: Vector2i) -> bool:
	return MissionObjectives.squad_exit(mission_definition(),cell)

func try_extract() -> bool:
	var actor := active_soldier
	var passenger: int = soldiers[actor]["carrying"] if actor >= 0 else -1
	close_pending = false
	var success := false
	if not ended:
		success = extract_selected_soldier()
		# Preserve the original status evaluation before passenger extraction.
		if success and all_extracted():
			status_text = "Squad extracted. %d civilians remain; continue turns or close operation." % remaining_civilians()
	if success and passenger >= 0:
		soldiers[passenger]["extracted"] = true
		soldiers[passenger]["carried_by"] = -1
		soldiers[actor]["carrying"] = -1
		status_text = "%s and %s extracted together for 1 AP." % [soldiers[actor]["name"],soldiers[passenger]["name"]]
		record_rescue("extracted_with",actor,passenger)
	if not success and return_state["active"]:
		status_text = "North extraction: (9,1) through (11,1), 1 AP; carriers extract both."
	return success

func extract_selected_soldier() -> bool:
	if not soldier_can_act(active_soldier):
		status_text = "Select an active soldier to extract."
	elif not extraction_cell(soldiers[active_soldier]["cell"]):
		status_text = mission_definition().squad_exit_hint
	elif soldiers[active_soldier]["ap"] < 1:
		status_text = "Extraction needs 1 AP. Entering the zone does not extract automatically."
	else:
		var soldier: Dictionary = soldiers[active_soldier]
		soldier["ap"] -= 1
		soldier["extracted"] = true
		status_text = "%s extracted for 1 AP." % soldier["name"]
		if all_extracted():
			status_text = "All four soldiers extracted. A5 encounter complete."
		active_soldier = -1
		selected_cell = NONE
		pinned_target = NONE
		rebuild_movement()
		return true
	queue_redraw()
	return false

func enemy_target() -> int:
	return machine_behavior.nearest_target(machine,enemies[0],soldiers,machine_plan(),soldier_can_act,sight_preview)

func enemy_intent() -> String:
	if not machine_present() or disabled():
		if machine["departed"] and protocol["diverted"]:
			return "DIVERTED: alternate component collected; machine departed."
		if disabled() and machine_present():
			return "DISABLED | No movement or shot | Feeder unpowered"
		return origin_machine_intent()
	if protocol["pause_pending"]: return "ACK-01: next machine activation PAUSED (once)."
	if protocol["diverted"]:
		return "DIVERTED: component collected; departs next activation." if protocol["component_collected"] else "DIVERTED: 2 squares/phase; avoids people; no defensive shots."
	if protocol["betrayed"] and machine["collected_round"] == 0:
		return "HOSTILE: safe route canceled; replanning toward skid (7,8)."
	return origin_machine_intent()

func resolve_enemy_turn() -> void:
	if return_state["active"]: activate_return_staging()
	else: activate_origin_machine()
	check_recovery_failure()
	finalize_result()

func target_at(cell: Vector2i) -> int:
	if return_state["active"]: return -1
	return 0 if machine_present() and enemies[0]["cell"] == cell else -1

func fire_block_reason() -> String:
	if soldier_can_act(active_soldier) and soldiers[active_soldier].get("carrying",-1) >= 0:
		return "Cannot fire while carrying a casualty."
	if ended: return "Operation ended. Load a save or restart to retry."
	return rifle_block_reason().replace("enemy (red E)","machine (D)").replace("enemy","machine")

func rifle_block_reason() -> String:
	if not soldier_can_act(active_soldier):
		return "Select an active soldier."
	var soldier: Dictionary = soldiers[active_soldier]
	if soldier["attacked"]:
		return "Attack already used this round."
	if soldier["ap"] < 1:
		return "No AP remaining."
	if soldier["ammo"] < 1:
		return "Magazine empty. Reload first."
	if not sight_mode:
		return "Switch to sight mode [T] and pin a enemy."
	if pinned_target == NONE:
		return "Click a enemy to pin it before firing."
	if target_at(pinned_target) < 0:
		return "Pin a standing enemy (red E)."
	var info := sight_preview(soldier["cell"], pinned_target)
	if not info["clear"]:
		return "Wall blocks the shot."
	if not info["can_fire"]:
		return "Target outside rifle range (1–12 squares)."
	return ""

func try_fire() -> bool:
	if return_state["active"]: return reject_return_fire()
	var was_diverted: bool = protocol["diverted"]
	var shooter_cell: Vector2i = soldiers[active_soldier]["cell"] if active_soldier >= 0 and active_soldier < soldiers.size() else NONE
	var success := fire_at_machine()
	if success and command_model == "authority":
		round_noise.append(shooter_cell)
		round_noise.append(enemies[0]["cell"])
	apply_protocol_betrayal(success,was_diverted)
	check_recovery_failure()
	finalize_result()
	return success

func try_reload() -> bool:
	close_pending = false
	return false if ended else reload_selected_soldier()

func reload_selected_soldier() -> bool:
	if not soldier_can_act(active_soldier):
		status_text = "Select an active soldier to reload."
	elif soldiers[active_soldier]["ap"] < 1:
		status_text = "Reload needs 1 AP."
	elif soldiers[active_soldier]["ammo"] == 4:
		status_text = "Magazine already full. No AP spent."
	else:
		soldiers[active_soldier]["ap"] -= 1
		soldiers[active_soldier]["ammo"] = 4
		status_text = "%s reloaded for 1 AP. Attack allowance unchanged." % soldiers[active_soldier]["name"]
		rebuild_movement()
		return true
	queue_redraw()
	return false

# Complete stable combat snapshot includes RNG state for later save integration (A6).

func combat_snapshot() -> Dictionary:
	return combat_state.snapshot()

func restore_combat(snapshot: Dictionary) -> void:
	combat_state.restore(snapshot)
	if active_soldier >= 0:
		selected_cell = soldiers[active_soldier]["cell"]
	rebuild_movement()

func cell_is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= GRID_SIZE.x and cell.y >= 1 and cell.y <= GRID_SIZE.y

func is_walkable(cell: Vector2i) -> bool:
	if return_state["active"] and enemies[0]["hp"] > 0 and cell == REPAIR_CELL: return false
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell) or target_at(cell) >= 0:
		return false
	for index in range(soldiers.size()):
		if soldier_visible(index) and ["critical","stable"].has(soldiers[index].get("condition","active")) and soldiers[index]["cell"] == cell:
			return false
	return true

func local_to_cell(point: Vector2) -> Vector2i:
	return board_projection.point_to_cell(point)

func cell_to_local(cell: Vector2i) -> Vector2:
	return board_projection.cell_anchor(cell)

func try_select_cell(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell):
		return false
	if not is_walkable(cell):
		status_text = "Cell (%d, %d) is blocked. Selection unchanged." % [cell.x, cell.y]
		queue_redraw()
		return false
	selected_cell = cell
	status_text = "Selected ground (%d, %d)." % [cell.x, cell.y]
	queue_redraw()
	return true

func soldier_at(cell: Vector2i) -> int:
	for index in range(soldiers.size()):
		if soldier_visible(index) and soldiers[index].get("condition","active") != "dead" and soldiers[index]["cell"] == cell:
			return index
	return -1

func rebuild_movement() -> void:
	refresh_tactical_movement()
	limit_carrier_movement()

func refresh_tactical_movement() -> void:
	distances.clear()
	parents.clear()
	if not soldier_can_act(active_soldier):
		queue_redraw()
		return
	var found := MovementSearch.reachable(soldiers[active_soldier]["cell"],soldiers[active_soldier]["ap"]*4,DIRECTIONS,is_walkable)
	distances.merge(found["distances"])
	parents.merge(found["parents"])
	queue_redraw()

func move_cost(cell: Vector2i) -> int:
	if not soldier_can_act(active_soldier) or not distances.has(cell) or soldier_at(cell) >= 0:
		return 0
	var steps: int = distances[cell]
	if steps <= 0:
		return 0
	return 1 if steps <= 4 else 2

func path_to(cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if move_cost(cell) == 0:
		return path
	var current := cell
	path.push_front(current)
	while parents.has(current):
		current = parents[current]
		path.push_front(current)
	return path

func select_soldier(index: int) -> void:
	if not soldier_can_act(index):
		status_text = "Soldier unavailable. Critical soldiers cannot act; recovery comes later."
		queue_redraw()
		return
	active_soldier = index
	selected_cell = soldiers[index]["cell"]
	status_text = "%s selected. Hover a target; click to pin or unpin." % soldiers[index]["name"] if sight_mode else "%s selected. Hover a destination to preview its route." % soldiers[index]["name"]
	rebuild_movement()

func try_move(cell: Vector2i) -> bool:
	var actor := active_soldier
	close_pending = false
	if ended: return false
	var success := move_selected_soldier(cell)
	if success and soldiers[actor]["carrying"] >= 0:
		soldiers[soldiers[actor]["carrying"]]["cell"] = cell
	return success

func move_selected_soldier(cell: Vector2i) -> bool:
	var cost := move_cost(cell)
	if cost == 0 or cost > soldiers[active_soldier]["ap"]:
		status_text = "Cannot move there: blocked, occupied, or beyond remaining AP."
		queue_redraw()
		return false
	var steps: int = distances[cell]
	soldiers[active_soldier]["cell"] = cell
	soldiers[active_soldier]["ap"] -= cost
	selected_cell = cell
	status_text = "%s moved %d squares for %d AP. %d AP remaining." % [soldiers[active_soldier]["name"], steps, cost, soldiers[active_soldier]["ap"]]
	rebuild_movement()
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

func toggle_sight() -> void:
	sight_mode = not sight_mode
	status_text = "Aim: click the enemy to pin it, review the chance, then press F to fire." if sight_mode else "Movement mode. Click a destination to move."
	queue_redraw()

func sight_target() -> Vector2i:
	return pinned_target if pinned_target != NONE else hovered_cell

func _unhandled_input(event: InputEvent) -> void:
	if hud_mode and not (event is InputEventKey):
		return
	LegacyScreen.handle_input(self,event)

func soldier_role(index: int) -> String:
	return {"MSG":"PSYOP", "Ortiz":"MEDIC", "Bell":"ENGINEER", "Park":"RECON"}.get(soldiers[index]["name"], "RIFLE")

func soldier_color(index: int) -> Color:
	return [Color("e9c66a"),Color("8ce0c1"),Color("8fb9ff"),Color("d7a2ed")][index % 4]

func draw_soldier_marker(index: int, center: Vector2) -> void:
	ActorView.soldier(self,font,center,soldier_marker_snapshot(index))

func _draw() -> void:
	if hud_mode:
		HudMapLayer.render(self)
		return
	LegacyScreen.render(self)

func draw_targets() -> void:
	pass # Farm Road draws its machine after hazard overlays.

func soldier_visible(index: int) -> bool:
	return not soldiers[index]["extracted"] and soldiers[index].get("carried_by",-1) == -1

func mission_definition() -> Resource:
	if mission_override != null: return mission_override
	return NorthboundMission if return_state["active"] else FarmRoadMission

func sight_preview(shooter: Vector2i, target: Vector2i) -> Dictionary:
	return Rules.preview(shooter,target,mission_definition())

func board_view_snapshot() -> Dictionary:
	return ViewModels.board_view_snapshot(self)

func tactical_buttons() -> Dictionary:
	return {"save":SAVE_RECT,"load":LOAD_RECT,"extract":EXTRACT_RECT,
		"fire":FIRE_RECT,"reload":RELOAD_RECT,"mode":MODE_RECT,"next":NEXT_PHASE_RECT}

func run_tactical_command(command: String) -> void:
	match command:
		"save": save_encounter()
		"load": load_encounter()
		"extract": try_extract()
		"fire": try_fire()
		"reload": try_reload()
		"mode": toggle_sight()
		"next": next_phase()
		"clear":
			active_soldier = -1
			pinned_target = NONE
			status_text = "Selection cleared. Click a soldier or inspect a ground cell."
			rebuild_movement()

func soldier_marker_snapshot(index: int) -> Dictionary:
	return ViewModels.soldier_marker_snapshot(self, index)

func tactical_overlay_snapshot(path: Array[Vector2i], target: Vector2i) -> Dictionary:
	return ViewModels.tactical_overlay_snapshot(self, path, target)

func tactical_panel_snapshot(path: Array[Vector2i], target: Vector2i) -> Dictionary:
	return ViewModels.tactical_panel_snapshot(self, path, target)

func interaction_command(event: InputEvent, keys: Dictionary, buttons: Dictionary, rows: Array = []) -> String:
	var point := Vector2.ZERO
	if event is InputEventMouse: point = get_global_transform_with_canvas().affine_inverse()*event.position
	return InteractionInput.command(event,point,keys,buttons,rows)

func apply_loaded_encounter(snapshot: Dictionary) -> void:
	EncounterRestore.apply(snapshot,{"extra":restore_extra_snapshot,"rescue":restore_rescue_section,"protocol":restore_protocol_section,"breaker":restore_breaker_section,"evac":restore_evac_section,"machine":restore_machine_section,"tactical":restore_tactical_section})

func ui_state_snapshot() -> Dictionary:
	return {"active":active_soldier,"selected":selected_cell,"pinned":pinned_target,"sight":sight_mode,"status":status_text}

func restore_tactical_section(snapshot: Dictionary) -> void:
	var ui: Dictionary = snapshot["ui"]
	active_soldier = ui["active"]
	restore_combat(snapshot["combat"])
	selected_cell = ui["selected"]
	pinned_target = ui["pinned"]
	sight_mode = ui["sight"]
	status_text = ui["status"]
	hovered_cell = NONE

func initialize_machine() -> void:
	machine_behavior = MachineActivation.new(next_machine_cell, enemy_target, cell_occupied_by_people, damage_cell, machine_path)
	enemies.assign([{"cell": mission_definition().machine_spawn, "hp": mission_definition().machine_hp, "ammo": 4}])
	status_text = "Farm Road: neutral machine. Orange = next movement; red = charged shot."
	enemy_message = "Observed route: (10,8) → (9,8) → (8,8) → skid (7,8), then return."
	save_feedback = "B1 has its own save slot. Gate A scene and save remain available."

func machine_present() -> bool:
	return enemies[0]["hp"] > 0 and not machine["departed"]

func next_machine_cell() -> Vector2i:
	if return_state["active"]: return NONE
	return machine_behavior.next_cell(machine,enemies[0],ROUTE,machine_plan())

func origin_machine_intent() -> String:
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
	if soldier_at(cell) >= 0: return true
	for cohort in cohorts:
		if cohort["status"] == "active" and cohort["cell"] == cell: return true
	return false

func damage_cell(cell: Vector2i, amount: int) -> String:
	var report := apply_casualty_damage(cell,amount)
	# Recovery must wait for every cell in the enclosing blast to resolve.
	call_deferred("check_recovery_failure")
	return report

func activate_origin_machine() -> void:
	if last_enemy_phase == phase: return
	last_enemy_phase = phase
	var outcome := machine_behavior.activate(machine,enemies[0],soldiers,phase,machine_plan())
	enemy_message = outcome["message"]
	if outcome["rebuild"]: rebuild_movement()

func fire_at_machine() -> bool:
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

func machine_track() -> Array[Vector2i]:
	if return_state["active"]:
		var empty: Array[Vector2i] = []
		return empty
	return mission_definition().machine_display_track

func skid_visible() -> bool:
	if return_state["active"]: return not campaign["missions"][0]["feeder"].contains("severed")
	return machine["collected_round"] == 0

func machine_plan() -> Dictionary:
	return {"collect_stage":mission_definition().machine_collect_stage,"depart_stage":ROUTE.size()-1,
		"disabled":disabled(),"protocol":protocol,"skid":SKID_CELL,"diversion":DIVERSION}

func machine_path(start: Vector2i, goal: Vector2i, avoid_people: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [start]
	var previous: Dictionary = {start: NONE}
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == goal:
			while current != start:
				result.push_front(current)
				current = previous[current]
			return result
		for direction in DIRECTIONS:
			var next := current + direction
			if previous.has(next) or not cell_is_in_bounds(next) or WALL_CELLS.has(next) or FIXTURES.has(next):
				continue
			if avoid_people and cell_occupied_by_people(next):
				continue
			previous[next] = current
			frontier.append(next)
	return result

func machine_view_snapshot() -> Dictionary:
	return ViewModels.machine_view_snapshot(self)

func machine_status_snapshot() -> Dictionary:
	return ViewModels.machine_status_snapshot(self)

func restore_machine_section(snapshot: Dictionary) -> void:
	machine_state.restore_machine(snapshot["machine"])

func initialize_evacuation() -> void:
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
	var route := "north" if order == "north" else "south"
	if return_state["active"]: return mission_definition().civilian_routes[route]
	if disabled(): return mission_definition().disabled_routes[route]
	return NORTH_WAYPOINT if order == "north" else SOUTH_WAYPOINT

func order_cohort(index: int, order: String) -> bool:
	if return_state["active"] and order == "north" and not cooling_ready():
		status_text = "Cooling route unavailable. Choose the manual route; disabled equipment needs two repairs."
		queue_redraw()
		return false
	return issue_civilian_order(index,order)

func issue_civilian_order(index: int, order: String) -> bool:
	close_pending = false
	if command_model == "authority":
		return issue_authority_order(index,order)
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

func issue_authority_order(index: int, order: String) -> bool:
	if ended or index < 0 or index >= 3 or cohorts[index]["status"] != "active" or not ["hold", "north", "south", "follow"].has(order):
		status_text = "Order unavailable."
		queue_redraw()
		return false
	var cohort: Dictionary = cohorts[index]
	var authority := CivilianCommand.order_authority(soldiers,active_soldier,cohort)
	if not authority["ok"]:
		status_text = "Group %s: %s." % [cohort["id"],authority["text"]]
		queue_redraw()
		return false
	if order == "follow" and not soldier_can_act(active_soldier):
		status_text = "Select a standing soldier on the map, then choose Follow Soldier."
		queue_redraw()
		return false
	if authority["cost"] > 0:
		soldiers[authority["by"]]["ap"] -= authority["cost"]
	cohort["leader"] = active_soldier if order == "follow" else -1
	cohort["order"] = order
	cohort["passed"] = cohort["cell"] == civilian_waypoint(order)
	cohort["note"] = "Waiting for your order" if order == "hold" else "Moves after End turn [N]"
	status_text = "Group %s: %s — %s. Moves when you end the turn." % [cohort["id"],cohort_order_label(cohort),authority["text"]]
	queue_redraw()
	return true

func calm_cohort(index: int) -> bool:
	if command_model != "authority" or ended or index < 0 or index >= cohorts.size() or cohorts[index]["status"] != "active":
		return false
	var cohort: Dictionary = cohorts[index]
	var authority := CivilianCommand.calm_authority(soldiers,active_soldier,cohort)
	if not authority["ok"]:
		status_text = "Group %s: %s." % [cohort["id"],authority["text"]]
		queue_redraw()
		return false
	soldiers[authority["by"]]["ap"] -= authority["cost"]
	cohort["panic"] = maxi(CivilianCommand.CALM,CivilianCommand.level(cohort)-authority["steps"])
	status_text = "Group %s: %s. Now %s." % [cohort["id"],authority["text"],CivilianCommand.level_name(cohort)]
	queue_redraw()
	return true

func civilian_threats() -> Array[Vector2i]:
	var threats: Array[Vector2i] = []
	if machine_present():
		threats.append(enemies[0]["cell"])
		if machine["pending_shot"] != NONE: threats.append(machine["pending_shot"])
	threats.append_array(round_noise)
	return threats

func route_label(order: String) -> String:
	if return_state["active"]:
		return ("Cooling" if cooling_ready() else "Cooling locked") if order == "north" else "Manual route"
	return "Upper route" if order == "north" else "Lower route"

func route_available(order: String) -> bool:
	return not (return_state["active"] and order == "north" and not cooling_ready())

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
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell): return false
	if return_state["active"]:
		return not (enemies[0]["hp"] > 0 and cell == REPAIR_CELL)
	return not (disabled() and GATES.has(cell)) and target_at(cell) < 0 and cell != next_machine_cell() and cell != machine["pending_shot"]

func civilian_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	return evacuation_rules.civilian_path(start, goal)

func on_civilian_step(cohort: Dictionary, cell: Vector2i) -> void:
	if protocol["diverted"] and not disabled() and [Vector2i(11,7),Vector2i(11,10)].has(cell) and not powered_gate_groups.has(cohort["id"]):
		powered_gate_groups.append(cohort["id"])

func civilian_exit() -> Vector2i:
	return EXIT_CELL

func resolve_civilian_phase() -> void:
	if ended or last_civilian_phase == phase:
		return
	last_civilian_phase = phase
	if command_model == "authority":
		resolve_authority_civilians()
		return
	for cohort in cohorts:
		move_cohort(cohort,3)

func resolve_authority_civilians() -> void:
	var threats := civilian_threats()
	for cohort in cohorts:
		if cohort["status"] != "active": continue
		var fear := CivilianCommand.update_panic(cohort,threats,soldiers)
		if fear == CivilianCommand.PANICKED:
			var step := CivilianCommand.scatter_step(cohort,threats,civilian_safe)
			if step != cohort["cell"]:
				cohort["cell"] = step
				on_civilian_step(cohort,step)
				cohort["note"] = "PANICKED — scattering away from danger"
			else:
				cohort["note"] = "PANICKED — frozen in place"
			continue
		move_cohort(cohort,CivilianCommand.MOVE_BUDGET[fear])
		if fear == CivilianCommand.SHAKEN and cohort["status"] == "active":
			cohort["note"] = "SHAKEN (moves 2) — " + cohort["note"]
	round_noise.clear()

func move_cohort(cohort: Dictionary, budget: int) -> void:
	evacuation_rules.move_cohort(cohort, budget, soldiers)

func finish_operation(reason: String) -> void:
	if ended or pending_finish_reason != "":
		return
	pending_finish_reason = reason
	call_deferred("finalize_result")

func close_evacuation(reason: String) -> void:
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

func before_turn_resolution() -> bool:
	return resolve_bleeding()

func prepare_machine_phase() -> void:
	close_pending = false

func after_turn_resolution() -> void:
	check_recovery_failure()
	finalize_result()
	update_closure_knowledge()

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

func mission_completion_reason(round_number: int) -> String:
	return MissionObjectives.completion_reason(mission_definition(),round_number,
		machine["collected_round"],all_extracted(),remaining_civilians())

func civilian_view_snapshot() -> Dictionary:
	return ViewModels.civilian_view_snapshot(self)

func civilian_panel_snapshot() -> Dictionary:
	return ViewModels.civilian_panel_snapshot(self)

func evac_state_snapshot() -> Dictionary:
	return {"cohorts": cohorts.duplicate(true), "selected": cohort_selected,
		"order_used": order_used, "ended": ended, "reason": end_reason, "last_phase": last_civilian_phase}

func restore_evac_section(snapshot: Dictionary) -> void:
	var evac: Dictionary = snapshot["evac"]
	evacuation_state.restore(evac)
	cohort_selected = evac["selected"]
	close_pending = false

func initialize_breaker() -> void:
	status_text = "Breaker (9,4): stand adjacent, then I to open for 1 AP. I again previews isolation."
	save_feedback = "B3 save slot. Destroy: blast + lost cooling. Disable: locked civilian gates."

func disabled() -> bool:
	return breaker_progress == 2

func breaker_reason() -> String:
	if soldier_can_act(active_soldier) and soldiers[active_soldier].get("carrying",-1) >= 0:
		return "Cannot operate the breaker while carrying."
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
	if return_state["active"]: return repair_return_machine()
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
	if return_state["active"]:
		return "Return: original %s / %s" % [return_state["source"],"cooling available" if cooling_ready() else ("repair %d/2" % return_state["repair"] if return_state["source"] == "disabled" else "manual route")]
	if enemies[0]["hp"] > 0 and not disabled() and protocol["diverted"]:
		return "Diverted | cooling preserved | skid and feeder intact"
	return origin_machine_outcome()

func origin_machine_outcome() -> String:
	if enemies[0]["hp"] <= 0:
		return "Destroyed | cooling lost | " + ("skid recoverable" if machine["collected_round"] == 0 else "collected skid not restored")
	if disabled():
		return "Disabled: machine retained; feeder outage; civilian gates locked."
	if machine["departed"]:
		return "Departed unresolved: machine and cooling unit unavailable."
	return "Active: no intervention completed."

func breaker_panel_snapshot() -> Dictionary:
	return ViewModels.breaker_panel_snapshot(self)

func restore_breaker_section(snapshot: Dictionary) -> void:
	breaker_progress = snapshot["breaker"]
	isolate_pending = false

func initialize_protocol() -> void:
	status_text = "MSG: O observe, P transmit. Console: Bell uses A authenticate, D divert."
	save_feedback = "B4 save slot. Protocol: HOLD / ONE CYCLE. Acknowledgement token: ACK-01."

func protocol_reason(action: String) -> String:
	if ["authenticate","divert"].has(action) and soldier_can_act(active_soldier) and soldiers[active_soldier].get("carrying",-1) >= 0:
		return "Cannot operate the console while carrying."
	return origin_protocol_reason(action)

func origin_protocol_reason(action: String) -> String:
	if ended or not machine_present() or disabled():
		return "Protocol unavailable: encounter ended or machine stopped/departed."
	if machine["collected_round"] > 0:
		return "Too late: the skid has already been collected."
	if not soldier_can_act(active_soldier) or soldiers[active_soldier]["ap"] < 1:
		return "Select an active soldier with 1 AP."
	if action == "observe" or action == "transmit":
		if active_soldier != 0:
			return "Only MSG may observe and transmit the pause protocol."
		if action == "observe":
			if protocol["observed"]:
				return "Machine already observed."
			var info := sight_preview(soldiers[0]["cell"],enemies[0]["cell"])
			if not info["clear"] or info["distance"] > 8:
				return "Observation needs sight and Manhattan distance 8 or less."
		else:
			if not protocol["observed"]:
				return "Observe the machine before transmitting."
			if protocol["acknowledged"]:
				return "Pause already acknowledged; it can be requested only once."
	else:
		if not protocol["acknowledged"]:
			return "Console requires the returned acknowledgement token."
		var eligible := active_soldier == 2 or (active_soldier == 0 and not soldier_can_act(2))
		if not eligible:
			return "%s operates the console. MSG substitutes if unavailable." % soldiers[2]["name"]
		var delta: Vector2i = soldiers[active_soldier]["cell"] - CONSOLE_CELL
		if absi(delta.x) + absi(delta.y) != 1:
			return "Stand adjacent to the console at (11,12)."
		if action == "authenticate" and protocol["authenticated"]:
			return "Token already authenticated."
		if action == "divert":
			if not protocol["authenticated"]:
				return "Authenticate ACK-01 before setting the route."
			if protocol["route_set"]:
				return "Diversion already used; firing on it cancels safe routing."
	return ""

func protocol_action(action: String) -> bool:
	if return_state["active"]: return reject_return_protocol()
	var success := execute_protocol_action(action)
	update_protocol_observation(action,success)
	return success

func execute_protocol_action(action: String) -> bool:
	if not ["observe","transmit","authenticate","divert"].has(action):
		return false
	var reason := protocol_reason(action)
	if reason != "":
		status_text = reason
		queue_redraw()
		return false
	close_pending = false
	soldiers[active_soldier]["ap"] -= 1
	match action:
		"observe":
			protocol["observed"] = true
			status_text = "Observed machine. Pause protocol displayed: HOLD / ONE CYCLE."
		"transmit":
			protocol["acknowledged"] = true
			protocol["pause_pending"] = true
			status_text = "ACK-01 received. The next machine activation will be skipped once."
		"authenticate":
			protocol["authenticated"] = true
			status_text = "ACK-01 authenticated. Set alternate route for 1 AP before skid collection."
		"divert":
			protocol["route_set"] = true
			protocol["diverted"] = true
			machine["pending_shot"] = NONE
			machine["hostile"] = false
			status_text = "Diverted: (10,10) → (14,10) → component (14,8). Avoids people."
	rebuild_movement()
	return true

func apply_protocol_betrayal(fired: bool, was_diverted: bool) -> void:
	if fired and was_diverted:
		protocol["diverted"] = false
		protocol["betrayed"] = true
		machine["hostile"] = true
		if machine_present():
			status_text += " Safe routing canceled; returning to skid."

func protocol_panel_snapshot() -> Dictionary:
	return ViewModels.protocol_panel_snapshot(self)

func restore_protocol_section(snapshot: Dictionary) -> void:
	machine_state.restore_protocol(snapshot["protocol"])

func initialize_rescue() -> void:
	for index in range(soldiers.size()):
		soldiers[index].merge({"condition":"active","bleed":0,"critical_epoch":0,
			"medical":2 if index == 1 else 0,"carrying":-1,"carried_by":-1})
	status_text = "Rescue: select a rescuer, then click a casualty. S stabilize, U pick up, J put down."
	save_feedback = "B5 save slot. V cycles casualties. Critical timer counts three subsequent player phases."

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

func resolve_bleeding() -> bool:
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
	return true

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
	var actor := active_soldier
	var casualty := target_for_rescue()
	var success := stabilize_casualty()
	if success: record_rescue("stabilized",actor,casualty)
	return success

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
	var actor := active_soldier
	var casualty := rescue_target
	var success := pick_up_casualty()
	if success: record_rescue("picked_up",actor,casualty)
	return success

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

func limit_carrier_movement() -> void:
	if soldier_can_act(active_soldier) and soldiers[active_soldier].get("carrying",-1) >= 0:
		for cell in distances.keys():
			if distances[cell] > 2:
				distances.erase(cell)
	queue_redraw()

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

func rescue_layout() -> String: return "gdd3.1-d1-return"

func rescue_slot() -> String: return RETURN_SLOT

func restore_extra_snapshot(snapshot: Dictionary) -> void:
	Snapshot.restore_extras(snapshot,{"return_map":restore_return_state,"results":restore_results_state,
		"story":restore_story_state,"campaign":restore_campaign_state})

func rescue_panel_snapshot() -> Dictionary:
	return ViewModels.rescue_panel_snapshot(self)

func restore_rescue_section(snapshot: Dictionary) -> void:
	rescue_target = snapshot["rescue_target"]
	drop_mode = false

func initialize_results() -> void:
	save_feedback = "B6: K save / L load. H opens the last resolved mission report."

func restore_results_state(snapshot: Dictionary) -> void:
	result_state.restore(snapshot["rescue_events"],snapshot["evac"]["ended"])
	result_feedback = "Recorded mission restored. Dispositions unchanged."

func record_rescue(kind: String, actor: int, casualty: int) -> void:
	append_rescue_record(kind,actor,casualty)
	apply_rescue_knowledge(actor)

func append_rescue_record(kind: String, actor: int, casualty: int) -> void:
	rescue_events.append({"id":"rescue-%d" % (rescue_events.size()+1),
		"kind":kind,"actor":actor,"casualty":casualty,"phase":phase})

func check_recovery_failure() -> void:
	if ended or soldiers[0]["extracted"] or soldiers[0]["condition"] == "active":
		return
	for index in range(soldiers.size()):
		if soldier_can_act(index):
			return
	finish_operation("MSG incapacitated; no conscious rescuer remains")

func finalize_result() -> void:
	Completion.finalize(result_state,soldiers,close_result_operation,save_mission_result,
		commit_roster,persist_campaign_result)

func close_result_operation(reason: String) -> void:
	close_evacuation(reason)
	close_rescue()

func save_mission_result() -> void:
	var problem := CampaignPersistence.report(encounter_snapshot,report_path,completion_path,not retry_required())
	result_feedback = "Mission record saved automatically." if problem == "" else problem
	queue_redraw()

func retry_required() -> bool:
	return not soldiers[0]["extracted"] or soldiers[0]["condition"] == "dead"

func soldier_disposition(index: int) -> String:
	if soldiers[index].get("actor_id","") == "": return "NOT DEPLOYED / vacancy"
	return recorded_soldier_disposition(index)

func recorded_soldier_disposition(index: int) -> String:
	var soldier: Dictionary = soldiers[index]
	if soldier["condition"] == "dead":
		return "CONFIRMED DEAD"
	if not soldier["extracted"]:
		return "LEFT BEHIND / unavailable"
	if soldier["condition"] == "critical":
		return "EXTRACTED / critical casualty"
	if soldier["condition"] == "stable":
		return "EXTRACTED / stabilized casualty"
	return "EXTRACTED / %d HP" % soldier["hp"]

func feeder_result() -> String:
	if return_state["active"]: return "Original record: "+campaign["missions"][0]["feeder"]
	return origin_feeder_result()

func origin_feeder_result() -> String:
	if machine["collected_round"] > 0:
		return "Feeder severed when the skid was collected."
	if disabled():
		return "Feeder isolated / power outage; skid retained."
	return "Feeder intact; skid not collected."

func evacuated_people() -> int:
	var count := 0
	for cohort in cohorts:
		if cohort["status"] == "extracted": count += cohort["manifest"].size()
	return count

func result_title() -> String:
	if retry_required():
		return "ATTEMPT ENDED / RETRY REQUIRED"
	var everyone := evacuated_people() == 12
	for soldier in soldiers:
		everyone = everyone and soldier["extracted"] and soldier["condition"] != "dead"
	return "FARM ROAD / EVACUATION COMPLETE" if everyone else "FARM ROAD / PARTIAL COMPLETION"

func restart_attempt() -> void:
	if campaign["committed"]:
		open_roster()
		return
	var state := ReturnRules.initial()
	if return_state["active"]:
		state["active"] = true
		state["source"] = return_state["source"]
	replace_return_attempt(campaign.duplicate(true),state)

func results_panel_snapshot() -> Dictionary:
	return ViewModels.results_panel_snapshot(self)

func initialize_story() -> void:
	report_path = "user://holdfast_c1_result.save"
	completion_path = "user://holdfast_c1_completed.save"
	save_feedback = "C1: Tab opens the scene log / intelligence. K save / L load."

func restore_story_state(snapshot: Dictionary) -> void:
	story_state.restore(snapshot["story"])
	scene_view = "" if opening_done else "opening"
	scene_page = opening_step
	return_view = ""

func apply_rescue_knowledge(actor: int) -> void:
	rescue_events[-1]["closure_warning"] = closure_warning
	# The acting soldier knows the action; an unconscious patient is not assumed to.
	knowledge[actor].append(rescue_events[-1]["id"])

func update_closure_knowledge() -> void:
	if not ended and phase >= 3: closure_warning = true

func update_protocol_observation(action: String, success: bool) -> void:
	if success and action == "observe":
		status_text = "Fact: retrieving a marked component. Assessment: evacuation equipment (unconfirmed). Tab: log."

func present(index: int) -> bool:
	return soldiers[index].get("actor_id","") != "" and soldiers[index]["extracted"] and ["active","stable"].has(soldiers[index]["condition"])

func original_actor(index: int, original_name: String) -> bool:
	return soldiers[index].get("actor_id","") == original_name.to_lower()

func knows(index: int, fact: String) -> bool:
	return present(index) and knowledge[index].has(fact)

func deliver_briefing() -> void:
	for index in range(4):
		if not present(index): continue
		for fact in ["outcomes","machinery"]:
			if not knowledge[index].has(fact): knowledge[index].append(fact)
		for event in rescue_events:
			if not knowledge[index].has(event["id"]): knowledge[index].append(event["id"])
	persist_story_report()

func persist_story_report() -> void:
	save_story_report()
	if result_ready and not retry_required():
		sync_knowledge()
		persist_campaign_result()

func save_story_report() -> void:
	if not ended or retry_required(): return
	var problem := CampaignPersistence.report(encounter_snapshot,report_path,completion_path,true)
	result_feedback = "Debrief choices and knowledge saved." if problem == "" else problem

func opening_pages() -> Array:
	return [
		{"speaker":"EXERCISE CHECKPOINT / BEFORE 09:17", "text":"Ortiz: ‘Patients wait in the shade. That buys us time.’\n\nBell: ‘If the truck cannot turn, nobody leaves.’\n\nPark moves a folding chair outside the turning arc.\n‘Both fit. Unless the next truck is bigger.’", "tag":"Ortiz · medic    Bell · engineer    Park · reconnaissance"},
		{"speaker":"09:17 / NORTHERN RIDGE", "text":"A vertical distortion crosses the ridge. No explosion. The power trips. Radio recordings lose eleven seconds.\n\nPark closes his paper notebook. ‘That was not in the exercise.’\n\nA recovery machine emerges through the old service gate.","tag":"Observed disruption / cause unknown"},
		{"speaker":"MAJOR ELENA WARD / TASK FORCE ALDER", "text":"‘Move the civilians east toward town. Keep the Farm Road junction usable. Report what you can verify.’\n\nA broken municipal transmission cuts through:\n‘Clear the service lane. Do not cut the buried feeder. People below need that power.’\n\nThe sender is unverified. The return channel is damaged.","tag":"Protect the route · evacuate civilians · extract the squad"}
	]

func report_text() -> String:
	var text := "Civilians: %d evacuated; %d stranded.\n" % [evacuated_people(),12-evacuated_people()]
	for cohort in cohorts:
		text += "Group %s: %s.\n" % [cohort["id"],"four evacuated" if cohort["status"] == "extracted" else "four stranded; fate unconfirmed"]
	text += "\n"
	for index in range(4): text += "%s: %s.\n" % [soldiers[index]["name"],soldier_disposition(index)]
	return text

func evidence_pages() -> Array:
	var recoveries: Array[String] = []
	for event in rescue_events:
		var line := "%s: %s %s." % [soldiers[event["actor"]]["name"],{"stabilized":"stabilized","picked_up":"picked up","extracted_with":"carried out"}[event["kind"]],soldiers[event["casualty"]]["name"]]
		if not recoveries.has(line): recoveries.append(line)
	if recoveries.is_empty(): recoveries.append("No casualty recovery actions recorded.")
	var pages: Array = []
	for first in range(0,recoveries.size(),6):
		var evidence := machine_outcome()+"\n"+feeder_result()+"\n"+("ACK-01 received; a bounded channel only." if protocol["acknowledged"] else "No protocol acknowledgement recorded.")+"\n\n"+"\n".join(recoveries.slice(first,first+6))
		pages.append({"speaker":"VERIFIED RECORD / READ TO SURVIVORS","text":evidence,"tag":"Available survivors receive these facts before personal dialogue."})
	return pages

func debrief_pages() -> Array:
	return return_debrief_pages() if return_state["active"] else origin_debrief_pages()

func origin_debrief_pages() -> Array:
	var pages: Array = [{"speaker":"FARM ROAD / VERIFIED FIELD REPORT","text":report_text(),"tag":"This report is read to the available survivors before discussion."}]
	pages.append_array(evidence_pages())
	var machine_text := "The machine remained active when we withdrew. No intervention was completed."
	if enemies[0]["hp"] <= 0:
		machine_text = "Machine is down. Its cooling unit is gone."
	elif disabled():
		machine_text = "Drive isolated. The gates lost power with it."
	elif protocol["diverted"]:
		var used := false
		for cohort in cohorts:
			used = used or (powered_gate_groups.has(cohort["id"]) and cohort["status"] == "extracted")
		machine_text = "The feeder stayed up. That gave the last group a route." if used else "The feeder stayed up. We kept that option."
	elif machine["departed"]:
		machine_text = "The machine departed without an intervention resolving it."
	pages.append({"speaker":"BELL" if original_actor(2,"Bell") and knows(2,"machinery") else "TECHNICAL RECORD",
		"text":machine_text+"\n\n"+feeder_result()+"\n\nA bounded protocol response does not establish an alliance." if protocol["acknowledged"] else machine_text+"\n\n"+feeder_result()+"\n\nNo protocol acknowledgement was recorded.",
		"tag":"Recorded machinery outcome / wider purpose unconfirmed"})
	var deaths: Array[String] = []
	for soldier in soldiers:
		if soldier["condition"] == "dead": deaths.append(soldier["name"])
	if not deaths.is_empty():
		pages.append({"speaker":"REST AREA / CASUALTY REPORT","text":"Confirmed dead: %s.\n\nAn empty place remains at the rest area. The casualty report replaces the usual conversation." % ", ".join(deaths),"tag":"Confirmed loss / no invented recovery"})
	elif original_actor(1,"Ortiz") and original_actor(3,"Park") and present(1) and present(3):
		for event in rescue_events:
			if event["kind"] == "stabilized" and event["actor"] == 1 and event["casualty"] == 3 and knows(1,event["id"]) and knows(3,event["id"]):
				pages.append({"speaker":"PARK / ORTIZ", "text":("Park: ‘You came back when the lane was closing.’" if event["closure_warning"] else "Park: ‘You came back for me.’")+"\n\nOrtiz: ‘You were still on this side of it.’\n\nTreatment continues. Extraction has not erased the injury.","tag":"Verified stabilization / both present and briefed"})
				break
	var response_text := "The report stays open for correction. What does the MSG say?"
	if not present(0) or soldiers[0]["condition"] != "active":
		response_text = "The MSG remains under medical care. Discussion waits for treatment; the verified report stands."
	elif debrief_response != "unset":
		response_text = response_line(debrief_response)
	pages.append({"speaker":"MSG / THE RECORD", "text":response_text,"tag":"Acknowledgement changes no casualty or civilian totals."})
	return pages

func response_line(value: String) -> String:
	match value:
		"cost": return "‘Keep the people we brought out and the people we lost in the same report.’"
		"correction": return "‘Correct anything we cannot support. Keep the observation separate from the assessment.’"
		"treatment": return "‘Treatment first. We can talk when everyone who can be helped is being helped.’"
	return ""

func choose_opening(value: String) -> void:
	if opening_done or opening_step != 0 or not ["procedure","patients","logistics"].has(value): return
	preference = value
	opening_step = 1
	scene_page = 1
	queue_redraw()

func finish_opening() -> void:
	if preference == "unset": preference = "skipped"
	opening_done = true
	opening_step = 2
	scene_view = ""
	save_feedback = "C1: Tab scene log / intelligence. K save / L load."
	queue_redraw()

func begin_debrief() -> bool:
	if not result_ready or retry_required(): return false
	scene_view = "debrief"
	scene_page = 0
	queue_redraw()
	return true

func choose_response(value: String) -> void:
	if scene_view != "debrief" or scene_page != debrief_pages().size()-1 or debrief_response != "unset" or not present(0) or soldiers[0]["condition"] != "active" or not ["cost","correction","treatment"].has(value): return
	debrief_response = value
	persist_story_report()
	queue_redraw()

func log_pages() -> Array:
	return return_log_pages() if return_state["active"] else annotate_historical_pages(origin_log_pages())

func origin_log_pages() -> Array:
	var pages := opening_pages()
	pages.append({"speaker":"MSG / SAVED DIALOGUE PREFERENCE","text":"Opening choice: %s\n\nThis preference changes no combat stats." % {"unset":"Not chosen yet.","skipped":"Opening skipped; no preference selected.","procedure":"Mark both spaces, then check the route.","patients":"Ortiz, walk me through the slowest patient.","logistics":"Bell, show me the failure point."}[preference],"tag":"Dialogue record"})
	pages.append({"speaker":"INTELLIGENCE / OBSERVATION & ASSESSMENT", "text":("FACT: retrieving a marked component.\n\nASSESSMENT: evacuation equipment — unconfirmed." if protocol["observed"] else "No close observation has been completed.\n\nThe machine’s purpose is unconfirmed.")+ ("\n\nACK-01 received. This verifies a bounded channel only." if protocol["acknowledged"] else "\n\nNo protocol acknowledgement recorded."),"tag":"Facts and interpretation kept separate"})
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func current_pages() -> Array:
	if scene_view == "opening": return opening_pages()
	if scene_view == "debrief": return debrief_pages()
	return log_pages()

func toggle_log() -> void:
	if scene_view == "log":
		scene_view = return_view
		scene_page = return_page
	else:
		return_view = scene_view
		return_page = scene_page
		scene_view = "log"
		scene_page = 0
	queue_redraw()

func advance_scene() -> void:
	if return_state["active"] and scene_view == "debrief":
		if scene_page == 0: scene_page = 1
		else:
			deliver_briefing()
			scene_view = ""
		queue_redraw()
	else: advance_origin_scene()

func advance_origin_scene() -> void:
	if scene_view == "opening" and scene_page == 0: return
	if scene_view == "debrief" and scene_page == evidence_pages().size(): deliver_briefing()
	if scene_page+1 < current_pages().size():
		scene_page += 1
		if scene_view == "opening": opening_step = scene_page
	elif scene_view == "opening": finish_opening()
	elif scene_view == "log": toggle_log()
	else: scene_view = ""
	queue_redraw()

func choose_scene_option(index: int) -> void:
	if not return_state["active"]: choose_origin_scene_option(index)

func choose_origin_scene_option(index: int) -> void:
	if scene_view == "opening": choose_opening(["procedure","patients","logistics"][index])
	elif scene_view == "debrief": choose_response(["cost","correction","treatment"][index])

func scene_options() -> Array:
	return [] if return_state["active"] else origin_scene_options()

func origin_scene_options() -> Array:
	if scene_view == "opening" and scene_page == 0:
		return ["Mark both spaces, then check the route.","Ortiz, walk me through the slowest patient.","Bell, show me the failure point."]
	if scene_view == "debrief" and scene_page == debrief_pages().size()-1 and debrief_response == "unset" and present(0) and soldiers[0]["condition"] == "active":
		return ["Acknowledge the cost.","Ask for factual corrections.","Defer discussion until treatment."]
	return []

func story_panel_snapshot() -> Dictionary:
	return ViewModels.story_panel_snapshot(self)

func story_state_snapshot() -> Dictionary:
	return story_state.snapshot()

func initialize_roster(resume: bool) -> void:
	report_path = "user://holdfast_c2_result.save"
	completion_path = "user://holdfast_c2_completed.save"
	if campaign.is_empty(): campaign = Roster.initial()
	apply_assignments()
	if campaign["deployment"] == 2:
		opening_done = true
		opening_step = 2
		scene_view = ""
		status_text = "Deployment 2 roster test: same map, new civilian manifest. Existing wounds remain."
	save_feedback = "C2: K save / L load. G roster after resolution. Campaign resumes saved progress."
	if resume and FileAccess.file_exists(campaign_path):
		load_encounter(campaign_path)

func apply_assignments() -> void:
	for index in range(4):
		var id: String = campaign["assignments"][index]
		var soldier: Dictionary = soldiers[index]
		soldier["actor_id"] = id
		if id == "":
			soldier["name"] = "Vacant"
			soldier["mark"] = "-"
			soldier["extracted"] = true
			soldier["ap"] = 0
			soldier["medical"] = 0
		else:
			var actor := Roster.actor(campaign,id)
			soldier["name"] = actor["name"]
			soldier["mark"] = actor["name"].left(1)
			soldier["hp"] = actor["hp"]
	for cohort in cohorts:
		var id: String = cohort["id"]
		cohort["manifest"] = []
		for number in range(1,5): cohort["manifest"].append("D%d-%s-%02d" % [campaign["deployment"],id,number])
	rebuild_movement()

func restore_campaign_state(snapshot: Dictionary) -> void:
	campaign_state.restore_campaign(snapshot["campaign"])
	roster_open = false
	roster_index = 0
	history_page = 0

func checkpoint() -> String:
	return Persistence.write(encounter_snapshot(),campaign_path)

func append_unique(array: Array, value: String) -> void:
	if not array.has(value): array.append(value)

func sync_knowledge() -> void:
	for index in range(4):
		var actor := Roster.actor(campaign,campaign["assignments"][index])
		if actor.is_empty(): continue
		for fact in knowledge[index]: append_unique(actor["knowledge"],"D%d:%s" % [campaign["deployment"],fact])

	# A patient forms this relationship memory only after receiving the event record.
	for event in rescue_events:
		if event["kind"] != "stabilized" or not knows(event["casualty"],event["id"]): continue
		var patient := Roster.actor(campaign,campaign["assignments"][event["casualty"]])
		var rescuer_id: String = campaign["assignments"][event["actor"]]
		if patient.is_empty() or rescuer_id == "": continue
		if not patient["relationships"].has(rescuer_id): patient["relationships"][rescuer_id] = []
		append_unique(patient["relationships"][rescuer_id],"Stabilized me during deployment %d." % campaign["deployment"])

func commit_roster() -> void:
	record_campaign_result()
	record_return_result()

func record_campaign_result() -> void:
	if not result_ready or retry_required() or campaign["committed"]: return
	var mission := {"id":"deployment-%d" % campaign["deployment"],"machine":machine_outcome(),
		"feeder":feeder_result(),"cohorts":cohorts.duplicate(true),"soldiers":[]}
	for index in range(4):
		var id: String = campaign["assignments"][index]
		if id == "": continue
		var actor := Roster.actor(campaign,id)
		var soldier: Dictionary = soldiers[index]
		actor["hp"] = soldier["hp"]
		actor["condition"] = soldier["condition"]
		actor["status"] = "dead" if soldier["condition"] == "dead" else ("left_behind" if not soldier["extracted"] else ("recovering" if soldier["condition"] != "active" else ("wounded" if soldier["hp"] < 8 else "ready")))
		var disposition := soldier_disposition(index)
		append_unique(actor["history"],"D%d: %s" % [campaign["deployment"],disposition])
		mission["soldiers"].append({"id":id,"disposition":disposition})
	for event in rescue_events:
		var rescuer := Roster.actor(campaign,campaign["assignments"][event["actor"]])
		var patient := Roster.actor(campaign,campaign["assignments"][event["casualty"]])
		if rescuer.is_empty() or patient.is_empty(): continue
		var action: String = {"stabilized":"stabilized","picked_up":"picked up","extracted_with":"carried out"}[event["kind"]]
		var memory := "D%d / %s: %s %s %s." % [campaign["deployment"],event["id"],rescuer["name"],action,patient["name"]]
		append_unique(rescuer["history"],memory)
		append_unique(patient["history"],memory)
	sync_knowledge()
	campaign["missions"].append(mission)
	campaign["committed"] = true
	if campaign["deployment"] == 1:
		for index in range(1,4):
			var actor := Roster.actor(campaign,campaign["assignments"][index])
			if not actor.is_empty() and actor["status"] == "dead" and Roster.actor(campaign,"reserve-%d" % index).is_empty():
				campaign["members"].append(Roster.replacement(index))

func persist_campaign_result() -> void:
	var problem := CampaignPersistence.campaign_result(encounter_snapshot,campaign_path,report_path,completion_path,not retry_required())
	result_feedback = "Mission and roster saved. G: review service records." if problem == "" else problem

func can_receive_staging_care() -> bool:
	if not campaign["committed"]: return false
	for actor in campaign["members"]:
		if actor["status"] == "recovering": return true
	return false

func provide_staging_care() -> bool:
	if not can_receive_staging_care(): return false
	# An explicit between-deployment interval, not a tactical heal or resurrection.
	for actor in campaign["members"]:
		if actor["status"] != "recovering": continue
		actor["hp"] = 1
		actor["condition"] = "active"
		actor["status"] = "wounded"
		append_unique(actor["history"],"After deployment %d: treatment and rest; cleared for duty at 1 HP." % campaign["deployment"])
	persist_campaign_result()
	queue_redraw()
	return true

func can_deploy() -> bool:
	return not return_state["active"] and campaign["committed"] and campaign["deployment"] < 3 and Roster.next_assignments(campaign)[0] == "msg"

func start_second_deployment() -> bool:
	if not can_deploy(): return false
	var next := campaign.duplicate(true)
	next["deployment"] += 1
	next["committed"] = false
	next["assignments"] = Roster.next_assignments(campaign)
	var state := ReturnRules.initial()
	state["active"] = true
	state["source"] = ReturnRules.outcome(campaign)
	return replace_return_attempt(next,state)

func open_roster() -> void:
	if not result_ready: return
	roster_open = true
	scene_view = ""
	queue_redraw()

func roster_details(actor: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	lines.append("Traits: %s / %s" % actor["traits"])
	lines.append(actor["hook"])
	lines.append("")
	lines.append("RELATIONSHIPS")
	if actor["relationships"].is_empty(): lines.append("No established relationships.")
	for id in actor["relationships"]:
		for note in actor["relationships"][id]: lines.append(Roster.actor(campaign,id)["name"]+": "+note)
	lines.append("")
	lines.append("SERVICE HISTORY")
	if actor["history"].is_empty(): lines.append("No deployment history. New to this element.")
	for memory in actor["history"]:
		var parts: PackedStringArray = memory.split(": ",true,1)
		lines.append(parts[0].split(" / ")[0].replace("D","Deployment ")+": "+parts[1] if parts.size() == 2 else memory)
	lines.append("")
	lines.append("Briefed / witnessed records: %d" % actor["knowledge"].size())
	for mission in campaign["missions"]:
		var participated := false
		for entry in mission["soldiers"]: participated = participated or entry["id"] == actor["id"]
		if not participated: continue
		var evacuated := 0
		for cohort in mission["cohorts"]:
			if cohort["status"] == "extracted": evacuated += cohort["manifest"].size()
		lines.append("")
		lines.append(mission["id"].replace("deployment-","Deployment ")+": %d evacuated / %d stranded" % [evacuated,12-evacuated])
		lines.append(mission["machine"])
		lines.append(mission["feeder"])
	return lines

func annotate_historical_pages(pages: Array) -> Array:
	if campaign["deployment"] == 2:
		# The original opening is historical, not a new scene performed by replacements.
		for index in range(3): pages[index]["speaker"] = "DEPLOYMENT 1 TRANSCRIPT / "+pages[index]["speaker"]
	return pages

func roster_panel_snapshot() -> Dictionary:
	return ViewModels.roster_panel_snapshot(self)

func prepare_return_startup() -> void:
	if campaign_path == CAMPAIGN_SLOT: campaign_path = RETURN_CAMPAIGN

func initialize_return(resume: bool) -> void:
	report_path = "user://holdfast_d1_result.save"
	completion_path = "user://holdfast_d1_completed.save"
	if return_state["active"]: configure_return()
	if resume:
		if FileAccess.file_exists(campaign_path): load_encounter(campaign_path)
		elif FileAccess.file_exists(CAMPAIGN_SLOT): load_encounter(CAMPAIGN_SLOT)
	save_feedback = "D1: K save / L load. G roster; return map uses the original machine outcome."

func restore_return_state(snapshot: Dictionary) -> void:
	campaign_state.restore_return(snapshot["return_map"])

func configure_return() -> void:
	opening_done = true
	opening_step = 2
	scene_view = ""
	# A stationary retained asset or an empty footprint; no new enemy is implied.
	enemies[0]["hp"] = 16 if ["diverted","disabled"].has(return_state["source"]) else 0
	machine["pending_shot"] = NONE
	status_text = "Return to Farm Road: civilians exit north at (10,1). Manual route always available."

func cooling_ready() -> bool:
	return return_state["source"] == "diverted" or (return_state["source"] == "disabled" and return_state["repair"] == 2)

func return_scene_path() -> String:
	return "res://farm_final.tscn"

func replace_return_attempt(next: Dictionary, state: Dictionary) -> bool:
	var fresh = load(return_scene_path()).instantiate()
	fresh.auto_resume = false
	fresh.campaign = next
	fresh.return_state = state
	fresh.campaign_path = campaign_path
	fresh.preference = preference
	get_parent().add_child(fresh)
	fresh.report_path = report_path
	fresh.completion_path = completion_path
	var problem: String = fresh.checkpoint()
	if problem != "":
		fresh.queue_free()
		result_feedback = problem
		queue_redraw()
		return false
	if get_tree().current_scene == self: get_tree().current_scene = fresh
	queue_free()
	return true

func activate_return_staging() -> void:
	last_enemy_phase = phase
	enemy_message = "Return staging: no hostile activation. North access closes after round 10."

func repair_return_machine() -> bool:
	if ended or return_state["source"] != "disabled" or return_state["repair"] == 2:
		status_text = "Repairs apply only to the retained disabled machine, once per step."
	elif not soldier_can_act(active_soldier) or soldiers[active_soldier]["ap"] < 1:
		status_text = "Select an active soldier with 1 AP."
	elif soldiers[active_soldier]["carrying"] >= 0:
		status_text = "Put down the casualty before repairing machinery."
	elif (soldiers[active_soldier]["cell"]-REPAIR_CELL).abs().x+(soldiers[active_soldier]["cell"]-REPAIR_CELL).abs().y != 1:
		status_text = "Stand adjacent to the retained machine at (10,8)."
	else:
		soldiers[active_soldier]["ap"] -= 1
		return_state["repair"] += 1
		status_text = "Repair %d/2 complete for 1 AP. %s" % [return_state["repair"],"Cooling route and one free move available." if cooling_ready() else "One more adjacent action required; another soldier may finish."]
		rebuild_movement()
		return true
	queue_redraw()
	return false

func use_cooling_move() -> bool:
	if ended or not return_state["active"] or not cooling_ready() or return_state["bonus_event"] != "":
		status_text = "Cooling move unavailable or already used."
		queue_redraw()
		return false
	var cohort: Dictionary = cohorts[cohort_selected]
	if cohort["status"] != "active" or cohort["order"] == "hold":
		status_text = "Select an active civilian group and give it an evacuation order first."
		queue_redraw()
		return false
	var before: Vector2i = cohort["cell"]
	move_cohort(cohort,3)
	if cohort["cell"] == before:
		status_text = "No safe movement available; cooling move retained."
		queue_redraw()
		return false
	return_state["bonus_event"] = "return-cooling-move-1"
	return_state["bonus_group"] = cohort["id"]
	status_text = "Cooling-assisted move used by group %s: up to 3 squares, no AP. One use per return." % cohort["id"]
	queue_redraw()
	return true

func reject_return_fire() -> bool:
	status_text = "No hostile targets in this return-map test."
	queue_redraw()
	return false

func reject_return_protocol() -> bool:
	status_text = "Original protocol outcome retained. Use I to repair or Y for the cooling move."
	queue_redraw()
	return false

func record_return_result() -> void:
	if return_state["active"] and campaign["committed"]:
		campaign["missions"][-1]["return_map"] = return_state.duplicate(true)

func return_debrief_pages() -> Array:
	return [{"speaker":"FARM ROAD RETURN / VERIFIED REPORT","text":report_text(),"tag":"Return-map outcomes; original losses remain recorded."},
		{"speaker":"STAGING RECORD","text":machine_outcome()+"\n\n"+feeder_result()+"\n\n"+("One cooling move used by group %s." % return_state["bonus_group"] if return_state["bonus_event"] != "" else "No cooling move used.")+"\n\nRepairs restore a function. They do not restore the original casualties.","tag":"Earlier choice / observed playable consequence"}]

func return_log_pages() -> Array:
	var pages: Array = [{"speaker":"FARM ROAD RETURN / EARLIER RECORD","text":"Original machine: %s.\n\n%s\n\nManual route: waypoint (5,4).\nCooling route: waypoint (10,4), when available.\nCivilian exit: north service tunnel (10,1).\n\nDisabled machinery needs two adjacent 1-AP repairs.\nCooling provides one free move of up to three cells." % [return_state["source"],feeder_result()],"tag":"Original losses persist; this test changes route and repair work."}]
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func return_overlay_snapshot() -> Dictionary:
	return ViewModels.return_overlay_snapshot(self)

func ending_available() -> bool:
	return result_ready and return_state["active"] and not retry_required() and campaign["committed"]

func open_ending_test() -> bool:
	if not ending_available(): return false
	var test = load("res://ending_test.tscn").instantiate()
	test.source_snapshot = encounter_snapshot()
	test.return_board = self
	get_parent().add_child(test)
	hide()
	set_process_unhandled_input(false)
	return true

func ending_overlay_snapshot() -> Dictionary:
	return ViewModels.ending_overlay_snapshot(self)

func encounter_slot(path: String) -> String:
	if [SaveStore.SAVE_PATH,FARM_SLOT,EVAC_SLOT,OPTIONS_SLOT,PROTOCOL_SLOT,RESCUE_SLOT,
		RESULT_SLOT,STORY_SLOT,TACTICAL_SLOT].has(path):
		return rescue_slot()
	return path
