extends "res://battlefield.gd"
## B1: route, occupied-cell impacts, and fixed-cell defensive shots.
const FARM_SLOT := "user://holdfast_b1.save"
const ROUTE: Array[Vector2i] = [Vector2i(10, 8), Vector2i(9, 8), Vector2i(8, 8), Vector2i(7, 8), Vector2i(7, 8), Vector2i(8, 8), Vector2i(9, 8), Vector2i(10, 8), Vector2i(11, 8)]
const FIXTURES: Array[Vector2i] = [Vector2i(9, 4), Vector2i(11, 12)]
var machine := {"stage": 0, "hostile": false, "pending_shot": Vector2i(-1, -1), "collected_round": 0, "departed": false}

func _ready() -> void:
	super._ready()
	enemies.assign([{"cell": Vector2i(10, 8), "hp": 16, "ammo": 4}])
	status_text = "Farm Road: neutral machine. Orange = next movement; red = charged shot."
	enemy_message = "Observed route: (10,8) → (9,8) → (8,8) → skid (7,8), then return."
	save_feedback = "B1 has its own save slot. Gate A scene and save remain available."

func machine_present() -> bool:
	return enemies[0]["hp"] > 0 and not machine["departed"]

func next_machine_cell() -> Vector2i:
	if not machine_present() or machine["stage"] == 3 or machine["stage"] == 8:
		return NONE
	return ROUTE[machine["stage"] + 1]

func target_at(cell: Vector2i) -> int:
	return 0 if machine_present() and enemies[0]["cell"] == cell else -1

func is_walkable(cell: Vector2i) -> bool:
	return not FIXTURES.has(cell) and super.is_walkable(cell)

func enemy_target() -> int:
	if not machine_present() or not machine["hostile"]:
		return -1
	var best := -1
	var nearest := 999
	for index in range(soldiers.size()):
		if not soldier_can_act(index):
			continue
		var info := Rules.preview(enemies[0]["cell"], soldiers[index]["cell"])
		if info["clear"] and info["distance"] <= 6 and info["distance"] < nearest:
			nearest = info["distance"]
			best = index
	return best

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
	if last_enemy_phase == phase:
		return
	last_enemy_phase = phase
	if not machine_present():
		enemy_message = "Machine: no activation."
		return
	var events: Array[String] = []
	var shot: Vector2i = machine["pending_shot"]
	machine["pending_shot"] = NONE
	if shot != NONE:
		events.append("Shot (%d,%d): %s" % [shot.x, shot.y, damage_cell(shot, 4)])
	var next := next_machine_cell()
	if machine["stage"] == 3:
		machine["collected_round"] = phase
		machine["stage"] = 4
		events.append("Skid collected; feeder severed")
	elif machine["stage"] == 8:
		machine["departed"] = true
		events.append("Machine departed")
	elif cell_occupied_by_people(next):
		events.append("Impact (%d,%d): %s; held" % [next.x, next.y, damage_cell(next, 4)])
	else:
		enemies[0]["cell"] = next
		machine["stage"] += 1
		events.append("Moved (%d,%d)" % [next.x, next.y])
	var index := enemy_target()
	if index >= 0:
		machine["pending_shot"] = soldiers[index]["cell"]
	enemy_message = "; ".join(events)
	rebuild_movement()

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
	var info := Rules.preview(soldier["cell"], pinned_target)
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
	var result := SaveStore.load_snapshot(path)
	if result["error"] != "" or result.get("snapshot", {}).get("layout") != "gdd3.1-b1-farm-road":
		save_feedback = result["error"] if result["error"] != "" else "This save belongs to Gate A. Open battlefield.tscn to load it."
		queue_redraw()
		return false
	var snapshot: Dictionary = result["snapshot"]
	# Restore route state before movement is rebuilt by the base loader.
	machine = snapshot["machine"].duplicate(true)
	var ui: Dictionary = snapshot["ui"]
	active_soldier = ui["active"]
	restore_combat(snapshot["combat"])
	selected_cell = ui["selected"]
	pinned_target = ui["pinned"]
	sight_mode = ui["sight"]
	status_text = ui["status"]
	hovered_cell = NONE
	save_feedback = "Loaded Farm Road phase %d, including pending hazards." % phase
	queue_redraw()
	return true

func machine_track() -> Array[Vector2i]:
	return [Vector2i(10,8),Vector2i(9,8),Vector2i(8,8),Vector2i(7,8),Vector2i(8,8),Vector2i(9,8),Vector2i(10,8),Vector2i(11,8)]

func skid_visible() -> bool:
	return machine["collected_round"] == 0

func _draw() -> void:
	super._draw()
	# Scene-specific title and footer replace the Gate A test labels.
	draw_rect(Rect2(35, 10, 790, 34), Color("0e1412"))
	draw_string(font, Vector2(40, 36), "HOLDFAST / B1 FARM ROAD MACHINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("e5e9e7"))
	var track := machine_track()
	for i in range(1, track.size()):
		draw_line(cell_to_local(track[i-1]) + Vector2(18, 27), cell_to_local(track[i]) + Vector2(18, 27), Color("d1b48a"), 2)
	for fixture in FIXTURES:
		draw_rect(Rect2(cell_to_local(fixture) + Vector2(4, 4), Vector2(28, 28)), Color("66727b"))
		draw_string(font, cell_to_local(fixture) + Vector2(0, 24), "B" if fixture == Vector2i(9, 4) else "C", HORIZONTAL_ALIGNMENT_CENTER, 36, 16, Color.WHITE)
	if skid_visible():
		draw_string(font, cell_to_local(Vector2i(7, 8)) + Vector2(0, 12), "SKID", HORIZONTAL_ALIGNMENT_CENTER, 36, 10, Color("e8d9b4"))
	var next := next_machine_cell()
	if next != NONE:
		draw_rect(Rect2(cell_to_local(next) + Vector2(2, 2), Vector2(32, 32)), Color(1.0,0.5,0.1,0.3))
		draw_rect(Rect2(cell_to_local(next) + Vector2(2, 2), Vector2(32, 32)), Color("ffb75a"), false, 3)
		draw_string(font, cell_to_local(next) + Vector2(0, 12), "IMPACT", HORIZONTAL_ALIGNMENT_CENTER, 36, 9, Color("ffb75a"))
	var shot: Vector2i = machine["pending_shot"]
	if shot != NONE:
		draw_rect(Rect2(cell_to_local(shot) + Vector2(3, 3), Vector2(30, 30)), Color(1.0,0.1,0.2,0.4))
		draw_rect(Rect2(cell_to_local(shot) + Vector2(3, 3), Vector2(30, 30)), Color("ff6d78"), false, 3)
		draw_line(cell_to_local(shot) + Vector2(4, 4), cell_to_local(shot) + Vector2(32, 32), Color("ff6d78"), 2)
		draw_line(cell_to_local(shot) + Vector2(32, 4), cell_to_local(shot) + Vector2(4, 32), Color("ff6d78"), 2)
	if machine_present():
		var center := cell_to_local(enemies[0]["cell"]) + Vector2(18, 18)
		var hull := PackedVector2Array([center+Vector2(-14,-8),center+Vector2(-8,-14),center+Vector2(8,-14),center+Vector2(14,-8),center+Vector2(14,10),center+Vector2(-14,10)])
		draw_colored_polygon(hull, Color("b34b42") if machine["hostile"] else Color("607e8f"))
		draw_rect(Rect2(center+Vector2(-17,-9),Vector2(5,23)),Color("192329"))
		draw_rect(Rect2(center+Vector2(12,-9),Vector2(5,23)),Color("192329"))
		draw_line(center,center+Vector2(-17,0),Color("f7cd6c"),5)
		draw_circle(center,5,Color("ff6d78") if machine["hostile"] else Color("8be6de"))
		draw_rect(Rect2(center+Vector2(-16,15),Vector2(32,3)),Color("17202a"))
		draw_rect(Rect2(center+Vector2(-16,15),Vector2(32.0*enemies[0]["hp"]/16.0,3)),Color("f7cd6c"))
		if sight_mode and pinned_target == enemies[0]["cell"]:
			for direction in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				draw_rect(Rect2(cell_to_local(enemies[0]["cell"] + direction) + Vector2(1, 1), Vector2(34, 34)), Color("e6a2c7"), false, 1)
	draw_rect(Rect2(35,672,800,20),Color("0e1412"))
	draw_string(font,Vector2(40,687),danger_summary(),HORIZONTAL_ALIGNMENT_LEFT,790,14,Color("ffb75a"))
	var forecast := "none (machine stopped)"
	if machine["collected_round"] > 0:
		forecast = str(machine["collected_round"] + 1)
	elif machine_present():
		forecast = str(phase + 4 - machine["stage"])
	draw_rect(Rect2(35, 966, 800, 52), Color("0e1412"))
	draw_string(font, Vector2(40, 985), enemy_intent(), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffb75a"))
	draw_string(font, Vector2(40, 1008), enemy_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d6ded9"))
	draw_rect(Rect2(35, 1070, 800, 47), Color("0e1412"))
	draw_string(font, Vector2(40, 1088), "Closure forecast: machine %s / external 10 (resolution in B2)." % forecast, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("aebbb6"))
	draw_string(font, Vector2(40, 1109), save_feedback, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("aebbb6"))
	if sight_mode and pinned_target == enemies[0]["cell"] and machine_present():
		draw_rect(Rect2(35, 803, 800, 26), Color("0e1412"))
		draw_string(font, Vector2(40, 822), "Machine HP %d/16 | No cover | Destruction: 4 blast damage in pink outline." % enemies[0]["hp"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e6a2c7"))

func draw_targets() -> void:
	pass # Farm Road draws its machine after hazard overlays.
