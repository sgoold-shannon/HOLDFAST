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
const RescueActions = preload("res://systems/rescue_actions.gd")
const MachineControls = preload("res://systems/machine_controls.gd")
const StoryFlow = preload("res://systems/story_flow.gd")
const CampaignFlow = preload("res://systems/campaign_flow.gd")
const ReturnMission = preload("res://systems/return_mission.gd")
const CivilianOrders = preload("res://systems/civilian_orders.gd")
const MissionResults = preload("res://systems/mission_results.gd")
const MachineTurn = preload("res://systems/machine_turn.gd")
const SquadActions = preload("res://systems/squad_actions.gd")
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
	return SquadActions.try_extract(self)

func extract_selected_soldier() -> bool:
	return SquadActions.extract_selected_soldier(self)

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
	return SquadActions.rifle_block_reason(self)

func try_fire() -> bool:
	return SquadActions.try_fire(self)

func try_reload() -> bool:
	return SquadActions.try_reload(self)

func reload_selected_soldier() -> bool:
	return SquadActions.reload_selected_soldier(self)

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
	return SquadActions.try_select_cell(self, cell)

func soldier_at(cell: Vector2i) -> int:
	for index in range(soldiers.size()):
		if soldier_visible(index) and soldiers[index].get("condition","active") != "dead" and soldiers[index]["cell"] == cell:
			return index
	return -1

func rebuild_movement() -> void:
	refresh_tactical_movement()
	limit_carrier_movement()

func refresh_tactical_movement() -> void:
	return SquadActions.refresh_tactical_movement(self)

func move_cost(cell: Vector2i) -> int:
	return SquadActions.move_cost(self, cell)

func path_to(cell: Vector2i) -> Array[Vector2i]:
	return SquadActions.path_to(self, cell)

func select_soldier(index: int) -> void:
	return SquadActions.select_soldier(self, index)

func try_move(cell: Vector2i) -> bool:
	return SquadActions.try_move(self, cell)

func move_selected_soldier(cell: Vector2i) -> bool:
	return SquadActions.move_selected_soldier(self, cell)

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
	return SquadActions.toggle_sight(self)

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
	return SquadActions.run_tactical_command(self, command)

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
	return MachineTurn.origin_machine_intent(self)

func danger_summary() -> String:
	return MachineTurn.danger_summary(self)

func cell_occupied_by_people(cell: Vector2i) -> bool:
	if soldier_at(cell) >= 0: return true
	for cohort in cohorts:
		if cohort["status"] == "active" and cohort["cell"] == cell: return true
	return false

func damage_cell(cell: Vector2i, amount: int) -> String:
	return MachineTurn.damage_cell(self, cell, amount)

func activate_origin_machine() -> void:
	return MachineTurn.activate_origin_machine(self)

func fire_at_machine() -> bool:
	return MachineTurn.fire_at_machine(self)

func machine_track() -> Array[Vector2i]:
	if return_state["active"]:
		var empty: Array[Vector2i] = []
		return empty
	return mission_definition().machine_display_track

func skid_visible() -> bool:
	if return_state["active"]: return not campaign["missions"][0]["feeder"].contains("severed")
	return machine["collected_round"] == 0

func machine_plan() -> Dictionary:
	return MachineTurn.machine_plan(self)

func machine_path(start: Vector2i, goal: Vector2i, avoid_people: bool) -> Array[Vector2i]:
	return MachineTurn.machine_path(self, start, goal, avoid_people)

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
	return CivilianOrders.remaining_civilians(self)

func civilian_waypoint(order: String) -> Vector2i:
	return CivilianOrders.civilian_waypoint(self, order)

func order_cohort(index: int, order: String) -> bool:
	return CivilianOrders.order_cohort(self, index, order)

func issue_civilian_order(index: int, order: String) -> bool:
	return CivilianOrders.issue_civilian_order(self, index, order)

func issue_authority_order(index: int, order: String) -> bool:
	return CivilianOrders.issue_authority_order(self, index, order)

func calm_cohort(index: int) -> bool:
	return CivilianOrders.calm_cohort(self, index)

func civilian_threats() -> Array[Vector2i]:
	return CivilianOrders.civilian_threats(self)

func route_label(order: String) -> String:
	return CivilianOrders.route_label(self, order)

func route_available(order: String) -> bool:
	return not (return_state["active"] and order == "north" and not cooling_ready())

func route_preview(cohort: Dictionary, order: String) -> Array[Vector2i]:
	return evacuation_rules.route_preview(cohort, order, soldiers)

func order_exit(index: int) -> bool:
	return CivilianOrders.order_exit(self, index)

func cohort_order_label(cohort: Dictionary) -> String:
	return CivilianOrders.cohort_order_label(self, cohort)

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
	return CivilianOrders.resolve_civilian_phase(self)

func resolve_authority_civilians() -> void:
	return CivilianOrders.resolve_authority_civilians(self)

func move_cohort(cohort: Dictionary, budget: int) -> void:
	evacuation_rules.move_cohort(cohort, budget, soldiers)

func finish_operation(reason: String) -> void:
	return CivilianOrders.finish_operation(self, reason)

func close_evacuation(reason: String) -> void:
	return CivilianOrders.close_evacuation(self, reason)

func request_close() -> bool:
	return CivilianOrders.request_close(self)

func before_turn_resolution() -> bool:
	return resolve_bleeding()

func prepare_machine_phase() -> void:
	close_pending = false

func after_turn_resolution() -> void:
	check_recovery_failure()
	finalize_result()
	update_closure_knowledge()

func begin_player_phase() -> void:
	return SquadActions.begin_player_phase(self)

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
	return MachineControls.origin_breaker_reason(self)

func try_breaker(confirm: bool = false) -> bool:
	if return_state["active"]: return repair_return_machine()
	return operate_origin_breaker(confirm)

func operate_origin_breaker(confirm: bool = false) -> bool:
	return MachineControls.operate_origin_breaker(self, confirm)

func blast_victims() -> String:
	return MachineTurn.blast_victims(self)

func machine_outcome() -> String:
	if return_state["active"]:
		return "Return: original %s / %s" % [return_state["source"],"cooling available" if cooling_ready() else ("repair %d/2" % return_state["repair"] if return_state["source"] == "disabled" else "manual route")]
	if enemies[0]["hp"] > 0 and not disabled() and protocol["diverted"]:
		return "Diverted | cooling preserved | skid and feeder intact"
	return origin_machine_outcome()

func origin_machine_outcome() -> String:
	return MachineTurn.origin_machine_outcome(self)

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
	return MachineControls.origin_protocol_reason(self, action)

func protocol_action(action: String) -> bool:
	if return_state["active"]: return reject_return_protocol()
	var success := execute_protocol_action(action)
	update_protocol_observation(action,success)
	return success

func execute_protocol_action(action: String) -> bool:
	return MachineControls.execute_protocol_action(self, action)

func apply_protocol_betrayal(fired: bool, was_diverted: bool) -> void:
	return MachineControls.apply_protocol_betrayal(self, fired, was_diverted)

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
	return RescueActions.kill_soldier(self, index)

func apply_casualty_damage(cell: Vector2i, amount: int) -> String:
	return RescueActions.apply_casualty_damage(self, cell, amount)

func resolve_bleeding() -> bool:
	return RescueActions.resolve_bleeding(self)

func casualty_available(index: int) -> bool:
	return RescueActions.casualty_available(self, index)

func casualty_in_reach(index: int) -> bool:
	return RescueActions.casualty_in_reach(self, index)

func target_for_rescue() -> int:
	return RescueActions.target_for_rescue(self)

func try_stabilize() -> bool:
	return RescueActions.try_stabilize(self)

func stabilize_casualty() -> bool:
	return RescueActions.stabilize_casualty(self)

func try_pickup() -> bool:
	return RescueActions.try_pickup(self)

func pick_up_casualty() -> bool:
	return RescueActions.pick_up_casualty(self)

func request_drop() -> void:
	return RescueActions.request_drop(self)

func try_drop(cell: Vector2i) -> bool:
	return RescueActions.try_drop(self, cell)

func limit_carrier_movement() -> void:
	return RescueActions.limit_carrier_movement(self)

func close_rescue() -> void:
	return RescueActions.close_rescue(self)

func cycle_casualty() -> void:
	return RescueActions.cycle_casualty(self)

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
	return MissionResults.check_recovery_failure(self)

func finalize_result() -> void:
	return MissionResults.finalize_result(self)

func close_result_operation(reason: String) -> void:
	return MissionResults.close_result_operation(self, reason)

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
	return MissionResults.recorded_soldier_disposition(self, index)

func feeder_result() -> String:
	if return_state["active"]: return "Original record: "+campaign["missions"][0]["feeder"]
	return origin_feeder_result()

func origin_feeder_result() -> String:
	return MissionResults.origin_feeder_result(self)

func evacuated_people() -> int:
	return MissionResults.evacuated_people(self)

func result_title() -> String:
	return MissionResults.result_title(self)

func restart_attempt() -> void:
	return MissionResults.restart_attempt(self)

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
	return StoryFlow.apply_rescue_knowledge(self, actor)

func update_closure_knowledge() -> void:
	return StoryFlow.update_closure_knowledge(self)

func update_protocol_observation(action: String, success: bool) -> void:
	return MachineControls.update_protocol_observation(self, action, success)

func present(index: int) -> bool:
	return StoryFlow.present(self, index)

func original_actor(index: int, original_name: String) -> bool:
	return StoryFlow.original_actor(self, index, original_name)

func knows(index: int, fact: String) -> bool:
	return StoryFlow.knows(self, index, fact)

func deliver_briefing() -> void:
	return StoryFlow.deliver_briefing(self)

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
	return StoryFlow.opening_pages(self)

func report_text() -> String:
	return StoryFlow.report_text(self)

func evidence_pages() -> Array:
	return StoryFlow.evidence_pages(self)

func debrief_pages() -> Array:
	return return_debrief_pages() if return_state["active"] else origin_debrief_pages()

func origin_debrief_pages() -> Array:
	return StoryFlow.origin_debrief_pages(self)

func response_line(value: String) -> String:
	return StoryFlow.response_line(self, value)

func choose_opening(value: String) -> void:
	return StoryFlow.choose_opening(self, value)

func finish_opening() -> void:
	if preference == "unset": preference = "skipped"
	opening_done = true
	opening_step = 2
	scene_view = ""
	save_feedback = "C1: Tab scene log / intelligence. K save / L load."
	queue_redraw()

func begin_debrief() -> bool:
	return StoryFlow.begin_debrief(self)

func choose_response(value: String) -> void:
	return StoryFlow.choose_response(self, value)

func log_pages() -> Array:
	return return_log_pages() if return_state["active"] else annotate_historical_pages(origin_log_pages())

func origin_log_pages() -> Array:
	return StoryFlow.origin_log_pages(self)

func current_pages() -> Array:
	return StoryFlow.current_pages(self)

func toggle_log() -> void:
	return StoryFlow.toggle_log(self)

func advance_scene() -> void:
	if return_state["active"] and scene_view == "debrief":
		if scene_page == 0: scene_page = 1
		else:
			deliver_briefing()
			scene_view = ""
		queue_redraw()
	else: advance_origin_scene()

func advance_origin_scene() -> void:
	return StoryFlow.advance_origin_scene(self)

func choose_scene_option(index: int) -> void:
	if not return_state["active"]: choose_origin_scene_option(index)

func choose_origin_scene_option(index: int) -> void:
	return StoryFlow.choose_origin_scene_option(self, index)

func scene_options() -> Array:
	return [] if return_state["active"] else origin_scene_options()

func origin_scene_options() -> Array:
	return StoryFlow.origin_scene_options(self)

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
	return CampaignFlow.apply_assignments(self)

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
	return CampaignFlow.sync_knowledge(self)

func commit_roster() -> void:
	return CampaignFlow.commit_roster(self)

func record_campaign_result() -> void:
	return CampaignFlow.record_campaign_result(self)

func persist_campaign_result() -> void:
	return CampaignFlow.persist_campaign_result(self)

func can_receive_staging_care() -> bool:
	return CampaignFlow.can_receive_staging_care(self)

func provide_staging_care() -> bool:
	return CampaignFlow.provide_staging_care(self)

func can_deploy() -> bool:
	return CampaignFlow.can_deploy(self)

func start_second_deployment() -> bool:
	return CampaignFlow.start_second_deployment(self)

func open_roster() -> void:
	return CampaignFlow.open_roster(self)

func roster_details(actor: Dictionary) -> Array[String]:
	return CampaignFlow.roster_details(self, actor)

func annotate_historical_pages(pages: Array) -> Array:
	return CampaignFlow.annotate_historical_pages(self, pages)

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
	return ReturnMission.configure_return(self)

func cooling_ready() -> bool:
	return return_state["source"] == "diverted" or (return_state["source"] == "disabled" and return_state["repair"] == 2)

func return_scene_path() -> String:
	return "res://farm_final.tscn"

func replace_return_attempt(next: Dictionary, state: Dictionary) -> bool:
	return ReturnMission.replace_return_attempt(self, next, state)

func activate_return_staging() -> void:
	return ReturnMission.activate_return_staging(self)

func repair_return_machine() -> bool:
	return ReturnMission.repair_return_machine(self)

func use_cooling_move() -> bool:
	return ReturnMission.use_cooling_move(self)

func reject_return_fire() -> bool:
	return ReturnMission.reject_return_fire(self)

func reject_return_protocol() -> bool:
	return ReturnMission.reject_return_protocol(self)

func record_return_result() -> void:
	return ReturnMission.record_return_result(self)

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
	return ReturnMission.open_ending_test(self)

func ending_overlay_snapshot() -> Dictionary:
	return ViewModels.ending_overlay_snapshot(self)

func encounter_slot(path: String) -> String:
	if [SaveStore.SAVE_PATH,FARM_SLOT,EVAC_SLOT,OPTIONS_SLOT,PROTOCOL_SLOT,RESCUE_SLOT,
		RESULT_SLOT,STORY_SLOT,TACTICAL_SLOT].has(path):
		return rescue_slot()
	return path
