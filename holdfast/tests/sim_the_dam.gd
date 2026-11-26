extends "res://tests/test_support.gd"
## Balance runs for The Dam (isolated; nothing saved). Not part of the suite.
const Dam = preload("res://systems/dam_works.gd")
const FallowCutter = preload("res://systems/fallow_cutter.gd")

func fresh():
	var b = load("res://the_dam.tscn").instantiate()
	b.auto_resume = false
	root.add_child(b)
	b.command_model = "authority"
	b.finish_opening()
	return b

func route(b, start: Vector2i, goal: Vector2i) -> Array:
	var previous := {start:start}
	var frontier: Array = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if cell == goal:
			var path: Array = []
			while cell != start:
				path.push_front(cell)
				cell = previous[cell]
			return path
		for direction in b.DIRECTIONS:
			var next: Vector2i = cell+direction
			if previous.has(next): continue
			if next != goal and not b.is_walkable(next): continue
			previous[next] = cell
			frontier.append(next)
	return []

## Walk toward a square next to goal (goal itself may be a fixture).
func walk_next_to(b, index: int, goal: Vector2i) -> void:
	if not b.soldier_can_act(index): return
	b.select_soldier(index)
	b.sight_mode = false
	if absi(b.soldiers[index]["cell"].x-goal.x)+absi(b.soldiers[index]["cell"].y-goal.y) == 1: return
	var path := route(b,b.soldiers[index]["cell"],goal)
	if path.size() < 2: return
	path.pop_back()
	for distance in range(path.size(),0,-1):
		var cell: Vector2i = path[distance-1]
		var cost: int = b.move_cost(cell)
		if cost > 0 and cost <= b.soldiers[index]["ap"] and b.soldier_at(cell) < 0:
			b.try_move(cell)
			return

## plan "careful": valves only when Kesh says clear. "power": all three units, crates by hand.
func play(tag: String, plan: String) -> void:
	var b = fresh()
	var log := []
	for turn in range(11):
		for i in range(2):
			var c = b.cohorts[i]
			if c["status"] != "active": continue
			for s in [0,1]:
				b.select_soldier(s)
				if c.get("panic",0) > 0: b.calm_cohort(i)
				if c["order"] == "hold": b.order_exit(i)
		if Dam.power_used(b.dam) < 2: walk_next_to(b,0,b.TURBINE)
		b.select_soldier(0)
		for system in (["life","bridge","trunk"] if plan == "power" else ["life","bridge"]):
			if b.power_reason(system) == "" and (system == "trunk" or not b.dam["power"][system]): b.assign_power(system)
		walk_next_to(b,2,b.CONSOLE)
		b.select_soldier(2)
		while b.stabilize_reason() == "": b.stabilize_habitat()
		# Valves: MSG takes the west valve after power, soldier 3 the east valve.
		if Dam.power_used(b.dam) >= 2: walk_next_to(b,0,b.WEST_VALVE)
		walk_next_to(b,3,b.EAST_VALVE)
		if b.dam["pressure"] >= Dam.BREACH-2:
			var order: Array = ["west","east"] if b.zone_clear("west") else ["east","west"] if b.zone_clear("east") else (["east","west"] if plan == "careful" else ["west","east"])
			for side in order:
				var who: int = 0 if side == "west" else 3
				b.select_soldier(who)
				if b.valve_reason(side) == "":
					b.open_valve(side)
					break
		for who in [3,0]:
			b.select_soldier(who)
			b.interrupt_crest_node()
		if plan == "power" and b.dam["delivered"] < 2 and b.remaining_civilians() <= 4:
			if b.carried_by(1) >= 0: walk_next_to(b,1,b.TRUNK)
			else:
				for crate in b.crates:
					if crate["state"] == "ground":
						walk_next_to(b,1,crate["cell"])
						break
			b.select_soldier(1)
			if b.crate_reason() == "": b.handle_crate()
		if turn >= 8 or (b.remaining_civilians() == 0 and b.dam["stabilized"]):
			for s in [0,1,2,3]: evacuate(b,s)
		var r: int = b.phase
		b.next_phase()
		var line := ""
		for c in b.cohorts: line += "%s%s%s " % [c["id"],c["cell"],{"active":"","extracted":"+","stranded":"x","held":"H"}.get(c["status"],"?")]
		log.append("r%d P%d %s S%s | %s" % [r,b.dam["pressure"],line,b.soldiers.map(func(x): return x["cell"]),b.enemy_message.left(110)])
		if b.ended: break
	print("%-8s out=%d/12 dependents=%s breached=%s valves=%s power=%s cargo=%d end=%s" % [tag,b.evacuated_people(),b.dependents_state(),b.dam["breached"],b.dam["valves"],b.dam["power"],b.dam["delivered"],b.end_reason])
	for l in log: print("   ",l)
	b.free()

func run() -> void:
	play("careful","careful")
	play("power","power")
	quit(0)
