extends RefCounted
## Read-only display data; no controller or gameplay callbacks.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:

	for i in range(1, view["track"].size()):
		canvas.draw_line(projection.cell_anchor(view["track"][i-1]) + Vector2(18, 27), projection.cell_anchor(view["track"][i]) + Vector2(18, 27), Color("d1b48a"), 2)
	for fixture in view["FIXTURES"]:
		canvas.draw_rect(Rect2(projection.cell_anchor(fixture) + Vector2(4, 4), Vector2(28, 28)), Color("66727b"))
		canvas.draw_string(font, projection.cell_anchor(fixture) + Vector2(0, 24), "B" if fixture == view["breaker"] else "C", HORIZONTAL_ALIGNMENT_CENTER, 36, 16, Color.WHITE)
	if view["skid_visible"]:
		canvas.draw_string(font, projection.cell_anchor(view["skid"]) + Vector2(0, 12), "SKID", HORIZONTAL_ALIGNMENT_CENTER, 36, 10, Color("e8d9b4"))

	if view["next"] != view["NONE"]:
		canvas.draw_rect(Rect2(projection.cell_anchor(view["next"]) + Vector2(2, 2), Vector2(32, 32)), Color(1.0,0.5,0.1,0.3))
		canvas.draw_rect(Rect2(projection.cell_anchor(view["next"]) + Vector2(2, 2), Vector2(32, 32)), Color("ffb75a"), false, 3)
		canvas.draw_string(font, projection.cell_anchor(view["next"]) + Vector2(0, 12), "IMPACT", HORIZONTAL_ALIGNMENT_CENTER, 36, 9, Color("ffb75a"))
	var shot: Vector2i = view["machine"]["pending_shot"]
	if shot != view["NONE"]:
		canvas.draw_rect(Rect2(projection.cell_anchor(shot) + Vector2(3, 3), Vector2(30, 30)), Color(1.0,0.1,0.2,0.4))
		canvas.draw_rect(Rect2(projection.cell_anchor(shot) + Vector2(3, 3), Vector2(30, 30)), Color("ff6d78"), false, 3)
		canvas.draw_line(projection.cell_anchor(shot) + Vector2(4, 4), projection.cell_anchor(shot) + Vector2(32, 32), Color("ff6d78"), 2)
		canvas.draw_line(projection.cell_anchor(shot) + Vector2(32, 4), projection.cell_anchor(shot) + Vector2(4, 32), Color("ff6d78"), 2)
	if view["present"]:
		var center = projection.cell_anchor(view["enemies"][0]["cell"]) + Vector2(18, 18)
		var hull = PackedVector2Array([center+Vector2(-14,-8),center+Vector2(-8,-14),center+Vector2(8,-14),center+Vector2(14,-8),center+Vector2(14,10),center+Vector2(-14,10)])
		canvas.draw_colored_polygon(hull, Color("b34b42") if view["machine"]["hostile"] else Color("607e8f"))
		canvas.draw_rect(Rect2(center+Vector2(-17,-9),Vector2(5,23)),Color("192329"))
		canvas.draw_rect(Rect2(center+Vector2(12,-9),Vector2(5,23)),Color("192329"))
		canvas.draw_line(center,center+Vector2(-17,0),Color("f7cd6c"),5)
		canvas.draw_circle(center,5,Color("ff6d78") if view["machine"]["hostile"] else Color("8be6de"))
		canvas.draw_rect(Rect2(center+Vector2(-16,15),Vector2(32,3)),Color("17202a"))
		canvas.draw_rect(Rect2(center+Vector2(-16,15),Vector2(32.0*view["enemies"][0]["hp"]/16.0,3)),Color("f7cd6c"))
		if view["sight_mode"] and view["pinned_target"] == view["enemies"][0]["cell"]:
			for direction in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				canvas.draw_rect(Rect2(projection.cell_anchor(view["enemies"][0]["cell"] + direction) + Vector2(1, 1), Vector2(34, 34)), Color("e6a2c7"), false, 1)
