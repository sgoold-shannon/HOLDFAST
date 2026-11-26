extends RefCounted
## Stateless terrain renderer. Only detached display data and projection enter here.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	for y in range(1, view["size"].y + 1):
		for x in range(1, view["size"].x + 1):
			var cell := Vector2i(x, y)
			var rect: Rect2 = Rect2(projection.cell_anchor(cell), Vector2.ONE * view["cell_size"])
			var cost := int(view["costs"].get(cell,0))
			if view.get("art",false):
				# Rendered art underneath: only tint reachable squares and keep a faint grid.
				if cost > 0: canvas.draw_rect(rect, Color(0.25,0.85,0.65,0.30) if cost == 1 else Color(0.35,0.55,1.0,0.30))
				canvas.draw_rect(rect, Color(0,0,0,0.10), false, 1.0)
			else:
				var fill := Color("24352e") if (x + y) % 2 == 0 else Color("293b33")
				if cost > 0:
					fill = Color("315b50") if cost == 1 else Color("304965")
				if view["walls"].has(cell):
					fill = Color("66727b")
				canvas.draw_rect(rect, fill)
				canvas.draw_rect(rect, Color("42554a"), false, 1.0)
			if view["walls"].has(cell) and not view.get("art",false):
				canvas.draw_line(rect.position + Vector2(10, 10), rect.end - Vector2(10, 10), Color("e4e8ec"), 2.0)
				canvas.draw_line(rect.position + Vector2(26, 10), rect.position + Vector2(10, 26), Color("e4e8ec"), 2.0)
			if cost > 0:
				canvas.draw_string(font, rect.position + Vector2(3, 13), str(cost), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("b7c9c0"))
			if view["exits"].has(cell):
				canvas.draw_rect(rect.grow(-2), Color("8be6de"), false, 2)
				canvas.draw_string(font, rect.position + Vector2(0, 25), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, view["cell_size"], 10, Color("8be6de"))
			if cell == view["selected"]:
				canvas.draw_rect(rect.grow(-3), Color("f7cd6c"), false, 3.0)
	for x in range(1, view["size"].x + 1):
		canvas.draw_string(font, Vector2(view["origin"].x + (x - 1) * view["cell_size"], 85), str(x), HORIZONTAL_ALIGNMENT_CENTER, view["cell_size"], 16, Color("d6ded9"))
	for y in range(1, view["size"].y + 1):
		canvas.draw_string(font, Vector2(31, view["origin"].y + (y - 1) * view["cell_size"] + 24), str(y), HORIZONTAL_ALIGNMENT_RIGHT, 28, 16, Color("d6ded9"))
