extends RefCounted
## Draws detached display data; gameplay and modal input remain in the controller.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	if view["roster_open"]:
		canvas.draw_rect(Rect2(35,75,1050,100),Color("0e1412"))
		line(canvas,font,115,"D1 / RETURN TO FARM ROAD",Color("f7cd6c"),26)
		line(canvas,font,155,"Original machinery: %s. Original casualties and civilian records are retained." % view["source_outcome"],Color("aebbb6"),17)
		canvas.draw_rect(Rect2(35,930,1060,65),Color("0e1412"))
		line(canvas,font,955,"North service tunnel. Manual route always available; preserved machinery adds cooling.",Color("8be6de"),18)
		canvas.draw_rect(view["DEPLOY_RECT"],Color("304965"))
		canvas.draw_string(font,view["DEPLOY_RECT"].position+Vector2(15,35),"Return test complete" if view["return_state"]["active"] else ("Deploy to return map [Enter]" if view["deploy"] else ("MSG needs staging care [T]" if view["campaign"]["committed"] else "Resolve the current mission first")),HORIZONTAL_ALIGNMENT_LEFT,450,19,Color.WHITE)
		return
	if view["scene_view"] != "" or view["result_ready"]: return
	canvas.draw_rect(Rect2(35,10,805,34),Color("0e1412"))
	canvas.draw_string(font,Vector2(40,36),"HOLDFAST / D1 · "+("NORTHBOUND RETURN" if view["return_state"]["active"] else "FARM ROAD ORIGIN"),HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	if not view["return_state"]["active"]: return
	canvas.draw_rect(Rect2(35,773,800,61),Color("0e1412"))
	canvas.draw_rect(view["BREAKER_RECT"],Color("34473e"))
	canvas.draw_string(font,view["BREAKER_RECT"].position+Vector2(0,29),"Repair [I] · 1 AP · %d/2" % view["return_state"]["repair"],HORIZONTAL_ALIGNMENT_CENTER,250,16,Color.WHITE)
	canvas.draw_string(font,Vector2(308,792),"Retained machine (10,8): adjacent repair" if view["return_state"]["source"] == "disabled" else "Original outcome: "+view["return_state"]["source"],HORIZONTAL_ALIGNMENT_LEFT,520,16,Color("f7cd6c"))
	canvas.draw_rect(Rect2(35,930,800,85),Color("0e1412"))
	canvas.draw_string(font,Vector2(40,958),view["outcome"],HORIZONTAL_ALIGNMENT_LEFT,784,18,Color("8be6de"))
	canvas.draw_string(font,Vector2(40,987),"North access closes after round 10. Manual evacuation remains available.",HORIZONTAL_ALIGNMENT_LEFT,784,15,Color.WHITE)
	canvas.draw_rect(Rect2(35,1070,800,155),Color("0e1412"))
	canvas.draw_string(font,Vector2(40,1094),"Cooling: "+("available" if view["cooling"] else "unavailable")+" | one free civilian move, up to 3 cells",HORIZONTAL_ALIGNMENT_LEFT,784,16,Color("8be6de"))
	canvas.draw_string(font,Vector2(40,1122),view["save_feedback"],HORIZONTAL_ALIGNMENT_LEFT,784,14,Color("aebbb6"))
	canvas.draw_rect(view["COOLING_BUTTON"],Color("304965"))
	canvas.draw_string(font,view["COOLING_BUTTON"].position+Vector2(0,28),"Cooling move used" if view["return_state"]["bonus_event"] != "" else "Use cooling move on selected civilian group [Y]",HORIZONTAL_ALIGNMENT_CENTER,784,18,Color.WHITE)
	canvas.draw_string(font,Vector2(40,1201),"Select a civilian group, order a route, then Y. Repairing never restores earlier losses.",HORIZONTAL_ALIGNMENT_LEFT,784,15,Color("aebbb6"))

static func line(canvas: Object, font: Font, y: float, text: String, color: Color = Color("d6ded9"), size: int = 19) -> void:
	canvas.draw_string(font,Vector2(60,y),text,HORIZONTAL_ALIGNMENT_LEFT,1024,size,color)
