extends RefCounted
## Draws detached display data; gameplay and modal input remain in the controller.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	canvas.draw_rect(Rect2(35,672,800,20),Color("0e1412"))
	canvas.draw_string(font,Vector2(40,687),view["danger"],HORIZONTAL_ALIGNMENT_LEFT,790,14,Color("ffb75a"))
	var forecast = "none (machine stopped)"
	if view["machine"]["collected_round"] > 0:
		forecast = str(view["machine"]["collected_round"] + 1)
	elif view["present"]:
		forecast = str(view["phase"] + 4 - view["machine"]["stage"])
	canvas.draw_rect(Rect2(35, 966, 800, 52), Color("0e1412"))
	canvas.draw_string(font, Vector2(40, 985), view["intent"], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("ffb75a"))
	canvas.draw_string(font, Vector2(40, 1008), view["enemy_message"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d6ded9"))
	canvas.draw_rect(Rect2(35, 1070, 800, 47), Color("0e1412"))
	canvas.draw_string(font, Vector2(40, 1088), "Closure forecast: machine %s / external 10 (resolution in B2)." % forecast, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("aebbb6"))
	canvas.draw_string(font, Vector2(40, 1109), view["save_feedback"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("aebbb6"))
	if view["sight_mode"] and view["pinned_target"] == view["enemies"][0]["cell"] and view["present"]:
		canvas.draw_rect(Rect2(35, 803, 800, 26), Color("0e1412"))
		canvas.draw_string(font, Vector2(40, 822), "Machine HP %d/16 | No cover | Destruction: 4 blast damage in pink outline." % view["enemies"][0]["hp"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e6a2c7"))

static func line(canvas: Object, font: Font, y: float, text: String, color: Color = Color("d6ded9"), size: int = 19) -> void:
	canvas.draw_string(font,Vector2(60,y),text,HORIZONTAL_ALIGNMENT_LEFT,1024,size,color)
