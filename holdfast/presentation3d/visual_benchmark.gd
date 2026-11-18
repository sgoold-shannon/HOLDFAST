extends Node3D
## Design blockout only. No encounter controller, commands, saves or collision rules.
var soldier: Node3D
var machine: Node3D
var civilians: Array[Node3D] = []
var selected_group := 0
var group_buttons: Array[Button] = []
var group_markers: Array[Label3D] = []
var stress_mode := 0
var stress_wall: MeshInstance3D
var extra_civilians: Array[Node3D] = []
var stress_button: Button
var silhouettes := false
var overlap := false
var focus_index := 0
var original_materials: Dictionary = {}
var inspection_labels: Array[Label3D] = []
var focus_button: Button
var silhouette_button: Button
var overlap_button: Button
var camera: Camera3D
var environment: Environment
var sun: DirectionalLight3D
var rim: DirectionalLight3D
var fixture_materials: Array[StandardMaterial3D] = []
var lamps: Array[OmniLight3D] = []
var night := false
var helmet: Node3D
var cap: Node3D
var cargo: Node3D
var machine_lamp: MeshInstance3D
var lamp_material: StandardMaterial3D
var status: Label
var readability: Node
var phase_label: Button
var headgear_label: Button
var cargo_label: Button

func mat(color: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color)
	m.roughness = 0.85
	return m
func shape(parent: Node3D, mesh: Mesh, at: Vector3, color: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.material_override = mat(color)
	parent.add_child(node)
	return node
func box(parent: Node3D, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return shape(parent,m,at,color)
func sphere(parent: Node3D, at: Vector3, radius: float, color: String) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius*2
	return shape(parent,m,at,color)
func label(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.position = at
	l.font_size = 28
	l.pixel_size = 0.009
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	add_child(l)
	inspection_labels.append(l)
func capsule(parent: Node3D, at: Vector3, radius: float, height: float, color: String) -> MeshInstance3D:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 12
	m.rings = 4
	return shape(parent,m,at,color)
func person(at: Vector3, color: String, scale_value: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE*scale_value
	add_child(root)
	for x in [-0.12,0.12]:
		capsule(root,Vector3(x,0.47,0),0.095,0.72,"39423b")
		box(root,Vector3(x,0.07,-0.05),Vector3(0.17,0.14,0.29),"33332c")
	var torso := capsule(root,Vector3(0,0.98,0),0.23,0.65,color)
	torso.scale.z = 0.65
	box(root,Vector3(0,0.96,-0.12),Vector3(0.38,0.38,0.09),"535b48")
	for x in [-0.28,0.28]:
		capsule(root,Vector3(x,0.93,0),0.075,0.53,color)
		sphere(root,Vector3(x,0.66,0),0.075,"bba18a")
	sphere(root,Vector3(0,1.40,0),0.15,"bba18a")
	return root
func shell_panel(parent: Node3D, theta0: float, theta1: float, phi0: float, phi1: float, color: String, inset: float = 1.0) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for u in range(4):
		for v in range(3):
			var points: Array[Vector3] = []
			for uv in [Vector2(u,v),Vector2(u+1,v),Vector2(u+1,v+1),Vector2(u,v+1)]:
				var theta := lerpf(theta0,theta1,uv.x/4.0)
				var phi := lerpf(phi0,phi1,uv.y/3.0)
				points.append(Vector3(0.46*inset*cos(phi)*sin(theta),0.20+0.85*inset*sin(phi),-0.46*inset*cos(phi)*cos(theta)))
			for index in [0,2,1,0,3,2]:
				var point: Vector3 = points[index]
				surface.set_normal(Vector3(point.x/0.46,(point.y-0.2)/0.85,point.z/0.46).normalized())
				surface.add_vertex(point)
	var node := shape(parent,surface.commit(),Vector3.ZERO,color)
	node.material_override.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override.metallic = 0.28
	node.material_override.roughness = 0.62
func _ready() -> void:
	readability = get_node_or_null("/root/Readability")
	if readability:
		readability.set_process(false)
		readability.set_process_input(false)
		for child in readability.get_children():
			if child is CanvasLayer: child.visible = false
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-35,0)
	sun.shadow_enabled = true
	add_child(sun)
	rim = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-32,145,0)
	rim.light_color = Color("cbd5dc")
	add_child(rim)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(-12,15,13)
	add_child(camera)
	camera.look_at(Vector3(0,0.3,0))
	camera.size = 16
	camera.current = true
	box(self,Vector3(0,-0.12,0),Vector3(10,0.2,10),"666c52")
	var road := box(self,Vector3(0,0,0),Vector3(9.9,0.06,3.0),"41494b")
	road.material_override.roughness = 0.98
	for x in range(-4,5,2): box(self,Vector3(x,0.04,0),Vector3(0.7,0.015,0.07),"b8af88")
	# One-unit footprint marks establish relative scale, not a new tactical map.
	for x in range(-5,6): box(self,Vector3(x,0.005,0),Vector3(0.012,0.012,10),"7c806c")
	for z in range(-5,6): box(self,Vector3(0,0.005,z),Vector3(10,0.012,0.012),"7c806c")
	box(self,Vector3(-0.5,0.35,-2),Vector3(1.8,0.7,0.3),"999b8f")
	box(self,Vector3(2.4,0.75,-2),Vector3(1,1.5,0.35),"999b8f")
	label("LOW COVER",Vector3(-0.5,1,-2))
	label("FULL WALL",Vector3(2.4,2,-2))
	soldier = person(Vector3(-3,0,1),"646a4d")
	soldier.rotation.y = -PI/2
	box(soldier,Vector3(0,0.92,0.25),Vector3(0.32,0.5,0.23),"444d3c")
	box(soldier,Vector3(-0.15,1.45,0.25),Vector3(0.025,0.7,0.025),"292f29")
	helmet = sphere(soldier,Vector3(0,1.49,0),0.18,"555e45")
	cap = box(soldier,Vector3(0,1.51,-0.04),Vector3(0.36,0.10,0.46),"6b7052")
	cap.hide()
	label("MSG / RADIO PROFILE",Vector3(-3,2.1,1))
	for i in range(4):
		var civilian := person(Vector3(-0.7+(i%2)*0.48,0,1.7+(i/2)*0.48),["98785c","c2b89b","596a70","8d9778"][i],0.65)
		civilians.append(civilian)
		box(civilian,Vector3(0,0.88,0.23),Vector3(0.26,0.35,0.17),"655846")
	label("ONE COHORT / FOUR PEOPLE",Vector3(-0.5,1.8,2))
	build_machine(Vector3(2,0,0.5))
	label("MACHINE A / SHAPE STUDY",Vector3(2,2,0.5))
	for x in [-3,3]:
		box(self,Vector3(x,1.3,-3.6),Vector3(0.08,2.6,0.08),"434b4d")
		var fixture := box(self,Vector3(x,2.55,-3.6),Vector3(0.35,0.12,0.22),"b8a57c")
		var glow: StandardMaterial3D = fixture.material_override
		glow.emission_enabled = true
		glow.emission = Color("ffd7a1")
		fixture_materials.append(glow)
		var light := OmniLight3D.new()
		light.position = Vector3(x,2.5,-3.6)
		light.light_color = Color("ffcf91")
		light.omni_range = 7.5
		add_child(light)
		lamps.append(light)
	stress_wall = box(self,Vector3(0.55,0.75,1.94),Vector3(0.25,1.5,2),"999b8f")
	stress_wall.hide()
	for i in range(4):
		var extra := person(Vector3.ZERO,["70889b","9b8870","788d79","a69e88"][i],0.65)
		extra.hide()
		extra_civilians.append(extra)
	for group in [civilians,extra_civilians]:
		for i in range(group.size()):
			var marker := Label3D.new()
			marker.font_size = 32
			marker.pixel_size = 0.005
			marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			marker.no_depth_test = true
			marker.outline_size = 10
			add_child(marker)
			group_markers.append(marker)
	build_hud()
	refresh_group_markers()
	apply_light()
func build_machine(at: Vector3) -> void:
	machine = Node3D.new()
	machine.position = at
	machine.rotation.y = PI/2
	add_child(machine)
	box(machine,Vector3(0,0.15,0),Vector3(0.9,0.25,0.9),"3e4842")
	# Segmented dome; omit lower front panels to leave a true cargo aperture.
	for band in range(3):
		for sector in range(12):
			var middle := -PI+(sector+0.5)*TAU/12.0
			if band<2 and absf(middle)<0.85: continue
			shell_panel(machine,-PI+sector*TAU/12.0,-PI+(sector+1)*TAU/12.0,band*PI/6.0,(band+1)*PI/6.0,"424b40",0.985)
			shell_panel(machine,-PI+sector*TAU/12.0+0.018,-PI+(sector+1)*TAU/12.0-0.018,band*PI/6.0+0.012,(band+1)*PI/6.0-0.012,["8f947e","a09d86","77856f"][(sector+band)%3])
	for x in [-0.34,0.34]:
		box(machine,Vector3(x,0.10,-0.27),Vector3(0.18,0.14,0.25),"454d43")
		var tool := box(machine,Vector3(x*0.65,0.32,-0.34),Vector3(0.075,0.075,0.24),"596350")
		tool.rotation.y = sign(x)*0.35
	cargo = box(machine,Vector3(0,0.40,-0.10),Vector3(0.38,0.25,0.4),"737868")
	cargo.hide()
	machine_lamp = box(machine,Vector3(0,0.83,-0.34),Vector3(0.24,0.06,0.035),"e6bd65")
	lamp_material = machine_lamp.material_override
	lamp_material.emission_enabled = true
	lamp_material.emission = Color("dba04c")
	lamp_material.emission_energy_multiplier = 0.7
func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var header_bg := ColorRect.new()
	header_bg.color = Color("17232d")
	header_bg.position = Vector2(12,12)
	header_bg.size = Vector2(720,78)
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(header_bg)
	var title := Label.new()
	title.position = Vector2(24,20)
	title.text = "HOLDFAST / VISUAL BENCHMARK\nEarly shape study — no gameplay or finished art"
	title.add_theme_font_size_override("font_size",23)
	layer.add_child(title)
	var group_row := HBoxContainer.new()
	group_row.position = Vector2(24,105)
	group_row.add_theme_constant_override("separation",12)
	layer.add_child(group_row)
	for i in range(2):
		var button := Button.new()
		button.custom_minimum_size = Vector2(270,44)
		button.add_theme_font_size_override("font_size",20)
		button.pressed.connect(select_group.bind(i))
		group_row.add_child(button)
		group_buttons.append(button)
	var controls_bg := ColorRect.new()
	controls_bg.color = Color("17232d")
	controls_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controls_bg.offset_top = -220
	controls_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(controls_bg)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -210
	panel.add_theme_constant_override("separation",12)
	layer.add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	for action in ["Day / night","Helmet / cap","Empty / loaded","Back to demo"]:
		var button := Button.new()
		button.text = action
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size",22)
		button.custom_minimum_size.y = 46
		row.add_child(button)
		match action:
			"Day / night":
				phase_label = button
				button.pressed.connect(toggle_light)
			"Helmet / cap":
				headgear_label = button
				button.pressed.connect(toggle_headgear)
			"Empty / loaded":
				cargo_label = button
				button.pressed.connect(toggle_cargo)
			_: button.pressed.connect(close)
	var inspect_row := HBoxContainer.new()
	panel.add_child(inspect_row)
	for action in ["View: whole scene","Silhouettes: off","Overlap: off","Stress: off"]:
		var button := Button.new()
		button.text = action
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 46
		button.add_theme_font_size_override("font_size",20)
		inspect_row.add_child(button)
		match action:
			"View: whole scene":
				focus_button = button
				button.pressed.connect(cycle_focus)
			"Silhouettes: off":
				silhouette_button = button
				button.pressed.connect(toggle_silhouettes)
			"Stress: off":
				stress_button = button
				button.pressed.connect(cycle_stress)
			_:
				overlap_button = button
				button.pressed.connect(toggle_overlap)
	status = Label.new()
	status.add_theme_font_size_override("font_size",20)
	status.text = "Same geometry in both lighting conditions. Scroll: zoom · Home: reset view\nCompare silhouettes, cargo opening, cover heights and labels. No saves or mission changes."
	panel.add_child(status)
func toggle_light() -> void:
	night = not night
	apply_light()
func apply_light() -> void:
	environment.background_color = Color("111b25") if night else Color("64717b")
	environment.ambient_light_color = Color("9daebd") if night else Color("d6dcce")
	environment.ambient_light_energy = 0.32 if night else 0.48
	sun.light_color = Color("b8cad6") if night else Color("fff0d5")
	sun.light_energy = 0.48 if night else 0.85
	rim.light_energy = 0.42 if night else 0.12
	for light in lamps: light.light_energy = 1.7 if night else 0.0
	for glow in fixture_materials: glow.emission_energy_multiplier = 1.0 if night else 0.0
	phase_label.text = "Night → Day" if night else "Day → Night"
	if silhouettes: environment.background_color = Color("dadada")
func toggle_headgear() -> void:
	helmet.visible = not helmet.visible
	cap.visible = not helmet.visible
	headgear_label.text = "Helmet → Cap" if helmet.visible else "Cap → Helmet"
func toggle_cargo() -> void:
	cargo.visible = not cargo.visible
	cargo_label.text = "Loaded → Empty" if cargo.visible else "Empty → Loaded"
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: camera.size = maxf(3,camera.size-0.5)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: camera.size = minf(20,camera.size+0.5)
	if event is InputEventKey and event.pressed and event.keycode==KEY_HOME:
		focus_index = 0
		apply_focus()
func close() -> void:
	if get_tree().current_scene==self: get_tree().change_scene_to_file("res://farm_final.tscn")
	else: queue_free()
func _exit_tree() -> void:
	if is_instance_valid(readability):
		readability.set_process(true)
		readability.set_process_input(true)
		for child in readability.get_children():
			if child is CanvasLayer: child.visible = true

func cycle_focus() -> void:
	focus_index = (focus_index+1)%4
	apply_focus()
func apply_focus() -> void:
	var target := Vector3(0,0.3,0)
	match focus_index:
		1: target = soldier.position+Vector3(0,0.8,0)
		2: target = machine.position+Vector3(0,0.5,0)
		3: target = Vector3(-0.5,0.6,2)
	camera.position = target+Vector3(-12,14.7,13)
	camera.look_at(target)
	camera.size = 16 if focus_index==0 else 4
	focus_button.text = "View: "+["whole scene","soldier","Machine A","cohort"][focus_index]
	update_inspection_labels()
func update_inspection_labels() -> void:
	for l in inspection_labels: l.visible = not silhouettes and focus_index==0 and not overlap
func toggle_overlap() -> void:
	stress_mode = 0
	selected_group = 0
	if is_instance_valid(stress_wall): stress_wall.hide()
	for extra in extra_civilians: extra.hide()
	if is_instance_valid(stress_button): stress_button.text = "Stress: off"
	overlap = not overlap
	soldier.position = Vector3(-0.46,0,1.94) if overlap else Vector3(-3,0,1)
	var right := Vector3(13,0,12).normalized()
	var toward := Vector3(-12,0,13).normalized()
	var offsets := [Vector2(-0.65,0.05),Vector2(0.65,0.05),Vector2(-0.29,0.65),Vector2(0.29,0.65)]
	for i in range(civilians.size()):
		civilians[i].position = soldier.position+right*offsets[i].x+toward*offsets[i].y if overlap else Vector3(-0.7+(i%2)*0.48,0,1.7+(i/2)*0.48)
	overlap_button.text = "Overlap: on" if overlap else "Overlap: off"
	apply_focus()
	refresh_group_markers()
	status.text = "Shared-space study: figures spread visually around the soldier; no occupancy rules change.\nHome: wide view · Scroll: zoom · Back preserves your demo." if overlap else "Same geometry in day/night. View cycles scene, soldier, machine and cohort.\nSilhouettes remove color/detail. Home: wide view · Scroll: zoom."
func toggle_silhouettes() -> void:
	silhouettes = not silhouettes
	if silhouettes:
		for node in find_children("*","MeshInstance3D",true,false):
			original_materials[node] = node.material_override
			var actor: bool = soldier.is_ancestor_of(node) or machine.is_ancestor_of(node)
			for civilian in civilians+extra_civilians: actor = actor or civilian.is_ancestor_of(node)
			var flat := mat("151515" if actor else "d7d7d7")
			flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			flat.cull_mode = BaseMaterial3D.CULL_DISABLED
			node.material_override = flat
	else:
		for node in original_materials: node.material_override = original_materials[node]
		original_materials.clear()
	silhouette_button.text = "Silhouettes: on" if silhouettes else "Silhouettes: off"
	update_inspection_labels()
	apply_light()

func cycle_stress() -> void:
	var next_mode := (stress_mode+1)%3
	if not overlap: toggle_overlap()
	stress_mode = next_mode
	stress_wall.visible = stress_mode==1
	for i in range(extra_civilians.size()):
		extra_civilians[i].visible = stress_mode==2
		extra_civilians[i].position = civilians[i].position+Vector3(0.8,0,-0.4)
	stress_button.text = ["Stress: off","Stress: wall","Stress: 2 groups"][stress_mode]
	focus_index = 3
	apply_focus()
	camera.size = 5
	if stress_mode!=2: selected_group = 0
	refresh_group_markers()
	status.text = ["Shared-space formation; stress obstacles hidden.","Wall test: check figure bodies and equipment against the adjacent wall.","Two-group test: eight civilians share the display area. Check which figures become hidden."][stress_mode]+"\nVisual test only; no logical movement, collisions or group membership changes."

func select_group(index: int) -> void:
	if index==1 and stress_mode!=2: return
	selected_group = index
	refresh_group_markers()
	status.text = "Group %s selected: four numbered markers identify its members, including obscured figures." % ["A","B"][index]+"\nInspection markers show through objects; they do not grant gameplay sight or issue orders."
func refresh_group_markers() -> void:
	for i in range(group_buttons.size()):
		group_buttons[i].disabled = i==1 and stress_mode!=2
		group_buttons[i].text = "%sGroup %s · 4 people%s" % ["> " if selected_group==i else "",["A","B"][i]," · hidden" if i==1 and stress_mode!=2 else ""]
	for index in range(group_markers.size()):
		var group := index/4
		var member := index%4
		var actor: Node3D = civilians[member] if group==0 else extra_civilians[member]
		var marker := group_markers[index]
		marker.visible = group==selected_group and actor.visible
		marker.position = actor.position+Vector3(0,1.13,0)
		marker.text = "%s%d" % [["A","B"][group],member+1]
