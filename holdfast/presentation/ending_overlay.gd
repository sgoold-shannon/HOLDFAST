extends RefCounted
## Draws detached display data; gameplay and modal input remain in the controller.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	if not view["available"] or view["scene_view"] != "": return
	var rect = view["DEPLOY_RECT"] if view["roster_open"] else view["ENDING_RECT"]
	canvas.draw_rect(rect,Color("344f46"))
	canvas.draw_string(font,rect.position+Vector2(10,29),"Ending logic test [Z]",HORIZONTAL_ALIGNMENT_LEFT,rect.size.x-20,19,Color.WHITE)

static func line(canvas: Object, font: Font, y: float, text: String, color: Color = Color("d6ded9"), size: int = 19) -> void:
	canvas.draw_string(font,Vector2(60,y),text,HORIZONTAL_ALIGNMENT_LEFT,1024,size,color)
