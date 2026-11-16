extends RefCounted
## Read-only display data; no controller or gameplay callbacks.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	canvas.draw_rect(Rect2(858, 86, 280, 1028), Color("18231f"))
	canvas.draw_string(font, Vector2(876, 115), "CIVILIANS / 12 PEOPLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
	for index in range(3):
		var cohort: Dictionary = view["cohorts"][index]
		var origin = Vector2(876, 132 + index * 112)
		canvas.draw_rect(Rect2(origin, Vector2(248,100)), Color("34473e") if index == view["cohort_selected"] else Color("22312a"))
		canvas.draw_string(font, origin + Vector2(10,24), "%s | 4 people | HP %d/4" % [cohort["id"],cohort["hp"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		canvas.draw_string(font, origin + Vector2(10,47), view["labels"][index] if cohort["status"] == "active" else cohort["status"].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("aabbe5"))
		canvas.draw_string(font, origin + Vector2(10,70), view["notes"][index], HORIZONTAL_ALIGNMENT_LEFT, 230, 13, Color("d4dfd8"))
		canvas.draw_string(font, origin + Vector2(10,90), "%s through %s" % [cohort["manifest"][0],cohort["manifest"][3]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("9eaea4"))
	canvas.draw_string(font, Vector2(876, 493), "Operation ended" if view["ended"] else ("Order spent this phase" if view["order_used"] else "One free group order available"), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f7cd6c"))
	var leader_name: String = view["leader"]
	for item in [[view["EXIT_ORDER_RECT"],"Move to EXIT"],[view["FOLLOW_RECT"],"Follow: " + leader_name],[view["HOLD_RECT"],"Hold position"],[view["NORTH_RECT"],view["north_label"]],[view["SOUTH_RECT"],view["south_label"]]]:
		canvas.draw_rect(item[0], Color("343b38") if view["order_used"] or view["ended"] or (item[0] == view["NORTH_RECT"] and not view["north_available"]) else Color("304965"))
		canvas.draw_string(font, item[0].position + Vector2(0,26), item[1], HORIZONTAL_ALIGNMENT_CENTER, item[0].size.x, 16, Color.WHITE)
	for line in [[714,"1. Select group A, B or C."],[736,"2. Move to EXIT, or follow a soldier."],[758,"3. End turn [N]: groups move 3 cells."],[780,"Orders persist. Order B/C next turns."]]:
		canvas.draw_string(font,Vector2(876,line[0]),line[1],HORIZONTAL_ALIGNMENT_LEFT,248,13,Color("d4dfd8"))
	canvas.draw_string(font,Vector2(876,807),"EXIT %s: automatic rescue" % view["exit"],HORIZONTAL_ALIGNMENT_LEFT,248,14,Color("8be6de"))
	canvas.draw_string(font,Vector2(876,831),"Road closes after round %d" % view["deadline"],HORIZONTAL_ALIGNMENT_LEFT,248,16,Color("f7cd6c"))
	var evacuated = 0
	var stranded = 0
	for cohort in view["cohorts"]:
		evacuated += 4 if cohort["status"] == "extracted" else 0
		stranded += 4 if cohort["status"] == "stranded" else 0
	canvas.draw_string(font, Vector2(876, 855), "Evacuated %d | Stranded %d" % [evacuated,stranded], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	var left = 0
	for soldier in view["soldiers"]:
		left += 0 if soldier["extracted"] else 1
	if view["ended"]:
		canvas.draw_string(font, Vector2(876, 878), view["end_reason"], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f7cd6c"))
		canvas.draw_string(font, Vector2(876, 900), "Squad: %d out / %d left behind" % [4-left,left], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		canvas.draw_string(font, Vector2(876, 922), "MSG missing: retry required" if not view["soldiers"][0]["extracted"] else "MSG extracted", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f7cd6c"))
	elif view["close_pending"]:
		canvas.draw_string(font, Vector2(876, 878), "Close operation now?", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("f7cd6c"))
		canvas.draw_string(font, Vector2(876, 900), "%d civilians will be stranded." % view["remaining"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
		canvas.draw_string(font, Vector2(876, 922), "%d soldiers will be left behind." % left, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	canvas.draw_rect(view["CLOSE_RECT"], Color("713f36") if view["close_pending"] else Color("343b38"))
	canvas.draw_string(font, view["CLOSE_RECT"].position + Vector2(0,28), "Confirm: leave them behind" if view["close_pending"] else "Close operation early", HORIZONTAL_ALIGNMENT_CENTER,248,15,Color.WHITE)
	if view["close_pending"]:
		canvas.draw_rect(view["CANCEL_RECT"],Color("304965"))
		canvas.draw_string(font,view["CANCEL_RECT"].position+Vector2(0,24),"Cancel",HORIZONTAL_ALIGNMENT_CENTER,248,15,Color.WHITE)
	canvas.draw_rect(Rect2(35,1070,800,47),Color("0e1412"))
	var forecast = str(view["machine"]["collected_round"] + 1) if view["machine"]["collected_round"] > 0 else (str(view["phase"] + 4 - view["machine"]["stage"]) if view["present"] else "none")
	canvas.draw_string(font,Vector2(40,1088),"External closure 10 | Machine forecast %s | Current deadline %d" % [forecast,view["deadline"]],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))
	canvas.draw_string(font,Vector2(40,1109),view["save_feedback"],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))
