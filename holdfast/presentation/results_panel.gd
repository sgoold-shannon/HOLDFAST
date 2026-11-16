extends RefCounted
## Draws detached display data; gameplay and modal input remain in the controller.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	canvas.draw_rect(Rect2(0,0,1144,1224),Color("0e1412"))
	line(canvas,font,55,"HOLDFAST  /  FARM ROAD RECORD",Color("8be6de"),17)
	line(canvas,font,108,view["title"],Color("f7cd6c"),29)
	line(canvas,font,146,"Round %d · %s" % [view["phase"],view["end_reason"]],Color("aebbb6"),18)
	line(canvas,font,184,"MSG terminal loss prevents continuation. Retry or load a tactical save." if view["retry"] else "MSG recovered. The casualties and losses below remain recorded.",Color.WHITE,18)
	line(canvas,font,243,"SQUAD DISPOSITIONS",Color("8be6de"),18)
	for index in range(view["soldiers"].size()):
		line(canvas,font,282+index*37,"%-8s  %s" % [view["soldiers"][index]["name"],view["dispositions"][index]])
	line(canvas,font,443,"CIVILIANS  /  %d evacuated · %d stranded" % [view["evacuated"],12-view["evacuated"]],Color("8be6de"),20)
	for index in range(view["cohorts"].size()):
		var cohort: Dictionary = view["cohorts"][index]
		line(canvas,font,480+index*33,"Group %s · 4 people · %s" % [cohort["id"],"EVACUATED" if cohort["status"] == "extracted" else "STRANDED — fate unconfirmed"],Color("d6ded9"),18)
	line(canvas,font,605,"MACHINERY & VERIFIED OBSERVATIONS",Color("8be6de"),18)
	line(canvas,font,641,view["outcome"],Color.WHITE,18)
	line(canvas,font,675,view["feeder"],Color("d6ded9"),18)
	line(canvas,font,709,"Protocol observed: %s · ACK-01 received: %s · Console authenticated: %s" % ["yes" if view["protocol"]["observed"] else "no","yes" if view["protocol"]["acknowledged"] else "no","yes" if view["protocol"]["authenticated"] else "no"],Color("d6ded9"),17)
	line(canvas,font,743,"These are local observations; the machine's wider purpose is unconfirmed.",Color("aebbb6"),17)
	line(canvas,font,799,"VERIFIED CASUALTY RECOVERY",Color("8be6de"),18)
	var summaries: Array[String] = []
	for index in range(4):
		var treatments = 0
		var pickups = 0
		var extractions = 0
		for event in view["rescue_events"]:
			if event["actor"] == index:
				treatments += 1 if event["kind"] == "stabilized" else 0
				pickups += 1 if event["kind"] == "picked_up" else 0
				extractions += 1 if event["kind"] == "extracted_with" else 0
		if treatments+pickups+extractions > 0:
			summaries.append("%s · treated %d · picked up %d · carried out %d" % [view["soldiers"][index]["name"],treatments,pickups,extractions])
	if summaries.is_empty(): summaries.append("No casualty recovery actions recorded.")
	for index in range(summaries.size()): line(canvas,font,835+index*32,summaries[index],Color("d6ded9"),18)
	line(canvas,font,1002,view["result_feedback"],Color("f7cd6c"),17)
	line(canvas,font,1036,"Non-MSG deaths stay recorded. Left behind and stranded do not mean confirmed dead.",Color("aebbb6"),16)
	for item in [[view["RETRY_RECT"],"Retry mission [Q]" if view["retry"] else "Replay mission [Q]"],[view["RESUME_RECT"],"Load tactical save [L]"],[view["RECORD_RECT"],"Save this state [K]"]]:
		canvas.draw_rect(item[0],Color("304965"))
		canvas.draw_string(font,item[0].position+Vector2(0,35),item[1],HORIZONTAL_ALIGNMENT_CENTER,320,19,Color.WHITE)
	line(canvas,font,1180,"A replay starts a new attempt. H reopens the last resolved mission record.",Color("aebbb6"),17)

static func line(canvas: Object, font: Font, y: float, text: String, color: Color = Color("d6ded9"), size: int = 19) -> void:
	canvas.draw_string(font,Vector2(60,y),text,HORIZONTAL_ALIGNMENT_LEFT,1024,size,color)
