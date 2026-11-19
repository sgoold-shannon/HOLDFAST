extends "res://tests/test_support.gd"
## Desktop civilian command: MSG's voice range, 1 AP orders from nearby soldiers, panic.
const Command = preload("res://systems/civilian_command.gd")

func fresh(label: String):
	var board = new_board(label)
	board.command_model = "authority"
	board.finish_opening()
	return board

func run() -> void:
	var legacy = new_board("command-legacy")
	expect(legacy.command_model == "phase","Legacy layout keeps the one-order-per-turn rule")
	legacy.free()

	var board = fresh("command-range")
	var msg: Dictionary = board.soldiers[0]
	expect(msg["name"] == "MSG","MSG is soldier 0")
	board.select_soldier(0)
	var ap_before: int = msg["ap"]
	expect(board.order_exit(0),"MSG orders group A inside his voice range")
	expect(msg["ap"] == ap_before,"MSG's orders are free")
	board.cohorts[1]["cell"] = msg["cell"]+Vector2i(Command.VOICE_RANGE+1,0)
	expect(not board.order_exit(1),"A group outside MSG's range can't be ordered by him")
	# Another soldier standing next to the group can order it for 1 AP.
	var park: Dictionary = board.soldiers[3]
	park["cell"] = board.cohorts[1]["cell"]+Vector2i(0,1)
	board.select_soldier(3)
	var park_ap: int = park["ap"]
	expect(board.order_exit(1) or board.order_cohort(1,"south"),"A nearby soldier can order the group")
	expect(park["ap"] == park_ap-1,"Nearby soldier pays 1 AP")
	park["ap"] = 0
	expect(not board.order_cohort(1,"hold"),"No AP, no order (MSG out of range)")
	board.free()

	board = fresh("command-panic")
	msg = board.soldiers[0]
	var machine_cell: Vector2i = board.enemies[0]["cell"]
	var cohort: Dictionary = board.cohorts[1]
	cohort["cell"] = machine_cell+Vector2i(-2,0)
	cohort["order"] = "hold"
	msg["cell"] = Vector2i(1,1)
	var threats: Array = [machine_cell]
	expect(Command.update_panic(cohort,threats,board.soldiers) == Command.SHAKEN,"Machine within range shakes a group")
	expect(Command.update_panic(cohort,threats,board.soldiers) == Command.PANICKED,"Staying near it panics them")
	board.select_soldier(0)
	expect(not board.order_exit(1),"A panicked group won't take orders")
	var step: Vector2i = Command.scatter_step(cohort,threats,board.civilian_safe)
	expect(Command.distance(step,machine_cell) > Command.distance(cohort["cell"],machine_cell) or step == cohort["cell"],"Panicked groups run away from danger or freeze")
	expect(not board.calm_cohort(1),"MSG too far away to calm them")
	msg["cell"] = cohort["cell"]+Vector2i(-3,0)
	var msg_ap: int = msg["ap"]
	expect(board.calm_cohort(1) and Command.level(cohort) == Command.CALM,"MSG talks a panicked group fully calm")
	expect(msg["ap"] == msg_ap-1,"Calming costs MSG 1 AP")
	expect(Command.update_panic(cohort,threats,board.soldiers) == Command.CALM,"MSG within 3 squares keeps the group steady")
	# Gunfire is noise: a shot fired this round scares groups near the shooter.
	board.round_noise.append(Vector2i(0,0))
	expect(board.civilian_threats().has(Vector2i(0,0)),"Gunfire counts as a threat this round")
	board.free()
	print("CIVILIAN COMMAND FAILURES: ",failures)
	quit(1 if failures else 0)
