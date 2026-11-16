extends RefCounted
## Draws detached display data; gameplay and modal input remain in the controller.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	canvas.draw_rect(Rect2(35,10,790,34),Color("0e1412"))
	canvas.draw_string(font,Vector2(40,36),"HOLDFAST / B3 DESTROY OR DISABLE",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	if view["disabled"]:
		for gate in view["GATES"]:
			var origin = projection.cell_anchor(gate)
			canvas.draw_rect(Rect2(origin+Vector2(2,2),Vector2(32,32)),Color("ea9670"),false,2)
			canvas.draw_string(font,origin+Vector2(0,24),"LOCK",HORIZONTAL_ALIGNMENT_CENTER,36,10,Color("ea9670"))
	if not view["sight_mode"]:
		canvas.draw_rect(view["BREAKER_RECT"],Color("315b50") if view["reason"] == "" else Color("343b38"))
		canvas.draw_string(font,view["BREAKER_RECT"].position+Vector2(0,29),"Open breaker [I] · 1 AP" if view["breaker_progress"] == 0 else ("Preview isolation [I]" if view["breaker_progress"] == 1 else "Drive isolated"),HORIZONTAL_ALIGNMENT_CENTER,250,16,Color.WHITE)
		canvas.draw_string(font,Vector2(308,792),"Breaker (9,4): %d/2 steps" % view["breaker_progress"],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("f7cd6c"))
		canvas.draw_string(font,Vector2(308,816),view["reason"] if view["reason"] != "" else "Progress persists; any adjacent soldier may finish.",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))
	elif view["pinned_target"] == view["enemies"][0]["cell"] and view["present"]:
		canvas.draw_rect(Rect2(35,803,800,28),Color("0e1412"))
		canvas.draw_string(font,Vector2(40,821),"HP %d/16 | Destruction: 4 damage to %s. Cooling lost." % [view["enemies"][0]["hp"], view["victims"]],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("e6a2c7"))
	canvas.draw_rect(Rect2(35,1070,800,47),Color("0e1412"))
	canvas.draw_string(font,Vector2(40,1088),view["outcome"]+" Closure: round %d." % view["deadline"],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))
	canvas.draw_string(font,Vector2(40,1109),view["save_feedback"],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))
	if view["isolate_pending"]:
		canvas.draw_rect(Rect2(110,240,640,320),Color("111b17"))
		canvas.draw_rect(Rect2(110,240,640,320),Color("f7cd6c"),false,2)
		var lines = ["ISOLATE DRIVE? 1 AP", "Stops the machine and clears its charged shot.", "Feeder loses power. Civilian gates (11,7) and (11,10) lock.", "North route: (11,7) → (11,4). South: (11,10) → (11,11).", "Existing groups still approaching their waypoint use the bypass.", "Soldiers retain manual access. Machine retained for later repair.", "A collected skid and an advanced deadline are NOT reversed."]
		for index in range(lines.size()):
			canvas.draw_string(font,Vector2(134,275+index*29),lines[index],HORIZONTAL_ALIGNMENT_LEFT,-1,18 if index == 0 else 15,Color("f7cd6c") if index == 0 else Color.WHITE)
		canvas.draw_rect(view["CONFIRM_RECT"],Color("713f36"))
		canvas.draw_rect(view["ABORT_RECT"],Color("304965"))
		canvas.draw_string(font,view["CONFIRM_RECT"].position+Vector2(0,29),"Confirm isolate [I]",HORIZONTAL_ALIGNMENT_CENTER,260,16,Color.WHITE)
		canvas.draw_string(font,view["ABORT_RECT"].position+Vector2(0,29),"Cancel [Esc]",HORIZONTAL_ALIGNMENT_CENTER,260,16,Color.WHITE)

static func line(canvas: Object, font: Font, y: float, text: String, color: Color = Color("d6ded9"), size: int = 19) -> void:
	canvas.draw_string(font,Vector2(60,y),text,HORIZONTAL_ALIGNMENT_LEFT,1024,size,color)
