extends RefCounted
## Marker appearance only; eligibility and state are resolved by the caller.
static func soldier(canvas: Object, font: Font, center: Vector2, marker: Dictionary) -> void:
	var color: Color = marker["color"]
	canvas.draw_rect(Rect2(center-Vector2(12,10),Vector2(24,24)),Color("14221d"))
	match int(marker["shape"]):
		0: canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(0,-15),center+Vector2(14,0),center+Vector2(0,15),center+Vector2(-14,0)]),color)
		1:
			canvas.draw_rect(Rect2(center-Vector2(5,14),Vector2(10,28)),color)
			canvas.draw_rect(Rect2(center-Vector2(14,5),Vector2(28,10)),color)
		2: canvas.draw_rect(Rect2(center-Vector2(13,13),Vector2(26,26)),color)
		3: canvas.draw_colored_polygon(PackedVector2Array([center+Vector2(0,-15),center+Vector2(15,13),center+Vector2(-15,13)]),color)
	canvas.draw_string(font,center+Vector2(-12,6),marker["mark"],HORIZONTAL_ALIGNMENT_CENTER,24,17,Color("14221d"))
	if marker["selected"]: canvas.draw_arc(center,17,0,TAU,24,Color.WHITE,2)
