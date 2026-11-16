extends RefCounted
## Shared small screen decorations. Callers choose visibility; no gameplay state is read.
static func header(canvas: Object, font: Font, text: String, width: float = 790, color: Color = Color.WHITE) -> void:
	canvas.draw_rect(Rect2(35,10,width,34),Color("0e1412"))
	canvas.draw_string(font,Vector2(40,36),text,HORIZONTAL_ALIGNMENT_LEFT,-1,24,color)

static func button(canvas: Object, font: Font, rect: Rect2, text: String, color: Color, baseline: float, size: int) -> void:
	canvas.draw_rect(rect,color)
	canvas.draw_string(font,rect.position+Vector2(0,baseline),text,HORIZONTAL_ALIGNMENT_CENTER,320,size,Color.WHITE)

static func rescue_guide(canvas: Object, font: Font) -> void:
	canvas.draw_rect(Rect2(35,46,800,28),Color("0e1412"))
	canvas.draw_string(font,Vector2(40,66),"RESCUE A + B + C: choose a group → Move to EXIT → End turn [N].",HORIZONTAL_ALIGNMENT_LEFT,790,18,Color("8be6de"))

static func sandbox_header(canvas: Object, font: Font) -> void:
	canvas.draw_string(font,Vector2(40,36),"HOLDFAST  /  A6 SAVE & REPLAY",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("e5e9e7"))
	canvas.draw_string(font,Vector2(40,62),"T: move / aim | F: fire | R: reload | N: end turn | E: extract | Esc: clear",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("aebbb6"))
