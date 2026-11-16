extends RefCounted
## Draws detached display data; gameplay and modal input remain in the controller.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	canvas.draw_rect(Rect2(35,10,790,34),Color("0e1412"))
	canvas.draw_string(font,Vector2(40,36),"HOLDFAST / B5 CASUALTY RESCUE",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	for index in range(view["soldiers"].size()):
		var soldier: Dictionary = view["soldiers"][index]
		if not view["visible"][index]:
			continue
		var center = projection.cell_anchor(soldier["cell"])+Vector2(18,18)
		if soldier["condition"] == "dead":
			canvas.draw_line(center-Vector2(11,11),center+Vector2(11,11),Color("f07878"),3)
		elif soldier["condition"] == "critical":
			canvas.draw_string(font,center+Vector2(7,-6),str(soldier["bleed"]),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("ffb75a"))
		elif soldier["condition"] == "stable":
			canvas.draw_string(font,center+Vector2(7,-6),"+",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("8be6de"))
		if soldier["carrying"] >= 0:
			canvas.draw_string(font,center+Vector2(-15,22),"+"+view["soldiers"][soldier["carrying"]]["mark"],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("8be6de"))
	var target = view["target"]
	canvas.draw_rect(view["CASUALTY_RECT"],Color("34473e"))
	canvas.draw_string(font,view["CASUALTY_RECT"].position+Vector2(0,23),"Casualty: %s [V]" % (view["soldiers"][target]["name"] if view["target_available"] else "none"),HORIZONTAL_ALIGNMENT_CENTER,248,14,Color.WHITE)
	for item in [[view["STABILIZE_RECT"],"Stabilize [S] · 1 AP + charge"],[view["PICKUP_RECT"],"Pick up [U] · 1 AP"],[view["DROP_RECT"],"Put down [J] · 1 AP"]]:
		canvas.draw_rect(item[0],Color("304965"))
		canvas.draw_string(font,item[0].position+Vector2(0,24),item[1],HORIZONTAL_ALIGNMENT_CENTER,248,14,Color.WHITE)
	canvas.draw_string(font,Vector2(876,1210),"%s medical charges: %d/2" % [view["soldiers"][1]["name"],view["soldiers"][1]["medical"]],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("8be6de"))
	if view["can_act"] and view["soldiers"][view["active_soldier"]]["carrying"] >= 0:
		canvas.draw_rect(Rect2(35,713,800,26),Color("0e1412"))
		canvas.draw_string(font,Vector2(40,730),"Carrying %s: 2 squares per move / 1 AP; no dash, fire or machinery." % view["soldiers"][view["soldiers"][view["active_soldier"]]["carrying"]]["name"],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("8be6de"))
	if view["close_pending"] and not view["ended"]:
		var living_left = 0
		for soldier in view["soldiers"]:
			living_left += 1 if not soldier["extracted"] and soldier["condition"] != "dead" else 0
		canvas.draw_rect(Rect2(872,905,256,25),Color("18231f"))
		canvas.draw_string(font,Vector2(876,922),"%d living soldiers left behind." % living_left,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
	if view["ended"]:
		var out_count = 0
		var dead_count = 0
		var left_count = 0
		for soldier in view["soldiers"]:
			out_count += 1 if soldier["extracted"] else 0
			dead_count += 1 if soldier["condition"] == "dead" else 0
			left_count += 1 if soldier["left_behind"] else 0
		canvas.draw_rect(Rect2(872,825,256,62),Color("18231f"))
		canvas.draw_string(font,Vector2(876,846),"Squad: out %d / dead %d / left %d" % [out_count,dead_count,left_count],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
		canvas.draw_string(font,Vector2(876,873),"MSG dead: retry required" if view["soldiers"][0]["condition"] == "dead" else ("MSG missing: retry required" if not view["soldiers"][0]["extracted"] else "MSG extracted"),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f7cd6c"))

static func line(canvas: Object, font: Font, y: float, text: String, color: Color = Color("d6ded9"), size: int = 19) -> void:
	canvas.draw_string(font,Vector2(60,y),text,HORIZONTAL_ALIGNMENT_LEFT,1024,size,color)
