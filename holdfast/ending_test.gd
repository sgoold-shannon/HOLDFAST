extends Node2D
const Rules = preload("res://ending_rules.gd")
const ACCEPT := Rect2(60,430,300,48)
const CHECK := Rect2(382,430,340,48)
const WITHDRAW := Rect2(744,430,340,48)
const BOARD := Rect2(60,900,320,54)
const END_ROUND := Rect2(402,900,320,54)
const LAUNCH := Rect2(744,900,340,54)
const SAVE := Rect2(60,984,320,48)
const LOAD := Rect2(402,984,320,48)
const BACK := Rect2(744,984,340,48)
var state := Rules.new_state("strong")
var source_snapshot: Dictionary = {}
var return_board: Node2D
var save_path := Rules.SLOT
var auto_resume := true
var pending_action := ""
var save_note := "K saves / L loads only this test. Campaign saves are unchanged."
var font: Font = ThemeDB.fallback_font

func source_summary() -> Dictionary:
	if source_snapshot.is_empty(): return {}
	var campaign: Dictionary = source_snapshot["campaign"]
	var losses: Array[String] = []
	for member in campaign["members"]:
		if ["dead","left_behind","recovering"].has(member["status"]): losses.append("%s: %s" % [member["name"],member["status"].replace("_"," ")])
	return {"machine":preload("res://return_rules.gd").outcome(campaign),"losses":losses,"records":campaign["missions"].size()}

func _ready() -> void:
	state = Rules.new_state("strong",source_summary())
	if auto_resume and FileAccess.file_exists(save_path):
		var loaded := Rules.load_state(save_path)
		if loaded["error"] == "" and loaded["state"]["source"] == state["source"]:
			state = loaded["state"]
			save_note = "Previous ending test restored. Choose a New fixture to restart its test."

func new_fixture(preset: String) -> void:
	state = Rules.new_state(preset,state["source"])
	pending_action = ""
	save_note = "New test. Earlier campaign deaths, rescues and machinery records are untouched."
	queue_redraw()

func save_test() -> bool:
	var error := Rules.save(state,save_path)
	save_note = "Ending test saved, including agreement and unique boarding events." if error == "" else error
	queue_redraw()
	return error == ""

func load_test() -> bool:
	var loaded := Rules.load_state(save_path)
	if loaded["error"] != "":
		save_note = loaded["error"]
		queue_redraw()
		return false
	if loaded["state"]["source"] != state["source"]:
		save_note = "This test belongs to another source record; current test unchanged."
		queue_redraw()
		return false
	state = loaded["state"]
	pending_action = ""
	save_note = "Loaded: no passenger or free boarding action is counted twice."
	queue_redraw()
	return true

func act(action: String) -> void:
	if state["finished"]: return
	if action == "accept":
		if not Rules.accept(state): state["feedback"] = "Agreement unavailable: it must be accepted by round 2."
	elif action == "check":
		if not Rules.service_check(state): state["feedback"] = "Check requires an accepted agreement, 1 AP, and round 1 or 2."
	elif action == "board": Rules.board(state,state["selected"])
	elif action == "next": Rules.end_round(state)
	elif action == "withdraw":
		if ["accepted","ready"].has(state["agreement"]) and not state["finished"]:
			pending_action = "withdraw"
		else: Rules.withdraw(state)
	elif action == "launch" and not state["finished"]: pending_action = "launch"
	if state["finished"]: save_test()
	queue_redraw()

func confirm_action() -> void:
	if pending_action == "withdraw": Rules.withdraw(state)
	elif pending_action == "launch": Rules.launch(state)
	pending_action = ""
	if state["finished"]: save_test()
	queue_redraw()

func back_to_campaign() -> void:
	save_test()
	if is_instance_valid(return_board):
		return_board.show()
		return_board.set_process_unhandled_input(true)
		queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if pending_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE: pending_action = ""
			elif event.keycode == KEY_ENTER or (event.keycode == KEY_W and pending_action == "withdraw") or (event.keycode == KEY_E and pending_action == "launch"): confirm_action()
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
			if Rect2(85,660,455,60).has_point(point): confirm_action()
			elif Rect2(565,660,455,60).has_point(point): pending_action = ""
		queue_redraw()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: new_fixture("strong")
			KEY_2: new_fixture("strained")
			KEY_3: new_fixture("minimum")
			KEY_4: new_fixture("no_power")
			KEY_A: act("accept")
			KEY_C: act("check")
			KEY_W: act("withdraw")
			KEY_B: act("board")
			KEY_N: act("next")
			KEY_E: act("launch")
			KEY_K: save_test()
			KEY_L: load_test()
			KEY_ESCAPE: back_to_campaign()
			KEY_DOWN: state["selected"] = (state["selected"]+1)%6
			KEY_UP: state["selected"] = posmod(state["selected"]-1,6)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
		for index in range(4):
			if Rect2(60+index*260,174,244,46).has_point(point): new_fixture(["strong","strained","minimum","no_power"][index])
		for item in [[ACCEPT,"accept"],[CHECK,"check"],[WITHDRAW,"withdraw"],[BOARD,"board"],[END_ROUND,"next"],[LAUNCH,"launch"]]:
			if item[0].has_point(point): act(item[1])
		if SAVE.has_point(point): save_test()
		elif LOAD.has_point(point): load_test()
		elif BACK.has_point(point): back_to_campaign()
		for index in range(6):
			if Rect2(60,565+index*40,1024,36).has_point(point): state["selected"] = index
	queue_redraw()

func line(y: float, text: String, color: Color = Color("d6ded9"), size: int = 18) -> void:
	draw_string(font,Vector2(60,y),text,HORIZONTAL_ALIGNMENT_LEFT,1024,size,color)

func button(rect: Rect2, text: String, enabled: bool = true) -> void:
	draw_rect(rect,Color("304965") if enabled else Color("28332d"))
	draw_string(font,rect.position+Vector2(10,31),text,HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-20,18,Color.WHITE)

func _draw() -> void:
	draw_rect(Rect2(0,0,1144,1224),Color("0e1412"))
	line(55,"HOLDFAST / D2 · AGREEMENT & ENDING TEST",Color("8be6de"),25)
	line(95,"24 TEST PASSENGERS · separate from campaign rescue totals",Color("f7cd6c"),21)
	line(132,"Original machinery: %s · %d prior deployment records retained" % [state["source"].get("machine","no campaign attached"),state["source"].get("records",0)],Color("aebbb6"),17)
	for index in range(4): button(Rect2(60+index*260,174,244,46),["1 · New Strong","2 · New Strained","3 · New Minimum","4 · No power"][index])
	var config: Dictionary = state["config"]
	var power := "reserve consumed" if state["reserve_used"] else Rules.power_path(state)
	line(244,"Core: %s · Tunnel: %s · Power path: %s" % ["ready" if state["core"] else "unavailable","open" if state["tunnel"] else "unavailable",power],Color.WHITE,18)
	line(268,"Primary: %s · Reserve: %s · Connector: %s · Berths: %d groups · Life support: %d groups" % ["available" if config["primary"] else "lost","consumed" if state["reserve_used"] else ("charged" if config["reserve"] else "unavailable"),"intact" if config["connector"] else "disconnected",config["berths"],config["life"]],Color("aebbb6"),15)
	line(298,"Round %d / closes after %d · AP %d/2 · Each group has four people" % [state["round"],config["deadline"],state["ap"]],Color("8be6de"),20)
	line(327,"BOUNDED AGREEMENT / %s · checks %d/2" % [state["agreement"].to_upper(),state["checks"]],Color("f7cd6c"),19)
	line(359,"Complete two service checks (1 AP each) by the end of round 2.",Color.WHITE,18)
	line(389,"Keep the service-lane allocation through launch. In return: one free boarding action.",Color("d6ded9"),18)
	button(ACCEPT,"Accept [A]",not state["finished"])
	button(CHECK,"Service check [C] · 1 AP",not state["finished"])
	button(WITHDRAW,"Withdraw terms [W]" if state["agreement"] != "offered" else "Decline [W]",not state["finished"])
	draw_multiline_string(font,Vector2(60,511),state["feedback"],HORIZONTAL_ALIGNMENT_LEFT,1024,16,2,Color("8be6de"))
	line(552,"GROUP / ARRIVAL ROUND",Color("aebbb6"),15)
	draw_string(font,Vector2(380,552),"DISPOSITION",HORIZONTAL_ALIGNMENT_LEFT,340,15,Color("aebbb6"))
	draw_string(font,Vector2(760,552),"MANIFEST",HORIZONTAL_ALIGNMENT_LEFT,300,15,Color("aebbb6"))
	for index in range(6):
		var cohort: Dictionary = state["cohorts"][index]
		var boarded: bool = state["events"].has("board:"+cohort["id"])
		var arrived: bool = cohort["arrival"] <= state["round"]
		var disposition := "BOARDED" if boarded else (("STRANDED AT STAGING" if state["finished"] else "AT STAGING") if arrived else ("DID NOT ARRIVE" if state["finished"] else "NOT ARRIVED"))
		var y := 565+index*40
		draw_rect(Rect2(60,y,1024,36),Color("3a5548") if state["selected"] == index else Color("1c2b24"))
		draw_string(font,Vector2(74,y+25),"%s · arrives %d" % [cohort["id"],cohort["arrival"]],HORIZONTAL_ALIGNMENT_LEFT,280,18,Color.WHITE)
		draw_string(font,Vector2(380,y+25),disposition,HORIZONTAL_ALIGNMENT_LEFT,340,17,Color("8be6de") if boarded else Color("d6ded9"))
		draw_string(font,Vector2(760,y+25),"TEST-%s-01 … 04" % cohort["id"],HORIZONTAL_ALIGNMENT_LEFT,300,16,Color("aebbb6"))
	var totals := Rules.counts(state)
	line(844,"Aboard: %d · %s: %d · Not arrived: %d" % [totals["boarded"],"Stranded at staging" if state["finished"] else "At staging",totals["staging"],totals["not_arrived"]],Color("f7cd6c"),21)
	line(876,"Protected Drover occupants and ecological reserves are unchanged by this test.",Color("aebbb6"),16)
	button(BOARD,"Board selected [B] · "+("FREE" if state["agreement"] == "ready" and not state["bonus_used"] else "1 AP"),not state["finished"])
	button(END_ROUND,"End round [N]",not state["finished"])
	button(LAUNCH,"Launch preview [E]",not state["finished"])
	button(SAVE,"Save test [K]")
	button(LOAD,"Load test [L]")
	button(BACK,"Back to campaign [Esc]")
	line(1068,"LAUNCHED" if state["launched"] else ("NO LAUNCH / RETRY REQUIRED" if state["finished"] else "Select a group with the mouse or ↑ / ↓, then B. Arrivals happen at round start."),Color("f7cd6c"),19)
	draw_multiline_string(font,Vector2(60,1102),Rules.agreement_report(state),HORIZONTAL_ALIGNMENT_LEFT,1024,17,3,Color("d6ded9"))
	line(1200,save_note,Color("aebbb6"),14)
	if pending_action != "":
		draw_rect(Rect2(0,0,1144,1224),Color(0,0,0,0.78))
		draw_rect(Rect2(60,360,1024,400),Color("182b23"))
		line(411,"CONFIRM WITHDRAWAL" if pending_action == "withdraw" else "CONFIRM LAUNCH / FINALIZE MANIFEST",Color("f7cd6c"),25)
		var preview := "Withdrawing breaks the active commitment. Any unused free boarding action is lost. Already boarded people stay aboard."
		if pending_action == "launch":
			preview = Rules.launch_problem(state)
			if preview == "": preview = "Launch with %d aboard. %d remain at staging; %d have not arrived. %s" % [totals["boarded"],totals["staging"],totals["not_arrived"],"The reserve battery will be consumed." if Rules.power_path(state) == "reserve" else "Primary power is used; the reserve is retained."]
			else: preview += " This ends the attempt with retry, not a completed ending."
		draw_multiline_string(font,Vector2(85,480),preview,HORIZONTAL_ALIGNMENT_LEFT,940,23,-1,Color.WHITE)
		button(Rect2(85,660,455,60),"Confirm [Enter]")
		button(Rect2(565,660,455,60),"Cancel [Esc]")
