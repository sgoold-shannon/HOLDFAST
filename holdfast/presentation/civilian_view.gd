extends RefCounted
## Read-only display data; no controller or gameplay callbacks.
static func render(canvas: Object, font: Font, projection: RefCounted, view: Dictionary) -> void:
	for waypoint in view["waypoints"]:
		canvas.draw_rect(Rect2(projection.cell_anchor(waypoint) + Vector2(2,2), Vector2(32,32)), Color("aabbe5"), false, 2)
	var selected_group: Dictionary = view["cohorts"][view["cohort_selected"]]
	if selected_group["status"] == "active":

		var previous: Vector2i = selected_group["cell"]
		for step in view["route"]:
			var a = projection.cell_anchor(previous) + Vector2(18,18)
			var b = projection.cell_anchor(step) + Vector2(18,18)
			canvas.draw_line(a, b, Color("8be6de"), 3)
			canvas.draw_circle(b, 3, Color("8be6de"))
			previous = step
	var exit_origin = projection.cell_anchor(view["exit"])
	canvas.draw_rect(Rect2(exit_origin, Vector2(36,36)), Color("178675"))
	canvas.draw_rect(Rect2(exit_origin, Vector2(36,36)), Color.WHITE, false, 3)
	canvas.draw_string(font, exit_origin + Vector2(0,24), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, 36, 13, Color.WHITE)
	for index in range(3):
		var cohort: Dictionary = view["cohorts"][index]
		if cohort["status"] == "active":
			if index == view["cohort_selected"]:
				canvas.draw_rect(Rect2(projection.cell_anchor(cohort["cell"])+Vector2(1,1),Vector2(34,34)), Color("8be6de"), false, 3)

			# Corner badges remain distinguishable when groups share a cell or soldier.
			var offset = Vector2(2 + index * 11, 2)
			canvas.draw_rect(Rect2(projection.cell_anchor(cohort["cell"]) + offset, Vector2(11,14)), Color("aabbe5"))
			canvas.draw_string(font, projection.cell_anchor(cohort["cell"]) + offset + Vector2(0,11), cohort["id"], HORIZONTAL_ALIGNMENT_CENTER, 11, 11, Color("17202a"))
