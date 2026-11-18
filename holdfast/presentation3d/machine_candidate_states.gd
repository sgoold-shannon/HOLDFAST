extends RefCounted
## Static art-review poses only. No encounter state, targeting, collision or animation.
const NAMES := ["Working", "Paused", "Hostile", "Charged", "Disabled", "Destroyed"]
var model: Node3D
var shoulder: Node3D
var shoulder_rest: Transform3D
var emitter: MeshInstance3D
var emitter_rest: Transform3D
var lamps: Array[StandardMaterial3D] = []
var emitter_material: StandardMaterial3D
var index := 0
var wreck: Node3D
var intact_roots: Array[Node] = []

func _init(asset: Node3D) -> void:
	model = asset
	var original_roots := model.get_children()
	var intact := Node3D.new()
	intact.name = "IntactPresentation"
	model.add_child(intact)
	for child in original_roots: child.reparent(intact)
	intact_roots = [intact]
	wreck = preload("res://assets/machine_a/machine_a_wreck_01.glb").instantiate()
	model.add_child(wreck)
	wreck.hide()
	shoulder = model.find_child("ToolShoulder",true,false)
	shoulder_rest = shoulder.transform
	emitter = model.find_child("DefensiveEmitter",true,false)
	emitter_rest = emitter.transform
	for node in model.find_child("WorkLights",true,false).get_children():
		if node is MeshInstance3D and str(node.name).begins_with("WorkLamp"):
			var material: StandardMaterial3D = node.get_active_material(0).duplicate()
			node.material_override = material
			lamps.append(material)
	emitter_material = emitter.get_active_material(0).duplicate()
	emitter.material_override = emitter_material
	apply(0)

func apply(value: int) -> void:
	index = clampi(value,0,NAMES.size()-1)
	for child in intact_roots: child.visible = index!=5
	wreck.visible = index==5
	shoulder.transform = shoulder_rest
	emitter.transform = emitter_rest
	# Static pose proposals: stow inward; defensive posture retracts the recovery tool.
	if index==1: shoulder.rotation.z += deg_to_rad(28)
	if index==2 or index==3: shoulder.rotation.z += deg_to_rad(45)
	if index==4: shoulder.rotation.z += deg_to_rad(12)
	for material in lamps:
		material.albedo_color = Color("302e27") if index>=4 else Color("e6bd65")
		material.emission_enabled = index<4
		material.emission = Color("dba04c") if index<4 else Color.BLACK
		material.emission_energy_multiplier = 0.7 if index<4 else 0.0
	# Charged aperture extends and widens, giving a shape cue in silhouette too.
	if index==3:
		emitter.scale = emitter_rest.basis.get_scale()*Vector3(1.7,1.7,1.8)
		emitter.position.z += 0.025
	emitter_material.albedo_color = Color("ff9147") if index==3 else Color("272b24")
	emitter_material.emission_enabled = index==3
	emitter_material.emission = Color("ff752b") if index==3 else Color.BLACK
	emitter_material.emission_energy_multiplier = 1.4 if index==3 else 0.0
