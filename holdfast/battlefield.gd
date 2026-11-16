extends Node2D
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
var shot_rng := RandomNumberGenerator.new()
var shot_history: Array[Dictionary] = []
# A5 test enemy: stationary, nearest visible active target, roster-order ties.
var enemies: Array[Dictionary] = [{"cell": Vector2i.ZERO, "hp": 8, "ammo": 4}]
var last_enemy_phase := 0
var enemy_message := "Enemy has not acted yet."
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
var soldiers: Array[Dictionary] = [
	{"name": "MSG", "mark": "M", "cell": Vector2i.ZERO, "ap": 2, "ammo": 4, "attacked": false, "hp": 8, "extracted": false},
	{"name": "Ortiz", "mark": "O", "cell": Vector2i.ZERO, "ap": 2, "ammo": 4, "attacked": false, "hp": 8, "extracted": false},
	{"name": "Bell", "mark": "B", "cell": Vector2i.ZERO, "ap": 2, "ammo": 4, "attacked": false, "hp": 8, "extracted": false},
	{"name": "Park", "mark": "P", "cell": Vector2i.ZERO, "ap": 2, "ammo": 4, "attacked": false, "hp": 8, "extracted": false}
]
var active_soldier := -1
var hovered_cell := NONE
var distances: Dictionary = {}
var parents: Dictionary = {}
var phase := 1
const NEXT_PHASE_RECT := Rect2(668, 880, 156, 40)
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
	shot_rng.seed = COMBAT_SEED
	board_projection = GridProjection.new(GRID_ORIGIN,Vector2(CELL_SIZE,0),Vector2(0,CELL_SIZE))
	for index in range(soldiers.size()):
		soldiers[index]["cell"] = mission_definition().squad_spawns[index]
	enemies[0]["cell"] = mission_definition().machine_spawn
	enemies[0]["hp"] = mission_definition().machine_hp

func encounter_snapshot() -> Dictionary:
	return {"layout": "gdd3.1-a5-10x7", "combat": combat_snapshot(),
		"ui": {"active": active_soldier, "selected": selected_cell,
			"pinned": pinned_target, "sight": sight_mode, "status": status_text}}

func save_encounter(path: String = SaveStore.SAVE_PATH) -> bool:
	# Actions and enemy turns resolve synchronously: inputs only run at stable boundaries.
	var error := SaveStore.save(encounter_snapshot(), path)
	save_feedback = "Saved phase %d. This slot survives restarting the project." % phase if error == "" else error
	queue_redraw()
	return error == ""

func load_encounter(path: String = SaveStore.SAVE_PATH) -> bool:
	var result := SaveStore.load_snapshot(path)
	if result["error"] != "":
		save_feedback = result["error"]
		queue_redraw()
		return false
	var snapshot: Dictionary = result["snapshot"]
	if snapshot["layout"] != encounter_snapshot()["layout"]:
		save_feedback = "Save belongs to another encounter. Current encounter unchanged."
		queue_redraw()
		return false
	var ui: Dictionary = snapshot["ui"]
	active_soldier = ui["active"]
	restore_combat(snapshot["combat"])
	selected_cell = ui["selected"]
	pinned_target = ui["pinned"]
	sight_mode = ui["sight"]
	status_text = ui["status"]
	hovered_cell = NONE
	save_feedback = "Loaded phase %d. Repeat the same action for the same result." % phase
	queue_redraw()
	return true

func soldier_can_act(index: int) -> bool:
	return index >= 0 and index < soldiers.size() and not soldiers[index]["extracted"] and soldiers[index]["hp"] > 0

func all_extracted() -> bool:
	for soldier in soldiers:
		if not soldier["extracted"]:
			return false
	return true

func extraction_cell(cell: Vector2i) -> bool:
	return MissionObjectives.squad_exit(mission_definition(),cell)

func try_extract() -> bool:
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
	if enemies.is_empty() or enemies[0]["hp"] <= 0:
		return -1
	var best := -1
	var nearest := 999
	for index in range(soldiers.size()):
		if not soldier_can_act(index):
			continue
		var info := sight_preview(enemies[0]["cell"], soldiers[index]["cell"])
		if info["can_fire"] and info["distance"] < nearest:
			best = index
			nearest = info["distance"]
	return best

func enemy_intent() -> String:
	if enemies.is_empty() or enemies[0]["hp"] <= 0:
		return "Enemy defeated. Extraction remains available."
	if all_extracted():
		return "All soldiers safely extracted."
	if enemies[0]["ammo"] == 0:
		return "Enemy next: reload; no shot this turn."
	var index := enemy_target()
	if index < 0:
		return "Enemy next: hold (no active soldier in sight and rifle range)."
	var info := sight_preview(enemies[0]["cell"], soldiers[index]["cell"])
	return "Enemy next: fire at %s | %d%% | range %+d, cover %+d" % [soldiers[index]["name"], info["chance"], info["range_modifier"], info["cover_modifier"]]

func resolve_enemy_turn() -> void:
	if last_enemy_phase == phase:
		return
	last_enemy_phase = phase
	if enemies.is_empty() or enemies[0]["hp"] <= 0 or all_extracted():
		enemy_message = "Enemy: no action."
		return
	var enemy: Dictionary = enemies[0]
	if enemy["ammo"] == 0:
		enemy["ammo"] = 4
		enemy_message = "Enemy reloaded; no shot this turn."
		return
	var index := enemy_target()
	if index < 0:
		enemy_message = "Enemy held: no active soldier in sight and range."
		return
	var info := sight_preview(enemy["cell"], soldiers[index]["cell"])
	var state_before := shot_rng.state
	var roll := shot_rng.randi_range(1, 100)
	var damage := 4 if roll <= info["chance"] else 0
	enemy["ammo"] -= 1
	soldiers[index]["hp"] = maxi(0, soldiers[index]["hp"] - damage)
	if soldiers[index]["hp"] == 0:
		soldiers[index]["ap"] = 0
	shot_history.append({"phase": phase, "actor": "enemy", "soldier": index,
		"target": soldiers[index]["cell"], "chance": info["chance"], "roll": roll,
		"damage": damage, "rng_before": state_before, "rng_after": shot_rng.state})
	enemy_message = "Enemy → %s: %s, %d damage; HP %d/8 (roll %d / %d%%)." % [soldiers[index]["name"], "HIT" if damage > 0 else "MISS", damage, soldiers[index]["hp"], roll, info["chance"]]
	if not soldier_can_act(active_soldier):
		active_soldier = -1
		selected_cell = NONE

func target_at(cell: Vector2i) -> int:
	for index in range(enemies.size()):
		if enemies[index]["cell"] == cell and enemies[index]["hp"] > 0:
			return index
	return -1

func fire_block_reason() -> String:
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
	var reason := fire_block_reason()
	if reason != "":
		status_text = reason
		queue_redraw()
		return false
	var soldier: Dictionary = soldiers[active_soldier]
	var info := sight_preview(soldier["cell"], pinned_target)
	var target_index := target_at(pinned_target)
	var state_before := shot_rng.state
	var roll := shot_rng.randi_range(1, 100)
	var hit: bool = roll <= info["chance"]
	soldier["ap"] -= 1
	soldier["ammo"] -= 1
	soldier["attacked"] = true
	var damage := 4 if hit else 0
	enemies[target_index]["hp"] = maxi(0, enemies[target_index]["hp"] - damage)
	shot_history.append({"phase": phase, "soldier": active_soldier, "target": pinned_target,
		"chance": info["chance"], "roll": roll, "damage": damage,
		"rng_before": state_before, "rng_after": shot_rng.state})
	status_text = "%s: %s (roll %d vs %d%%), %d damage. Target HP %d/8." % [soldier["name"], "HIT" if hit else "MISS", roll, info["chance"], damage, enemies[target_index]["hp"]]
	rebuild_movement()
	return true

func try_reload() -> bool:
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
	return {"soldiers": soldiers.duplicate(true), "targets": enemies.duplicate(true),
		"phase": phase, "rng_seed": shot_rng.seed, "rng_state": shot_rng.state, "history": shot_history.duplicate(true),
		"last_enemy_phase": last_enemy_phase, "enemy_message": enemy_message}

func restore_combat(snapshot: Dictionary) -> void:
	soldiers.assign(snapshot["soldiers"].duplicate(true))
	enemies.assign(snapshot["targets"].duplicate(true))
	phase = snapshot["phase"]
	last_enemy_phase = snapshot["last_enemy_phase"]
	enemy_message = snapshot["enemy_message"]
	shot_rng.seed = snapshot["rng_seed"]
	shot_rng.state = snapshot["rng_state"]
	shot_history.assign(snapshot["history"].duplicate(true))
	if active_soldier >= 0:
		selected_cell = soldiers[active_soldier]["cell"]
	rebuild_movement()

func cell_is_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= GRID_SIZE.x and cell.y >= 1 and cell.y <= GRID_SIZE.y

func is_walkable(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or target_at(cell) >= 0:
		return false
	for soldier in soldiers:
		if not soldier["extracted"] and soldier["hp"] <= 0 and soldier["cell"] == cell:
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
	for i in range(soldiers.size()):
		if not soldiers[i]["extracted"] and soldiers[i]["cell"] == cell:
			return i
	return -1

func rebuild_movement() -> void:
	distances.clear()
	parents.clear()
	if not soldier_can_act(active_soldier):
		queue_redraw()
		return
	var origin: Vector2i = soldiers[active_soldier]["cell"]
	var budget: int = soldiers[active_soldier]["ap"] * 4
	var frontier: Array[Vector2i] = [origin]
	distances[origin] = 0
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		if distances[cell] >= budget:
			continue
		for direction in DIRECTIONS:
			var neighbor := cell + direction
			if not is_walkable(neighbor) or distances.has(neighbor):
				continue
			distances[neighbor] = distances[cell] + 1
			parents[neighbor] = cell
			frontier.append(neighbor)
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
	if all_extracted():
		status_text = "All soldiers extracted. Restart the scene to play again."
		queue_redraw()
		return
	resolve_enemy_turn()
	phase += 1
	for index in range(soldiers.size()):
		if soldier_can_act(index):
			soldiers[index]["ap"] = 2
			soldiers[index]["attacked"] = false
	status_text = "Player phase %d: active soldiers have 2 AP and a fresh attack." % phase
	rebuild_movement()

func toggle_sight() -> void:
	sight_mode = not sight_mode
	status_text = "Aim: click the enemy to pin it, review the chance, then press F to fire." if sight_mode else "Movement mode. Click a destination to move."
	queue_redraw()

func sight_target() -> Vector2i:
	return pinned_target if pinned_target != NONE else hovered_cell

func _unhandled_input(event: InputEvent) -> void:
	var command := TacticalInput.key_command(event)
	if command != "":
		run_tactical_command(command)
	if event is InputEventMouse:
		var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		hovered_cell = local_to_cell(local_position)
		queue_redraw()
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			command = TacticalInput.button_command(local_position,tactical_buttons())
			if command != "":
				run_tactical_command(command)
				return
			if not cell_is_in_bounds(hovered_cell):
				return
			if sight_mode and active_soldier >= 0:
				pinned_target = hovered_cell if pinned_target != hovered_cell else NONE
				return
			var index := soldier_at(hovered_cell)
			if index >= 0:
				select_soldier(index)
			elif active_soldier >= 0:
				try_move(hovered_cell)
			else:
				try_select_cell(hovered_cell)

func soldier_role(index: int) -> String:
	return {"MSG":"PSYOP", "Ortiz":"MEDIC", "Bell":"ENGINEER", "Park":"RECON"}.get(soldiers[index]["name"], "RIFLE")

func soldier_color(index: int) -> Color:
	return [Color("e9c66a"),Color("8ce0c1"),Color("8fb9ff"),Color("d7a2ed")][index % 4]

func draw_soldier_marker(index: int, center: Vector2) -> void:
	ActorView.soldier(self,font,center,soldier_marker_snapshot(index))

func _draw() -> void:
	SceneChrome.sandbox_header(self,font)
	BoardView.render(self,font,board_projection,board_view_snapshot())
	var path: Array[Vector2i] = []
	if not sight_mode:
		path = path_to(hovered_cell)
	var target := sight_target()
	OverlayView.render(self,board_projection,tactical_overlay_snapshot(path,target))
	draw_targets()
	for i in range(soldiers.size()):
		if not soldier_visible(i):
			continue
		var center := cell_to_local(soldiers[i]["cell"]) + Vector2(18, 18)
		draw_soldier_marker(i, center)
	TacticalPanel.render(self,font,board_projection,tactical_panel_snapshot(path,target))

func draw_targets() -> void:
	for dummy in enemies:
		var center := cell_to_local(dummy["cell"]) + Vector2(18, 18)
		if dummy["hp"] <= 0:
			draw_string(font, center + Vector2(-12, 6), "—", HORIZONTAL_ALIGNMENT_CENTER, 24, 18, Color("7a827e"))
			continue
		draw_circle(center, 13, Color("b14e4b"))
		draw_string(font, center + Vector2(-12, 6), "E", HORIZONTAL_ALIGNMENT_CENTER, 24, 18, Color.WHITE)
		draw_string(font, center + Vector2(7, -7), str(dummy["hp"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func soldier_visible(index: int) -> bool:
	return not soldiers[index]["extracted"]

func mission_definition() -> Resource:
	return mission_override if mission_override != null else SandboxMission

func sight_preview(shooter: Vector2i, target: Vector2i) -> Dictionary:
	return Rules.preview(shooter,target,mission_definition())

func board_view_snapshot() -> Dictionary:
	var costs := {}
	if not sight_mode:
		for y in range(1,GRID_SIZE.y+1):
			for x in range(1,GRID_SIZE.x+1):
				var cell := Vector2i(x,y)
				var cost := move_cost(cell)
				if cost > 0: costs[cell] = cost
	return {"size":GRID_SIZE,"cell_size":CELL_SIZE,"origin":GRID_ORIGIN,
		"walls":WALL_CELLS.duplicate(),"exits":mission_definition().squad_exits.duplicate(),
		"selected":selected_cell,"costs":costs}

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
	return {"shape":index%4,"mark":soldiers[index]["mark"],"selected":index==active_soldier,
		"color":soldier_color(index) if soldiers[index]["hp"] > 0 else Color("b36b6b")}

func tactical_overlay_snapshot(path: Array[Vector2i], target: Vector2i) -> Dictionary:
	var aim := {}
	if sight_mode and active_soldier >= 0 and cell_is_in_bounds(target):
		var source: Vector2i = soldiers[active_soldier]["cell"]
		var info := sight_preview(source,target)
		aim = {"source":source,"target":target,"cells":info["cells"].duplicate(),
			"blockers":info["blockers"].duplicate(),"clear":info["clear"],"protected":info["protected"]}
	return {"path":path.duplicate(),"aim":aim,"cover":mission_definition().cover_edges.duplicate(true),"cell_size":CELL_SIZE}

func tactical_panel_snapshot(path: Array[Vector2i], target: Vector2i) -> Dictionary:
	var roles := []
	var colors := []
	for index in range(soldiers.size()):
		roles.append(soldier_role(index))
		colors.append(soldier_color(index))
	return {
		"active_soldier":active_soldier,
		"selected_cell":selected_cell,
		"NONE":NONE,
		"hovered_cell":hovered_cell,
		"sight_mode":sight_mode,
		"pinned_target":pinned_target,
		"status_text":status_text,
		"phase":phase,
		"enemy_message":enemy_message,
		"save_feedback":save_feedback,
		"NEXT_PHASE_RECT":NEXT_PHASE_RECT,
		"MODE_RECT":MODE_RECT,
		"FIRE_RECT":FIRE_RECT,
		"RELOAD_RECT":RELOAD_RECT,
		"EXTRACT_RECT":EXTRACT_RECT,
		"SAVE_RECT":SAVE_RECT,
		"LOAD_RECT":LOAD_RECT,
		"soldiers":soldiers.duplicate(true),
		"path":path.duplicate(),
		"target":target,
		"cost":move_cost(hovered_cell),
		"valid_target":cell_is_in_bounds(target),
		"info":sight_preview(soldiers[active_soldier]["cell"],target).duplicate(true) if active_soldier >= 0 and cell_is_in_bounds(target) else {},
		"roles":roles,
		"colors":colors,
		"intent":enemy_intent(),
		"fire_reason":fire_block_reason()}

func interaction_command(event: InputEvent, keys: Dictionary, buttons: Dictionary, rows: Array = []) -> String:
	var point := Vector2.ZERO
	if event is InputEventMouse: point = get_global_transform_with_canvas().affine_inverse()*event.position
	return InteractionInput.command(event,point,keys,buttons,rows)
