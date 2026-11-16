extends RefCounted
## Draws detached display data; gameplay and modal input remain in the controller.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	canvas.draw_rect(Rect2(35,10,790,34),Color("0e1412"))
	canvas.draw_string(font,Vector2(40,36),"HOLDFAST / B4 COMMUNICATE & DIVERT",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	if view["protocol"]["route_set"] and not view["protocol"]["betrayed"]:
		for waypoint in view["DIVERSION"]:
			canvas.draw_rect(Rect2(projection.cell_anchor(waypoint)+Vector2(1,1),Vector2(34,34)),Color("8be6de"),false,2)
	for item in [[view["OBSERVE_RECT"],"Observe [O] · 1 AP","observe"],[view["TRANSMIT_RECT"],"Transmit [P] · 1 AP","transmit"],[view["AUTH_RECT"],"Authenticate [A] · 1 AP","authenticate"],[view["DIVERT_RECT"],"Divert [D] · 1 AP","divert"]]:
		canvas.draw_rect(item[0],Color("304965") if view["reasons"][item[2]] == "" else Color("343b38"))
		canvas.draw_string(font,item[0].position+Vector2(0,26),item[1],HORIZONTAL_ALIGNMENT_CENTER,item[0].size.x,14,Color.WHITE)
	var progress = "Observed: %s | ACK-01: %s | Authenticated: %s" % ["yes" if view["protocol"]["observed"] else "no","received" if view["protocol"]["acknowledged"] else "not received","yes" if view["protocol"]["authenticated"] else "no"]
	canvas.draw_string(font,Vector2(40,1127),progress,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("8be6de"))
	canvas.draw_string(font,Vector2(40,1201),"Pause: HOLD / ONE CYCLE. Console: (11,12), adjacent %s (MSG if unavailable)." % view["soldiers"][2]["name"],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))
	# Keep the forecast honest while paused or safely redirected.
	var forecast = "none"
	if view["machine"]["collected_round"] > 0:
		forecast = str(view["machine"]["collected_round"] + 1)
	elif view["present"] and not view["disabled"] and not view["protocol"]["diverted"]:
		var path = view["path"]
		forecast = str(view["phase"] + path.size() + 1 + (1 if view["protocol"]["pause_pending"] else 0))
	canvas.draw_rect(Rect2(35,1070,800,25),Color("0e1412"))
	canvas.draw_string(font,Vector2(40,1088),"Machine closure forecast %s | External 10 | Deadline %d | %s" % [forecast,view["deadline"],"Safe route canceled" if view["protocol"]["betrayed"] else ("Diverted" if view["protocol"]["diverted"] else "Default recovery")],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))

static func line(canvas: Object, font: Font, y: float, text: String, color: Color = Color("d6ded9"), size: int = 19) -> void:
	canvas.draw_string(font,Vector2(60,y),text,HORIZONTAL_ALIGNMENT_LEFT,1024,size,color)
