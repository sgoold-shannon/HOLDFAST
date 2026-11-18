extends Node3D
## Design blockout only. No encounter controller, commands, saves or collision rules.
var camera: Camera3D
var environment: Environment
var sun: DirectionalLight3D
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
func person(at: Vector3, color: String, scale_value: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE*scale_value
	add_child(root)
	for x in [-0.13,0.13]:
		box(root,Vector3(x,0.30,0),Vector3(0.18,0.60,0.2),"39423b")
		box(root,Vector3(x,0.05,-0.06),Vector3(0.2,0.13,0.32),"33332c")
	box(root,Vector3(0,0.89,0),Vector3(0.48,0.60,0.28),color)
	for x in [-0.32,0.32]: box(root,Vector3(x,0.83,0),Vector3(0.14,0.55,0.17),color)
	sphere(root,Vector3(0,1.37,0),0.17,"bba18a")
	return root
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
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(-12,15,13)
	add_child(camera)
	camera.look_at(Vector3(0,0.3,0))
	camera.size = 16
	camera.current = true
	box(self,Vector3(0,-0.12,0),Vector3(10,0.2,10),"666c52")
	box(self,Vector3(0,0,0),Vector3(9.9,0.06,3.0),"535b5c")
	for x in range(-4,5,2): box(self,Vector3(x,0.04,0),Vector3(0.7,0.015,0.07),"b8af88")
	# One-unit footprint marks establish relative scale, not a new tactical map.
	for x in range(-5,6): box(self,Vector3(x,0.005,0),Vector3(0.012,0.012,10),"7c806c")
	for z in range(-5,6): box(self,Vector3(0,0.005,z),Vector3(10,0.012,0.012),"7c806c")
	box(self,Vector3(-0.5,0.35,-2),Vector3(1.8,0.7,0.3),"999b8f")
	box(self,Vector3(2.4,0.75,-2),Vector3(1,1.5,0.35),"999b8f")
	label("LOW COVER",Vector3(-0.5,1,-2))
	label("FULL WALL",Vector3(2.4,2,-2))
	var soldier := person(Vector3(-3,0,1),"646a4d")
	soldier.rotation.y = -PI/2
	box(soldier,Vector3(0,0.92,0.25),Vector3(0.32,0.5,0.23),"444d3c")
	box(soldier,Vector3(-0.15,1.45,0.25),Vector3(0.025,0.7,0.025),"292f29")
	helmet = sphere(soldier,Vector3(0,1.46,0),0.20,"555e45")
	cap = box(soldier,Vector3(0,1.48,-0.04),Vector3(0.36,0.10,0.46),"6b7052")
	cap.hide()
	label("MSG / RADIO PROFILE",Vector3(-3,2.1,1))
	for i in range(4):
		var civilian := person(Vector3(-0.7+(i%2)*0.48,0,1.7+(i/2)*0.48),["98785c","c2b89b","596a70","8d9778"][i],0.65)
		box(civilian,Vector3(0,0.88,0.23),Vector3(0.26,0.35,0.17),"655846")
	label("ONE COHORT / FOUR PEOPLE",Vector3(-0.5,1.8,2))
	build_machine(Vector3(2,0,0.5))
	label("MACHINE A / SHAPE STUDY",Vector3(2,2,0.5))
	for x in [-3,3]:
		box(self,Vector3(x,1.3,-3.6),Vector3(0.08,2.6,0.08),"434b4d")
		box(self,Vector3(x,2.55,-3.6),Vector3(0.35,0.12,0.22),"b8a57c")
		var light := OmniLight3D.new()
		light.position = Vector3(x,2.5,-3.6)
		light.light_color = Color("ffcf91")
		light.omni_range = 5.5
		add_child(light)
		lamps.append(light)
	build_hud()
	apply_light()
func build_machine(at: Vector3) -> void:
	var machine := Node3D.new()
	machine.position = at
	machine.rotation.y = PI/2
	add_child(machine)
	box(machine,Vector3(0,0.15,0),Vector3(0.9,0.25,0.9),"3e4842")
	# Layered arch leaves the front cargo opening unobstructed.
	for x in [-0.34,0.34]:
		box(machine,Vector3(x,0.50,0),Vector3(0.22,0.7,0.84),"9a9983")
		var shoulder := box(machine,Vector3(x*0.75,0.88,0.05),Vector3(0.27,0.25,0.74),"8b907a")
		shoulder.rotation.z = -sign(x)*0.45
	box(machine,Vector3(0,1.0,0.07),Vector3(0.42,0.2,0.7),"747e69")
	box(machine,Vector3(0,0.60,0.37),Vector3(0.68,0.65,0.12),"898c7b")
	box(machine,Vector3(-0.23,0.35,-0.37),Vector3(0.13,0.1,0.25),"535d50")
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
	var title := Label.new()
	title.position = Vector2(24,20)
	title.text = "HOLDFAST / VISUAL BENCHMARK\nEarly shape study — no gameplay or finished art"
	title.add_theme_font_size_override("font_size",23)
	layer.add_child(title)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 24
	panel.offset_right = -24
	panel.offset_top = -150
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
	environment.ambient_light_energy = 0.45 if night else 0.7
	sun.light_color = Color("b8cad6") if night else Color("fff0d5")
	sun.light_energy = 0.3 if night else 1.1
	for light in lamps: light.light_energy = 1.2 if night else 0.0
	phase_label.text = "Night → Day" if night else "Day → Night"
func toggle_headgear() -> void:
	helmet.visible = not helmet.visible
	cap.visible = not helmet.visible
	headgear_label.text = "Helmet → Cap" if helmet.visible else "Cap → Helmet"
func toggle_cargo() -> void:
	cargo.visible = not cargo.visible
	cargo_label.text = "Loaded → Empty" if cargo.visible else "Empty → Loaded"
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index==MOUSE_BUTTON_WHEEL_UP: camera.size = maxf(7,camera.size-0.5)
		if event.button_index==MOUSE_BUTTON_WHEEL_DOWN: camera.size = minf(20,camera.size+0.5)
	if event is InputEventKey and event.pressed and event.keycode==KEY_HOME: camera.size = 16
func close() -> void:
	if get_tree().current_scene==self: get_tree().change_scene_to_file("res://farm_final.tscn")
	else: queue_free()
func _exit_tree() -> void:
	if is_instance_valid(readability):
		readability.set_process(true)
		readability.set_process_input(true)
		for child in readability.get_children():
			if child is CanvasLayer: child.visible = true
