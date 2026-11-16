extends SceneTree
const Machine = preload("res://systems/machine_activation.gd")
const Turns = preload("res://systems/turn_resolution.gd")
const NONE := Vector2i(-1,-1)
var failures := 0
var machine: Dictionary
var unit: Dictionary
var actors: Array
var plan: Dictionary
var service
var events: Array[String] = []
var hits: Array[Vector2i] = []
var occupied := NONE
var blocked := false
var finished := false
var allow_before := true
var closing_round := 10
var squad_out := false
var civilians_left := 4
var fatal_activation := false
var route: Array = [Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),Vector2i(3,2),Vector2i(3,2),Vector2i(3,1),Vector2i(2,1),Vector2i(1,1),Vector2i(1,2)]
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func reset() -> void:
	machine = {"stage":0,"hostile":false,"pending_shot":NONE,"collected_round":0,"departed":false}
	unit = {"cell":Vector2i(1,1),"hp":16}
	actors = [{"cell":Vector2i(4,1),"active":true},{"cell":Vector2i(2,3),"active":true}]
	plan = {"collect_stage":3,"depart_stage":8,"disabled":false,"protocol":{},"skid":Vector2i(1,1),"diversion":[Vector2i(2,2),Vector2i(3,2),Vector2i(4,2)]}
	events.clear()
	hits.clear()
	occupied = NONE
	blocked = false
	finished = false
	service = Machine.new(next_cell,target,is_occupied,damage,path)
func next_cell() -> Vector2i: return service.next_cell(machine,unit,route,plan)
func target() -> int: return service.nearest_target(machine,unit,actors,plan,active,sight)
func active(index: int) -> bool: return actors[index]["active"]
func sight(a: Vector2i,b: Vector2i) -> Dictionary:
	var d := b-a
	return {"clear":not blocked,"distance":absi(d.x)+absi(d.y)}
func is_occupied(cell: Vector2i) -> bool: return cell==occupied
func damage(cell: Vector2i,_amount: int) -> String:
	hits.append(cell)
	finished = true # Completion may be requested, but all activation effects must finish.
	return "hit"
func path(start: Vector2i, goal: Vector2i, avoid: bool) -> Array[Vector2i]:
	if blocked or start==goal: return []
	var step := start + Vector2i(signi(goal.x-start.x),0) if start.x != goal.x else start+Vector2i(0,signi(goal.y-start.y))
	return [] if avoid and step==occupied else [step]
func activate(): return service.activate(machine,unit,actors,1,plan)
func protocol() -> Dictionary:
	return {"pause_pending":false,"pause_used":false,"diverted":false,"component_collected":false,"waypoint":0,"betrayed":false}
func run() -> void:
	reset()
	activate()
	expect(unit["cell"]==Vector2i(2,1) and machine["pending_shot"]==NONE and hits.is_empty(),"Neutral patrol moves without shooting")
	reset()
	machine["hostile"] = true
	activate()
	expect(machine["pending_shot"]==Vector2i(4,1) and hits.is_empty(),"First hostile activation charges, not fires")
	actors[0]["cell"] = Vector2i(4,2)
	activate()
	expect(hits==[Vector2i(4,1)],"Charged shot strikes fixed cell even after target moves")
	reset()
	machine["hostile"] = true
	actors = [{"cell":Vector2i(2,1),"active":true},{"cell":Vector2i(1,2),"active":true}]
	expect(target()==0,"Target ties preserve roster order")
	actors[0]["active"] = false
	expect(target()==1,"Incapacitated soldier excluded")
	blocked = true
	expect(target()==-1,"Blocked sight prevents acquisition")
	reset()
	plan["protocol"] = protocol()
	plan["protocol"]["pause_pending"] = true
	machine["pending_shot"] = Vector2i(4,1)
	activate()
	expect(machine["stage"]==0 and machine["pending_shot"]==Vector2i(4,1) and hits.is_empty() and plan["protocol"]["pause_used"],"Pause preserves charged shot and skips entire activation")
	plan["disabled"] = true
	activate()
	expect(machine["pending_shot"]==NONE and hits.is_empty(),"Disable clears charge without damage")
	reset()
	plan["protocol"] = protocol()
	plan["protocol"]["diverted"] = true
	unit["cell"] = Vector2i(1,2)
	occupied = Vector2i(2,2)
	activate()
	expect(unit["cell"]==Vector2i(1,2) and hits.is_empty(),"Diverted machine waits rather than impacts people")
	occupied = NONE
	activate()
	expect(unit["cell"]==Vector2i(3,2) and not machine["departed"],"Diversion moves at most two cells")
	activate()
	expect(plan["protocol"]["component_collected"] and not machine["departed"],"Collection precedes departure by an activation")
	activate()
	expect(machine["departed"] and machine["collected_round"]==0,"Diversion departure preserves original skid")
	reset()
	plan["protocol"] = protocol()
	plan["protocol"]["betrayed"] = true
	machine["hostile"] = true
	machine["pending_shot"] = Vector2i(4,1)
	unit["cell"] = Vector2i(3,1)
	occupied = Vector2i(2,1)
	activate()
	expect(hits==[Vector2i(4,1),Vector2i(2,1)] and unit["cell"]==Vector2i(3,1),"Betrayal resolves shot then occupied-cell impact before completion")
	unit["cell"] = plan["skid"]
	activate()
	expect(machine["collected_round"]==1 and machine["stage"]==4,"Betrayal rejoins patrol after collection")
	reset()
	machine["stage"] = 3
	activate()
	expect(machine["collected_round"]==1 and machine["stage"]==4,"Patrol collection updates deadline state")
	machine["stage"] = 8
	activate()
	expect(machine["departed"] and next_cell()==NONE,"Patrol departs at configured stage")
	reset()
	unit["hp"] = 0
	activate()
	expect(machine["stage"]==0 and hits.is_empty(),"Destroyed machine has no activation")
	test_turn_order()
	print("MACHINE AND TURN RULES FAILURES: ",failures)
	quit(1 if failures else 0)
func before() -> bool:
	events.append("casualties")
	return allow_before
func do_machine() -> void:
	events.append("machine")
	if fatal_activation: finished = true
func finish(reason: String) -> void:
	events.append(reason)
	finished = true
func test_turn_order() -> void:
	var hooks := {
		"ended":func() -> bool: return finished,
		"before_machine":before,
		"prepare_machine":func(): events.append("prepare"),
		"machine":do_machine,
		"civilians":func(): events.append("civilians"),
		"completion":completion,
		"finish":finish,
		"begin_player":func(): events.append("player"),
		"after_turn":func(): events.append("finalize"),
	}
	finished = false
	events.clear()
	Turns.resolve(1,hooks)
	expect(events==["casualties","prepare","machine","civilians","player","finalize"],"Normal sequence is explicit")
	events.clear()
	Turns.resolve(10,hooks)
	expect(events==["casualties","prepare","machine","civilians","Road closed","finalize"],"Deadline closes after civilian movement without resetting AP")
	events.clear()
	Turns.resolve(10,hooks)
	expect(events==["finalize"],"Finished turn cannot damage or move again")
	finished = false
	allow_before = false
	events.clear()
	Turns.resolve(1,hooks)
	expect(events==["casualties","finalize"],"Bleed-out halt skips machine and civilians")
	allow_before = true
	fatal_activation = true
	events.clear()
	Turns.resolve(1,hooks)
	expect(events==["casualties","prepare","machine","finalize"],"Fatal machine activation halts remainder")
	fatal_activation = false
	finished = false
	squad_out = true
	civilians_left = 0
	events.clear()
	Turns.resolve(1,hooks)
	expect(events==["casualties","prepare","machine","civilians","Evacuation resolved","finalize"],"Complete extraction ends instead of starting another turn")

func completion(round_number: int) -> String:
	if round_number >= closing_round: return "Road closed"
	if squad_out and civilians_left == 0: return "Evacuation resolved"
	return ""
