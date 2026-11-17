extends Node3D
## 3D movement practice using the existing encounter rules; campaign stays untouched.
const MovementSession = preload("res://presentation3d/movement_session.gd")
var session := MovementSession.new()
var squad_models: Array[Node3D] = []
var squad_buttons: Array[Button] = []
var range_nodes: Array[Node3D] = []
var path_nodes: Array[Node3D] = []
var hovered := Vector2i(-1,-1)
var display: Dictionary
const Mission = preload("res://missions/farm_road.tres")
const NAMES := ["MSG · PSYOP", "Ortiz · Medic", "Bell · Engineer", "Park · Recon"]
const COLORS := [Color("e4bf60"),Color("73d5ac"),Color("78acdc"),Color("c393d9")]
var camera: Camera3D
var selection: MeshInstance3D
var detail: Label
var selected := Vector2i(-1,-1)
var warning: MeshInstance3D
var elapsed := 0.0
var readability: Node

func world(cell: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3(cell.x-(Mission.grid_size.x+1)*0.5,height,cell.y-(Mission.grid_size.y+1)*0.5)

func cell_at(screen: Vector2) -> Vector2i:
	var hit = Plane(Vector3.UP,0.0).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
	if hit == null: return Vector2i(-1,-1)
	var cell := Vector2i(floori(hit.x+(Mission.grid_size.x+1)*0.5+0.5),floori(hit.z+(Mission.grid_size.y+1)*0.5+0.5))
	return cell if cell.x>=1 and cell.x<=Mission.grid_size.x and cell.y>=1 and cell.y<=Mission.grid_size.y else Vector2i(-1,-1)

func material(color: Color, glow: bool = false) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.85
	if glow:
		result.emission_enabled = true
		result.emission = color
		result.emission_energy_multiplier = 0.65
	return result

func mesh(shape: Mesh, at: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = shape
	node.material_override = material(color,glow)
	node.position = at
	add_child(node)
	return node

func box(at: Vector3, size: Vector3, color: Color, glow: bool = false) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return mesh(shape,at,color,glow)

func cylinder(at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	return mesh(shape,at,color)

func label3d(text: String, at: Vector3, color: Color, size: int = 32) -> void:
	var node := Label3D.new()
	node.text = text
	node.font_size = size
	node.pixel_size = 0.018
	node.modulate = color
	node.outline_size = 7
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.no_depth_test = true
	node.position = at
	add_child(node)

func person(at: Vector3, color: Color, scale_value: float = 1.0) -> void:
	cylinder(at+Vector3(0,0.40*scale_value,0),0.18*scale_value,0.55*scale_value,color)
	var head := SphereMesh.new()
	head.radius = 0.14*scale_value
	head.height = 0.28*scale_value
	mesh(head,at+Vector3(0,0.80*scale_value,0),Color("dfc5a6"))
	for offset in [-0.10,0.10]:
		box(at+Vector3(offset*scale_value,0.10*scale_value,0),Vector3(0.12,0.22,0.17)*scale_value,Color("283d3a"))

func _ready() -> void:
	session.setup(self)
	readability = get_node_or_null("/root/Readability")
	if readability:
		readability.set_process(false)
		readability.set_process_input(false)
		for child in readability.get_children():
			if child is CanvasLayer: child.visible = false
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("111b24")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b8c7d5")
	environment.environment.ambient_light_energy = 0.65
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-30,0)
	sun.light_color = Color("ffe2b2")
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.position = Vector3(-27,29,20)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	fit_camera()
	get_viewport().size_changed.connect(fit_camera)
	box(Vector3(0,-0.30,0),Vector3(20.5,0.45,16.5),Color("273330"))
	for y in range(1,17):
		for x in range(1,21):
			var cell := Vector2i(x,y)
			var color := Color("495a4c") if (x+y)%2==0 else Color("425345")
			if y in [7,8,9]: color = Color("666761") if (x+y)%2==0 else Color("5c605b")
			if cell in Mission.squad_exits: color = Color("2b9a8d")
			box(world(cell,-0.04),Vector3(0.97,0.12,0.97),color)
	for cell in Mission.walls: box(world(cell,0.75),Vector3(0.94,1.5,0.94),Color("84908b"))
	for cell in Mission.cover_edges:
		var edge := -0.42 if Mission.cover_edges[cell]=="north" else 0.42
		box(world(cell,0.25)+Vector3(0,0,edge),Vector3(0.88,0.5,0.16),Color("8c9e91"))
	for cell in Mission.fixtures:
		box(world(cell,0.35),Vector3(0.55,0.7,0.5),Color("526878"))
		box(world(cell,0.72),Vector3(0.4,0.05,0.3),Color("78c7cd"),true)
	for x in range(1,21): label3d(str(x),world(Vector2i(x,0),0.08),Color("a6b8b7"),24)
	for y in range(1,17): label3d(str(y),world(Vector2i(0,y),0.08),Color("a6b8b7"),24)
	for i in range(4):
		var previous_children := get_children()
		var at := world(Mission.squad_spawns[i])
		cylinder(at+Vector3(0,0.04,0),0.39,0.06,COLORS[i])
		person(at,COLORS[i])
		# Role silhouettes: radio antenna, medic pack, engineer tools, recon optic.
		if i==0: box(at+Vector3(-0.2,0.85,0.12),Vector3(0.035,0.85,0.035),COLORS[i])
		if i==1: box(at+Vector3(0,0.4,0.22),Vector3(0.32,0.38,0.22),Color("f0eadd"))
		if i==2: box(at+Vector3(0.27,0.24,0),Vector3(0.25,0.26,0.36),COLORS[i])
		if i==3: box(at+Vector3(0.22,0.5,-0.18),Vector3(0.13,0.13,0.55),Color("27313d"))
		label3d(["MSG","ORTIZ","BELL","PARK"][i],at+Vector3(0,1.22,0),COLORS[i],28)
		# Put the whole figure under an actor transform, facing east (toward the machine).
		var pieces := get_children().filter(func(child): return not previous_children.has(child))
		var actor := Node3D.new()
		add_child(actor)
		actor.position = at
		for piece in pieces:
			piece.position -= at
			piece.reparent(actor,false)
		actor.rotation.y = -PI/2.0
		squad_models.append(actor)
	for i in range(3):
		var at := world(Mission.civilian_spawns[i])
		for offset in [Vector3(-0.23,0,-0.23),Vector3(0.23,0,-0.23),Vector3(-0.23,0,0.23),Vector3(0.23,0,0.23)]: person(at+offset,Color("c7b99a"),0.65)
		label3d("GROUP "+["A","B","C"][i],at+Vector3(0,1.0,0),Color("eedcba"),26)
	var machine_at := world(Mission.machine_spawn)
	box(machine_at+Vector3(0,0.5,0),Vector3(0.72,0.65,0.82),Color("b18442"))
	for x in [-0.39,0.39]: box(machine_at+Vector3(x,0.20,0),Vector3(0.17,0.30,0.95),Color("202a30"))
	box(machine_at+Vector3(0,0.82,0),Vector3(0.47,0.22,0.45),Color("677a81"))
	box(machine_at+Vector3(-0.26,0.8,0),Vector3(0.05,0.10,0.2),Color("ffcf66"),true)
	label3d("MACHINE",machine_at+Vector3(0,1.45,0),Color("ffcf66"),28)
	box(world(Mission.skid_cell,0.14),Vector3(0.65,0.25,0.65),Color("ad8760"))
	warning = box(world(Mission.machine_patrol[1],0.04),Vector3(0.92,0.04,0.92),Color("d58d38"),true)
	label3d("!",world(Mission.machine_patrol[1],0.18),Color("ffe1a1"),32)
	label3d("EVACUATION",world(Mission.civilian_exit,0.25),Color("9df9df"),30)
	selection = box(Vector3.ZERO,Vector3(1.01,0.035,1.01),Color("a4f3df"),true)
	selection.visible = false
	build_hud()
	refresh_movement()

func fit_camera() -> void:
	var size := get_viewport().get_visible_rect().size
	camera.size = maxf(23.0,31.0*size.y/maxf(size.x,1.0))

func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var back := Button.new()
	back.text = "Back to demo"
	back.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	back.offset_left = -200
	back.offset_right = -20
	back.offset_top = 20
	back.offset_bottom = 68
	back.add_theme_font_size_override("font_size",22)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close_preview)
	layer.add_child(back)
	var title := Label.new()
	title.position = Vector2(24,20)
	title.text = "HOLDFAST / FARM ROAD\n3D MOVEMENT PRACTICE"
	title.add_theme_font_size_override("font_size",25)
	layer.add_child(title)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 20
	panel.offset_right = -20
	panel.offset_top = -210
	panel.offset_bottom = -20
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,16)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",10)
	margin.add_child(stack)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	stack.add_child(row)
	for i in range(4):
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",20)
		button.add_theme_color_override("font_color",COLORS[i])
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(select_actor.bind(i))
		row.add_child(button)
		squad_buttons.append(button)
	var reset := Button.new()
	reset.text = "Reset practice"
	reset.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	reset.offset_left = -200
	reset.offset_right = -20
	reset.offset_top = 78
	reset.offset_bottom = 122
	reset.add_theme_font_size_override("font_size",20)
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(reset_practice)
	layer.add_child(reset)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size",20)
	stack.add_child(detail)
	detail.text = "Select a soldier. Green = 1 AP; blue = 2 AP.\nHover to preview a route; click a reachable cell to move. Practice does not change your campaign."

func select_cell(cell: Vector2i) -> void:
	if cell==Vector2i(-1,-1): return
	selected = cell
	selection.position = world(cell,0.07)
	selection.visible = true
	var description := "Open ground"
	if cell in Mission.walls: description = "Wall · blocks movement and sight"
	elif cell in Mission.fixtures: description = "Breaker" if cell==Mission.breaker_cell else "Protocol console"
	elif session.actor_at(cell)>=0: description = NAMES[session.actor_at(cell)]
	elif cell in Mission.civilian_spawns: description = "Civilian group "+["A","B","C"][Mission.civilian_spawns.find(cell)]+" · 4 people"
	elif cell==Mission.machine_spawn: description = "Neutral machine · firing makes it hostile"
	elif cell==Mission.machine_patrol[1]: description = "Next machine step · impact danger: 4 damage if occupied"
	elif cell==Mission.civilian_exit: description = "Civilian exit · ordered groups evacuate automatically"
	elif cell in Mission.squad_exits: description = "Squad extraction · 1 AP in the playable demo"
	elif Mission.cover_edges.has(cell): description = "Low cover · "+Mission.cover_edges[cell]+" edge"
	detail.text = "CELL (%d, %d)  /  %s\nSelect a soldier to move · Scroll to zoom · Home to fit · Practice does not change your campaign" % [cell.x,cell.y,description]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		preview_route(cell_at(event.position))
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_LEFT: activate_cell(pick_cell(event.position))
		elif event.button_index==MOUSE_BUTTON_WHEEL_UP: camera.size = maxf(12.0,camera.size-1.5)
		elif event.button_index==MOUSE_BUTTON_WHEEL_DOWN: camera.size = minf(60.0,camera.size+1.5)
	elif event is InputEventKey and event.pressed and event.keycode==KEY_HOME: fit_camera()

func _process(delta: float) -> void:
	elapsed += delta
	warning.scale = Vector3.ONE*(0.95+0.04*sin(elapsed*3.0))

func _exit_tree() -> void:
	if is_instance_valid(readability):
		readability.set_process(true)
		readability.set_process_input(true)
		for child in readability.get_children():
			if child is CanvasLayer: child.visible = true

func close_preview() -> void:
	if get_tree().current_scene == self:
		get_tree().change_scene_to_file("res://farm_final.tscn")
	else:
		queue_free()

func clear_nodes(nodes: Array[Node3D]) -> void:
	for node in nodes: node.free()
	nodes.clear()

func select_actor(index: int) -> void:
	session.select(index)
	hovered = Vector2i(-1,-1)
	refresh_movement()

func reset_practice() -> void:
	session.reset()
	hovered = Vector2i(-1,-1)
	for actor in squad_models: actor.rotation.y = -PI/2.0
	refresh_movement()

func refresh_movement() -> void:
	display = session.view(hovered)
	clear_nodes(range_nodes)
	for cell in display["reachable"]:
		var color := Color("307a61") if display["reachable"][cell]==1 else Color("356495")
		range_nodes.append(box(world(cell,0.035),Vector3(0.89,0.02,0.89),color))
	for i in range(4):
		var soldier: Dictionary = display["soldiers"][i]
		squad_models[i].position = world(soldier["cell"])
		squad_buttons[i].text = "%s%s  |  %d HP · %d AP" % ["> " if i==display["active"] else "",soldier["name"],soldier["hp"],soldier["ap"]]
	selection.visible = display["active"]>=0
	if selection.visible: selection.position = world(display["soldiers"][display["active"]]["cell"],0.07)
	preview_route(hovered,true)

func preview_route(cell: Vector2i, force: bool = false) -> void:
	if cell==hovered and not force: return
	hovered = cell
	display = session.view(cell)
	clear_nodes(path_nodes)
	if display["cost"]>0:
		for step in display["path"]:
			path_nodes.append(cylinder(world(step,0.10),0.10,0.05,Color("f7d580")))
	var active: int = display["active"]
	if active<0:
		detail.text = "Select a soldier. Green = 1 AP; blue = 2 AP.\nHover for a route; click a reachable cell to move. Practice does not change your campaign."
	else:
		var soldier: Dictionary = display["soldiers"][active]
		var route := "Move to (%d, %d): %d AP · %d squares" % [cell.x,cell.y,display["cost"],display["path"].size()-1] if display["cost"]>0 else ("No AP left. Select another soldier or Reset practice." if soldier["ap"]==0 else "Hover a highlighted cell to preview its route. Other cells cannot be reached.")
		detail.text = "%s · %d/8 HP · %d AP  |  Green 1 AP / Blue 2 AP\n%s\nPractice only · Back to demo preserves your campaign." % [NAMES[active],soldier["hp"],soldier["ap"],route]

func activate_cell(cell: Vector2i) -> void:
	var index: int = session.actor_at(cell)
	if index>=0:
		select_actor(index)
		return
	var state := session.view(cell)
	if state["cost"]<=0:
		select_cell(cell)
		return
	var actor: int = state["active"]
	var route: Array = state["path"]
	if session.move(cell):
		if route.size()>1:
			var delta: Vector2i = route[-1]-route[-2]
			squad_models[actor].rotation.y = atan2(-float(delta.x),-float(delta.y))
		refresh_movement()

func pick_cell(screen: Vector2) -> Vector2i:
	# Prefer visible figure bodies near the pointer, then the terrain plane.
	var closest := 20.0
	var result := Vector2i(-1,-1)
	for soldier in session.view()["soldiers"]:
		var distance := camera.unproject_position(world(soldier["cell"],0.5)).distance_to(screen)
		if distance<closest:
			closest = distance
			result = soldier["cell"]
	return cell_at(screen) if result==Vector2i(-1,-1) else result
