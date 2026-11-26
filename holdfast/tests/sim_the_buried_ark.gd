extends "res://tests/test_support.gd"
## Balance runs for the Buried Ark (isolated; nothing saved). Not part of the suite.
const Warden = preload("res://systems/ark_warden.gd")
const FallowCutter = preload("res://systems/fallow_cutter.gd")

func fresh(trunk: int, channel: String, aven: bool, terms: int):
	var b = load("res://the_buried_ark.tscn").instantiate()
	b.auto_resume = false
	root.add_child(b)
	b.trunk = trunk
	b.channel = channel
	b.aven = aven
	b.aven_charge = aven
	b.parley["start"] = terms
	b.parley["terms"] = terms
	b.parley["aven"] = aven
	b.start_terms = terms
	b.command_model = "authority"
	b.finish_opening()
	return b

func route(b, start: Vector2i, goal: Vector2i, avoid_cone: bool) -> Array:
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
			if avoid_cone and next != goal and Warden.hostile(b.warden) and (Warden.in_cone(b.warden,next) or next == Vector2i(9,7) or next == Vector2i(11,7)): continue
			previous[next] = cell
			frontier.append(next)
	return []

## Walk next to goal; never end a move inside a hostile Warden's cone.
func walk_next_to(b, index: int, goal: Vector2i, avoid_cone: bool) -> void:
	if not b.soldier_can_act(index): return
	b.select_soldier(index)
	b.sight_mode = false
	if absi(b.soldiers[index]["cell"].x-goal.x)+absi(b.soldiers[index]["cell"].y-goal.y) == 1: return
	var path := route(b,b.soldiers[index]["cell"],goal,avoid_cone)
	if path.size() < 2: path = route(b,b.soldiers[index]["cell"],goal,false)
	if path.size() < 2: return
	path.pop_back()
	for distance in range(path.size(),0,-1):
		var cell: Vector2i = path[distance-1]
		var cost: int = b.move_cost(cell)
		if cost > 0 and cost <= b.soldiers[index]["ap"] and b.soldier_at(cell) < 0 and not (Warden.hostile(b.warden) and Warden.in_cone(b.warden,cell) and distance < path.size()):
			b.try_move(cell)
			return

func shoot_cutter(b, index: int) -> void:
	if not b.soldier_can_act(index) or b.soldiers[index]["ap"] < 1 or b.soldiers[index]["attacked"] or not FallowCutter.cutter_alive(b.fallow): return
	b.select_soldier(index)
	if b.soldiers[index]["ammo"] < 1: b.try_reload()
	b.sight_mode = true
	b.pinned_target = b.fallow["cutter"]["cell"]
	b.try_fire()
	b.sight_mode = false
	b.pinned_target = b.NONE

## plan "crawl": everyone via the crawl. "disable": Bell disables, others wait. "negotiate": MSG at the console.
func play(tag: String, plan: String, trunk: int, channel: String, aven: bool, terms: int) -> void:
	var b = fresh(trunk,channel,aven,terms)
	var log := []
	for turn in range(13):
		var crawl: bool = plan == "crawl"
		if plan == "disable" and Warden.hostile(b.warden):
			walk_next_to(b,2,b.COUPLING,true)
			b.select_soldier(2)
			while b.disable_reason() == "": b.disable_warden()
		if plan == "negotiate" and Warden.hostile(b.warden):
			walk_next_to(b,0,b.CONSOLE,true)
			b.select_soldier(0)
			if b.console_reason() == "": b.negotiate_warden()
		var go: bool = crawl or not Warden.hostile(b.warden)
		if go and turn < 10:
			walk_next_to(b,0,b.TABLE,crawl)
			b.select_soldier(0)
			if b.recall_reason() == "": b.recall_delegates()
			if b.shield_reason() == "" and b.fallow.get("target",-1) == 0: b.shield_strip()
			walk_next_to(b,3,b.DOOR,crawl)
			b.select_soldier(3)
			if b.nursery_reason() == "": b.open_nursery()
			if not b.cohorts[2]["penned"] and b.cohorts[2]["status"] == "active":
				b.select_soldier(3)
				if b.cohorts[2].get("panic",0) > 0: b.calm_cohort(2)
			walk_next_to(b,1,b.fallow["node"] if b.fallow["stage"] == "active" else Vector2i(15,5),crawl)
			b.select_soldier(1)
			b.interrupt_rift_node()
			for s in [1,3]: shoot_cutter(b,s)
			if b.fallow["stage"] == "active":
				walk_next_to(b,2,Vector2i(14,5),crawl)
				shoot_cutter(b,2)
		if turn >= 10:
			for s in [0,1,2,3]: evacuate(b,s)
		var r: int = b.phase
		b.next_phase()
		var line := ""
		for c in b.cohorts: line += "%s%s%s " % [c["id"],c["cell"],{"active":"","extracted":"+","stranded":"x"}.get(c["status"],"?")]
		log.append("r%d T%d L%d W:%s C%d %s S%s | %s" % [r,b.parley["terms"],b.life,b.warden["state"],b.fallow["cutter"]["hp"],line,b.soldiers.map(func(x): return "%s%d" % [x["cell"],x["hp"]]),b.enemy_message.left(110)])
		if b.ended: break
	print("%-10s terms=%d agreement=%s warden=%s life=%d D=%s L=%s N=%s msg_out=%s end=%s" % [tag,b.parley["terms"],b.agreement(),b.warden["state"],b.life,b.group_state(0),b.group_state(1),b.group_state(2),b.soldiers[0]["extracted"],b.end_reason])
	for l in log: print("   ",l)
	b.free()

func run() -> void:
	play("crawl","crawl",1,"partial",false,0)
	play("disable","disable",1,"partial",false,1)
	play("negotiate","negotiate",2,"authenticated",true,5)
	quit(0)
