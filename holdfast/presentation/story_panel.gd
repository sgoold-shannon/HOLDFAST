extends RefCounted
## Draws detached display data; gameplay and modal input remain in the controller.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	canvas.draw_rect(Rect2(0,0,1144,1224),Color("0e1412"))
	var pages = view["pages"]
	var page: Dictionary = pages[clampi(view["scene_page"],0,pages.size()-1)]
	line(canvas,font,65,"HOLDFAST / "+("SCENE LOG" if view["scene_view"] == "log" else ("OPENING" if view["scene_view"] == "opening" else "FARM ROAD DEBRIEF")),Color("8be6de"),20)
	line(canvas,font,125,page["speaker"],Color("f7cd6c"),26)
	canvas.draw_multiline_string(font,Vector2(60,207),page["text"],HORIZONTAL_ALIGNMENT_LEFT,1000,25,-1,Color("e2e9e5"))
	line(canvas,font,698,page["tag"],Color("8be6de"),17)
	line(canvas,font,735,"%d / %d" % [view["scene_page"]+1,pages.size()],Color("aebbb6"),17)
	var options = view["options"]
	for index in range(options.size()):
		var rect = Rect2(60,770+index*70,980,58)
		canvas.draw_rect(rect,Color("304965"))
		canvas.draw_string(font,rect.position+Vector2(18,37),"%d · %s" % [index+1,options[index]],HORIZONTAL_ALIGNMENT_LEFT,940,21,Color.WHITE)
	for item in [[view["NEXT_RECT"],"Choose 1–3 above" if view["scene_view"] == "opening" and view["scene_page"] == 0 else ("Next [Enter]" if view["scene_page"]+1 < pages.size() else ("Begin mission [Enter]" if view["scene_view"] == "opening" else "Return [Enter]"))],[view["SKIP_RECT"],"Skip opening [Esc]" if view["scene_view"] == "opening" else "Return [Esc]"],[view["LOG_RECT"],"Close log [Tab]" if view["scene_view"] == "log" else "Scene log / intelligence [Tab]"]]:
		canvas.draw_rect(item[0],Color("34473e"))
		canvas.draw_string(font,item[0].position+Vector2(15,34),item[1],HORIZONTAL_ALIGNMENT_LEFT,item[0].size.x-25,20,Color.WHITE)
	line(canvas,font,1195,view["save_feedback"],Color("aebbb6"),15)

static func line(canvas: Object, font: Font, y: float, text: String, color: Color = Color("d6ded9"), size: int = 19) -> void:
	canvas.draw_string(font,Vector2(60,y),text,HORIZONTAL_ALIGNMENT_LEFT,1024,size,color)
