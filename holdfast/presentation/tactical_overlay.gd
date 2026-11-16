extends RefCounted
## Read-only movement, sight and cover display; no pathfinding or combat rules.
static func render(canvas: Object, projection: RefCounted, view: Dictionary) -> void:
	var path: Array = view["path"]
	for i in range(1,path.size()):
		canvas.draw_line(projection.cell_anchor(path[i-1])+Vector2(18,18),projection.cell_anchor(path[i])+Vector2(18,18),Color("f7cd6c"),3.0)
	var aim: Dictionary = view["aim"]
	if not aim.is_empty():
		for cell in aim["cells"]:
			canvas.draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(2,2),Vector2(32,32)),Color(0.85,0.8,0.4,0.18))
		for cell in aim["blockers"]:
			canvas.draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(2,2),Vector2(32,32)),Color("f27b79"),false,3)
		canvas.draw_line(projection.cell_anchor(aim["source"])+Vector2(18,18),projection.cell_anchor(aim["target"])+Vector2(18,18),Color("9ae2c4") if aim["clear"] else Color("f27b79"),2)
		canvas.draw_rect(Rect2(projection.cell_anchor(aim["target"])+Vector2(4,4),Vector2(28,28)),Color.WHITE,false,2)
	for cell in view["cover"]:
		var origin: Vector2 = projection.cell_anchor(cell)
		var edge_y: float = 2.0 if view["cover"][cell]=="north" else view["cell_size"]-2.0
		var color := Color("7ed4ee")
		if not aim.is_empty() and aim["target"]==cell and aim["protected"]: color = Color("f7cd6c")
		canvas.draw_line(origin+Vector2(3,edge_y),origin+Vector2(33,edge_y),color,5)
