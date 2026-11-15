extends Node2D
## HOLDFAST A6. Public cell coordinates follow GDD v3.1 section 26 (one-based).
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
var enemies: Array[Dictionary] = [{"cell": Vector2i(10, 7), "hp": 8, "ammo": 4}]
var last_enemy_phase := 0
var enemy_message := "Enemy has not acted yet."
const EXTRACT_RECT := Rect2(40, 1020, 200, 40)

var sight_mode := false
var pinned_target := Vector2i(-1, -1)
const MODE_RECT := Rect2(480, 880, 178, 40)
const GRID_SIZE := Vector2i(20, 16)
const CELL_SIZE := 36.0
const GRID_ORIGIN := Vector2(72, 96)
const WALL_CELLS: Array[Vector2i] = [
	Vector2i(12, 5), Vector2i(12, 6), Vector2i(12, 8), Vector2i(12, 9)
]
const NONE := Vector2i(-1, -1)
var selected_cell := NONE
var status_text := "Click a ground cell to select it."
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]
var soldiers: Array[Dictionary] = [
	{"name": "MSG", "mark": "M", "cell": Vector2i(3, 6), "ap": 2, "ammo": 4, "attacked": false, "hp": 8, "extracted": false},
	{"name": "Ortiz", "mark": "O", "cell": Vector2i(3, 7), "ap": 2, "ammo": 4, "attacked": false, "hp": 8, "extracted": false},
	{"name": "Bell", "mark": "B", "cell": Vector2i(3, 9), "ap": 2, "ammo": 4, "attacked": false, "hp": 8, "extracted": false},
	{"name": "Park", "mark": "P", "cell": Vector2i(3, 10), "ap": 2, "ammo": 4, "attacked": false, "hp": 8, "extracted": false}
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
	return cell.x == 19 and cell.y >= 6 and cell.y <= 10

func try_extract() -> bool:
	if not soldier_can_act(active_soldier):
		status_text = "Select an active soldier to extract."
	elif not extraction_cell(soldiers[active_soldier]["cell"]):
		status_text = "Extraction zone: column 19, rows 6–10. Stand on an EXIT cell."
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
		var info := Rules.preview(enemies[0]["cell"], soldiers[index]["cell"])
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
	var info := Rules.preview(enemies[0]["cell"], soldiers[index]["cell"])
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
	var info := Rules.preview(enemy["cell"], soldiers[index]["cell"])
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
	var info := Rules.preview(soldier["cell"], pinned_target)
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
	var info := Rules.preview(soldier["cell"], pinned_target)
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
	var offset := point - GRID_ORIGIN
	return Vector2i(floori(offset.x / CELL_SIZE) + 1, floori(offset.y / CELL_SIZE) + 1)

func cell_to_local(cell: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(cell - Vector2i.ONE) * CELL_SIZE

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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			save_encounter()
		elif event.keycode == KEY_L:
			load_encounter()
		elif event.keycode == KEY_N:
			next_phase()
		elif event.keycode == KEY_E:
			try_extract()
		elif event.keycode == KEY_F:
			try_fire()
		elif event.keycode == KEY_R:
			try_reload()
		elif event.keycode == KEY_T:
			toggle_sight()
		elif event.keycode == KEY_ESCAPE:
			active_soldier = -1
			pinned_target = NONE
			status_text = "Selection cleared. Click a soldier or inspect a ground cell."
			rebuild_movement()
	if event is InputEventMouse:
		var local_position: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		hovered_cell = local_to_cell(local_position)
		queue_redraw()
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if SAVE_RECT.has_point(local_position):
				save_encounter()
				return
			if LOAD_RECT.has_point(local_position):
				load_encounter()
				return
			if EXTRACT_RECT.has_point(local_position):
				try_extract()
				return
			if FIRE_RECT.has_point(local_position):
				try_fire()
				return
			if RELOAD_RECT.has_point(local_position):
				try_reload()
				return
			if MODE_RECT.has_point(local_position):
				toggle_sight()
				return
			if NEXT_PHASE_RECT.has_point(local_position):
				next_phase()
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

func _draw() -> void:
	draw_string(font, Vector2(40, 36), "HOLDFAST  /  A6 SAVE & REPLAY", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e5e9e7"))
	draw_string(font, Vector2(40, 62), "T: move / aim | F: fire | R: reload | N: end turn | E: extract | Esc: clear", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("aebbb6"))
	for y in range(1, GRID_SIZE.y + 1):
		for x in range(1, GRID_SIZE.x + 1):
			var cell := Vector2i(x, y)
			var rect := Rect2(cell_to_local(cell), Vector2.ONE * CELL_SIZE)
			var fill := Color("24352e") if (x + y) % 2 == 0 else Color("293b33")
			var cost := 0 if sight_mode else move_cost(cell)
			if cost > 0:
				fill = Color("315b50") if cost == 1 else Color("304965")
			if WALL_CELLS.has(cell):
				fill = Color("66727b")
			draw_rect(rect, fill)
			draw_rect(rect, Color("42554a"), false, 1.0)
			if WALL_CELLS.has(cell):
				draw_line(rect.position + Vector2(10, 10), rect.end - Vector2(10, 10), Color("e4e8ec"), 2.0)
				draw_line(rect.position + Vector2(26, 10), rect.position + Vector2(10, 26), Color("e4e8ec"), 2.0)
			if cost > 0:
				draw_string(font, rect.position + Vector2(3, 13), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b7c9c0"))
			if extraction_cell(cell):
				draw_rect(rect.grow(-2), Color("8be6de"), false, 2)
				draw_string(font, rect.position + Vector2(0, 25), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, CELL_SIZE, 10, Color("8be6de"))
			if cell == selected_cell:
				draw_rect(rect.grow(-3), Color("f7cd6c"), false, 3.0)
	for x in range(1, GRID_SIZE.x + 1):
		draw_string(font, Vector2(GRID_ORIGIN.x + (x - 1) * CELL_SIZE, 85), str(x), HORIZONTAL_ALIGNMENT_CENTER, CELL_SIZE, 16, Color("d6ded9"))
	for y in range(1, GRID_SIZE.y + 1):
		draw_string(font, Vector2(31, GRID_ORIGIN.y + (y - 1) * CELL_SIZE + 24), str(y), HORIZONTAL_ALIGNMENT_RIGHT, 28, 16, Color("d6ded9"))
	var path: Array[Vector2i] = []
	if not sight_mode:
		path = path_to(hovered_cell)
	for i in range(1, path.size()):
		draw_line(cell_to_local(path[i - 1]) + Vector2(18, 18), cell_to_local(path[i]) + Vector2(18, 18), Color("f7cd6c"), 3.0)
	var target := sight_target()
	if sight_mode and active_soldier >= 0 and cell_is_in_bounds(target):
		var source: Vector2i = soldiers[active_soldier]["cell"]
		var info := Rules.preview(source, target)
		for cell in info["cells"]:
			draw_rect(Rect2(cell_to_local(cell) + Vector2(2, 2), Vector2(32, 32)), Color(0.85, 0.8, 0.4, 0.18))
		for cell in info["blockers"]:
			draw_rect(Rect2(cell_to_local(cell) + Vector2(2, 2), Vector2(32, 32)), Color("f27b79"), false, 3)
		draw_line(cell_to_local(source) + Vector2(18, 18), cell_to_local(target) + Vector2(18, 18), Color("9ae2c4") if info["clear"] else Color("f27b79"), 2)
		draw_rect(Rect2(cell_to_local(target) + Vector2(4, 4), Vector2(28, 28)), Color("ffffff"), false, 2)
	for cell in Rules.COVER:
		var origin := cell_to_local(cell)
		var edge_y: float = 2.0 if Rules.COVER[cell] == "north" else CELL_SIZE - 2.0
		var color := Color("7ed4ee")
		if sight_mode and active_soldier >= 0 and target == cell and Rules.preview(soldiers[active_soldier]["cell"], target)["protected"]:
			color = Color("f7cd6c")
		draw_line(origin + Vector2(3, edge_y), origin + Vector2(33, edge_y), color, 5)
	draw_targets()
	for i in range(soldiers.size()):
		if not soldier_visible(i):
			continue
		var center := cell_to_local(soldiers[i]["cell"]) + Vector2(18, 18)
		draw_circle(center, 13, Color("ab6767") if soldiers[i]["hp"] <= 0 else (Color("f7cd6c") if i == active_soldier else Color("d5e0d9")))
		draw_string(font, center + Vector2(-12, 6), soldiers[i]["mark"], HORIZONTAL_ALIGNMENT_CENTER, 24, 18, Color("16251e"))
	var selection := "Select a soldier  |  Green 1 = move  |  Blue 2 = dash"
	if active_soldier >= 0:
		var soldier: Dictionary = soldiers[active_soldier]
		selection = "%s | HP %d/8 | AP %d | Ammo %d | Attack %s | (%d,%d)" % [soldier["name"], soldier["hp"], soldier["ap"], soldier["ammo"], "used" if soldier["attacked"] else "ready", soldier["cell"].x, soldier["cell"].y]
	elif selected_cell != NONE:
		selection = "Selected ground (%d, %d)" % [selected_cell.x, selected_cell.y]
	draw_string(font, Vector2(40, 702), selection, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f7cd6c"))
	var preview := "Green 1: up to 4 squares / 1 AP. Blue 2: 5–8 squares / 2 AP."
	if path.size() > 0:
		preview = "Destination (%d, %d): %d orthogonal steps / %d AP" % [hovered_cell.x, hovered_cell.y, path.size() - 1, move_cost(hovered_cell)]
	if sight_mode:
		preview = "SIGHT PREVIEW: select a soldier, then hover a target cell."
		if active_soldier >= 0 and cell_is_in_bounds(target):
			var info := Rules.preview(soldiers[active_soldier]["cell"], target)
			preview = "%s (%d, %d) | Distance %d | %s" % ["Pinned" if pinned_target != NONE else "Target", target.x, target.y, info["distance"], "Sight clear" if info["clear"] else "WALL BLOCKS SHOT"]
			var detail := "Aim 75 | Range %+d | Cover %+d | " % [info["range_modifier"], info["cover_modifier"]]
			detail += "%d%% preview" % info["chance"] if info["can_fire"] else "Cannot fire"
			draw_string(font, Vector2(40, 790), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("f7cd6c"))
			var explanation := "No cover edge at target."
			if info["edge"] != "none":
				explanation = "%s edge: %s" % [info["edge"].capitalize(), "protected (-25)" if info["protected"] else "flanked (0)"]
			if not info["blockers"].is_empty():
				explanation += " Wall touched: %s." % str(info["blockers"][0])
			elif info["distance"] > 12:
				explanation += " Beyond rifle range (12)."
			elif info["distance"] == 0:
				explanation += " Choose a different cell."
			draw_string(font, Vector2(40, 820), explanation, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d6ded9"))
	draw_string(font, Vector2(40, 730), preview, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d6ded9"))
	draw_string(font, Vector2(40, 758), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d6ded9"))
	var roster := "Phase %d  |  " % phase
	for soldier in soldiers:
		roster += "%s %s   " % [soldier["name"], "OUT" if soldier["extracted"] else ("CRIT" if soldier["hp"] <= 0 else "%dHP" % soldier["hp"])]
	draw_string(font, Vector2(40, 865), roster, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("d6ded9"))
	draw_rect(NEXT_PHASE_RECT, Color("315b50"))
	draw_string(font, NEXT_PHASE_RECT.position + Vector2(0, 26), "End turn [N]", HORIZONTAL_ALIGNMENT_CENTER, NEXT_PHASE_RECT.size.x, 16, Color.WHITE)

	draw_rect(MODE_RECT, Color("304965") if sight_mode else Color("315b50"))
	draw_string(font, MODE_RECT.position + Vector2(0, 26), "Aim / sight [T]" if sight_mode else "Movement [T]", HORIZONTAL_ALIGNMENT_CENTER, MODE_RECT.size.x, 16, Color.WHITE)
	draw_string(font, Vector2(40, 979), enemy_intent(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("7ed4ee"))

	var reason := fire_block_reason()
	draw_rect(FIRE_RECT, Color("713f36") if reason == "" else Color("343b38"))
	draw_string(font, FIRE_RECT.position + Vector2(0, 26), "Fire [F] · 1 AP", HORIZONTAL_ALIGNMENT_CENTER, FIRE_RECT.size.x, 16, Color.WHITE)
	draw_rect(RELOAD_RECT, Color("315b50"))
	draw_string(font, RELOAD_RECT.position + Vector2(0, 26), "Reload [R] · 1 AP", HORIZONTAL_ALIGNMENT_CENTER, RELOAD_RECT.size.x, 16, Color.WHITE)
	draw_string(font, Vector2(40, 947), reason if reason != "" else "Ready: fire costs 1 AP + 1 round. Hit deals 4 damage.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f7cd6c"))
	draw_string(font, Vector2(40, 1005), enemy_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("aebbb6"))

	draw_rect(EXTRACT_RECT, Color("315b50"))
	draw_string(font, EXTRACT_RECT.position + Vector2(0, 26), "Extract [E] · 1 AP", HORIZONTAL_ALIGNMENT_CENTER, EXTRACT_RECT.size.x, 16, Color.WHITE)
	draw_rect(SAVE_RECT, Color("304965"))
	draw_string(font, SAVE_RECT.position + Vector2(0, 26), "Save [K]", HORIZONTAL_ALIGNMENT_CENTER, SAVE_RECT.size.x, 16, Color.WHITE)
	draw_rect(LOAD_RECT, Color("304965"))
	draw_string(font, LOAD_RECT.position + Vector2(0, 26), "Load [L]", HORIZONTAL_ALIGNMENT_CENTER, LOAD_RECT.size.x, 16, Color.WHITE)
	draw_string(font, Vector2(635, 1046), "One save slot", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("aebbb6"))
	draw_string(font, Vector2(40, 1090), save_feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("aebbb6"))

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
