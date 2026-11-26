extends SceneTree
## Dev tool (not part of the game): renders HOLDFAST's 2D sprites from the 3D sources in
## res://render_src (Quaternius CC0 kits). Needs a real window, so run it without --headless:
##   godot --path holdfast --script res://tools/sprite_render.gd -- <job>
## Jobs: map, units, compose, all. Output goes to res://assets/sprites/.
const CELL_M := 2.0          # one board square is 2 m
const MAP_PX := 96           # map background pixels per square
const FRAME := Vector2i(128,160)
const OUT := "res://assets/sprites/"
const FACINGS := {"s":0.0,"e":90.0,"n":180.0,"w":-90.0}
const FACING_ORDER := ["s","e","n","w"]

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var anim_lib: AnimationLibrary
var textures := {}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	setup()
	var args := OS.get_cmdline_user_args()
	var job: String = args[0] if not args.is_empty() else "all"
	if job in ["all","map"]: await render_map("main_street")
	if job in ["all","units"]: await render_units()
	if job in ["all","compose"]: compose_look_test("main_street")
	print("SPRITES DONE")
	quit(0)

# ---------------------------------------------------------------- stage

func setup() -> void:
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = FRAME
	root.add_child(vp)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62,0.67,0.75)
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.5
	we.environment = env
	vp.add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0,0.94,0.84)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	sun.rotation_degrees = Vector3(-64,145,0)
	vp.add_child(sun)
	world = Node3D.new()
	vp.add_child(world)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.1
	cam.far = 400.0
	vp.add_child(cam)
	cam.current = true
	var ual: Node = load("res://render_src/anim/UAL1_Standard.glb").instantiate()
	var src: AnimationPlayer = ual.find_children("*","AnimationPlayer",true,false)[0]
	anim_lib = src.get_animation_library(src.get_animation_library_list()[0]).duplicate(true)
	ual.free()

func clear_world() -> void:
	for child in world.get_children(): child.free()

func snap(size: Vector2i) -> Image:
	vp.size = size
	for i in range(3): await RenderingServer.frame_post_draw
	return vp.get_texture().get_image()

func place(path: String, pos: Vector3, yaw: float = 0.0, scl: Vector3 = Vector3.ONE) -> Node3D:
	var scene: PackedScene = load("res://render_src/%s.gltf" % path)
	var node: Node3D = scene.instantiate()
	node.position = pos
	node.rotation_degrees.y = yaw
	node.scale = scl
	world.add_child(node)
	return node

func box(size: Vector3, pos: Vector3, color: Color, rough: float = 0.9) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	world.add_child(node)
	return node

func tex(path: String) -> Texture2D:
	if textures.has(path): return textures[path]
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	var t := ImageTexture.create_from_image(img)
	textures[path] = t
	return t

func center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x-0.5)*CELL_M,0.0,(cell.y-0.5)*CELL_M)

func cell_hash(cell: Vector2i) -> int:
	return absi(cell.x*73856093 ^ cell.y*19349663)

# ---------------------------------------------------------------- map background

func render_map(mission_id: String) -> void:
	clear_world()
	var mission: Resource = load("res://missions/%s.tres" % mission_id)
	var grid: Vector2i = mission.grid_size
	var walls: Array = mission.walls
	var wall_rows := {}
	for cell in walls: wall_rows[cell.y] = true
	var rows: Array = wall_rows.keys()
	rows.sort()
	var top: int = rows[0] if not rows.is_empty() else 0
	var bottom: int = rows[-1] if not rows.is_empty() else 0
	var bricks := StandardMaterial3D.new()
	bricks.albedo_texture = tex("res://render_src/city/T_RedBrick_BaseColor.png")
	bricks.uv1_triplanar = true
	bricks.uv1_scale = Vector3(0.5,0.5,0.5)
	bricks.roughness = 0.95
	# Ground: the street between the two building rows, sidewalks along them, concrete lots beyond.
	for y in range(1,grid.y+1):
		for x in range(1,grid.x+1):
			var cell := Vector2i(x,y)
			if walls.has(cell): continue
			var c := center(cell)
			if y > top and y < bottom:
				if y == top+1 or y == bottom-1:
					place("city/Sidewalk_Straight_3m",c,0.0 if y == top+1 else 180.0,Vector3(2.0/3.0,1,2.0/3.0))
				else:
					place("city/Street_Asphalt_6x6",c+Vector3(0,0.15,0),0,Vector3(1.0/3.0,1,1.0/3.0))
			elif wall_rows.has(y) or wall_rows.has(y+1) or wall_rows.has(y-1):
				# Alleys between buildings and service lanes behind them.
				place("city/Street_Asphalt_6x6",c+Vector3(0,0.15,0),0,Vector3(1.0/3.0,1,1.0/3.0))
				if cell_hash(cell) % 9 == 0: place("city/Prop_Drain",c+Vector3(0.3,0,0.3))
			else:
				place("city/Sidewalk_NoCurb_3m",c,90.0*(cell_hash(cell)%4),Vector3(2.0/3.0,1,2.0/3.0))

	# Lane markings down the middle of the street.
	if bottom-top > 3:
		var mid: float = ((top+bottom)/2.0-0.5)*CELL_M
		for x in range(1,grid.x+1):
			box(Vector3(1.1,0.02,0.12),Vector3((x-0.5)*CELL_M,0.01,mid-0.12),Color(0.86,0.74,0.25))
			box(Vector3(1.1,0.02,0.12),Vector3((x-0.5)*CELL_M,0.01,mid+0.12),Color(0.86,0.74,0.25))
	# Street furniture: manholes and drains in the road, crosswalks at the alley mouths.
	for x in range(1,grid.x+1):
		for y in range(top+2,bottom-1):
			var cell := Vector2i(x,y)
			if cell_hash(cell) % 13 == 0: place("city/Prop_ManholeCover",center(cell))
		if top > 0 and not walls.has(Vector2i(x,top)) and walls.has(Vector2i(x-1,top)) and walls.has(Vector2i(x+1,top)):
			var z0: float = (top+1)*CELL_M+0.4
			var z1: float = (bottom-1)*CELL_M-0.4
			var z := z0
			while z < z1:
				box(Vector3(1.5,0.02,0.35),Vector3((x-0.5)*CELL_M,0.012,z+0.175),Color(0.82,0.82,0.78))
				z += 0.75
	# Buildings: brick bodies with flat roofs, parapets and rooftop clutter; height varies by run.
	var heights := [5.0,7.5,6.0,4.5,8.0]
	var run_index := 0
	for y in rows:
		var x := 1
		while x <= grid.x:
			if not walls.has(Vector2i(x,y)):
				x += 1
				continue
			var start := x
			while x <= grid.x and walls.has(Vector2i(x,y)): x += 1
			var h: float = heights[run_index % heights.size()]
			run_index += 1
			var width: float = (x-start)*CELL_M
			var mid := Vector3((start-1)*CELL_M+width/2.0,0,(y-0.5)*CELL_M)
			var body := box(Vector3(width,h,CELL_M),mid+Vector3(0,h/2.0,0),Color(1,1,1))
			body.material_override = bricks
			var roof_color := Color(0.24,0.25,0.26) if run_index % 2 == 0 else Color(0.33,0.31,0.29)
			box(Vector3(width-0.5,0.05,CELL_M-0.5),mid+Vector3(0,h+0.03,0),roof_color)
			for side in [-1,1]:
				box(Vector3(width,0.45,0.25),mid+Vector3(0,h+0.22,side*(CELL_M/2.0-0.125)),Color(0.55,0.53,0.5))
				box(Vector3(0.25,0.45,CELL_M),mid+Vector3(side*(width/2.0-0.125),h+0.22,0),Color(0.55,0.53,0.5))
			for cx in range(start,x):
				var cell := Vector2i(cx,y)
				if cell_hash(cell) % 3 == 0:
					place("city/Prop_ACUnit",center(cell)+Vector3(-0.2,h+0.05,0),90.0*(cell_hash(cell)%4))
				elif cell_hash(cell) % 5 == 1:
					box(Vector3(0.7,0.5,0.7),center(cell)+Vector3(0.3,h+0.3,0.2),Color(0.3,0.31,0.33))
	# Cover: planters, crates, barrels and bollards on the edge the cover protects.
	var offsets := {"north":Vector3(0,0,-0.62),"south":Vector3(0,0,0.62),"east":Vector3(0.62,0,0),"west":Vector3(-0.62,0,0)}
	var kinds := ["planter","crates","barrels","bollards"]
	for cell in mission.cover_edges.keys():
		var side: String = mission.cover_edges[cell]
		var pos: Vector3 = center(cell)+offsets.get(side,Vector3.ZERO)
		var along_x: bool = side in ["north","south"]
		match kinds[cell_hash(cell) % kinds.size()]:
			"planter": place("city/Prop_Planter_Single",pos,0.0,Vector3(0.85 if along_x else 0.38,0.9,0.38 if along_x else 0.85))
			"crates":
				crate(pos+(Vector3(-0.4,0,0) if along_x else Vector3(0,0,-0.4)),0.7,5.0)
				crate(pos+(Vector3(0.42,0,0) if along_x else Vector3(0,0,0.42)),0.62,-12.0)
			"barrels":
				for i in range(3): place("scifi/Prop_Barrel1",pos+(Vector3(-0.6+0.6*i,0,0) if along_x else Vector3(0,0,-0.6+0.6*i)),40.0*i,Vector3.ONE*0.7)
			_:
				for i in range(4): place("city/Prop_Bollard",pos+(Vector3(-0.72+0.48*i,0,0) if along_x else Vector3(0,0,-0.72+0.48*i)))
	for cell in mission.fixtures:
		# A stalled delivery: pallets under a tarp.
		box(Vector3(1.5,0.9,1.2),center(cell)+Vector3(0,0.45,0),Color(0.30,0.36,0.30))
		crate(center(cell)+Vector3(0.5,0,0.6),0.6,20.0)
	cam.rotation_degrees = Vector3(-90,0,0)
	cam.size = grid.y*CELL_M
	cam.position = Vector3(grid.x*CELL_M/2.0,80.0,grid.y*CELL_M/2.0)
	env.ambient_light_energy = 0.75
	var img := await snap(grid*MAP_PX)
	img.save_png(ProjectSettings.globalize_path(OUT+"map_%s.png" % mission_id))
	print("map %s %s" % [mission_id,img.get_size()])

# ---------------------------------------------------------------- figures

func make_figure(texture: String, female: bool, soldier: bool) -> Node3D:
	var body: Node3D = load("res://render_src/characters/Superhero_%s_FullBody.gltf" % ("Female" if female else "Male")).instantiate()
	world.add_child(body)
	for mesh in body.find_children("*","MeshInstance3D",true,false):
		if String(mesh.name).begins_with("SuperHero") or String(mesh.name).begins_with("Superhero"):
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = tex("res://render_src/characters/%s.png" % texture)
			mat.roughness = 0.85
			mesh.material_override = mat
	var player := AnimationPlayer.new()
	body.add_child(player)
	player.add_animation_library("",anim_lib)
	var skeleton: Skeleton3D = body.find_children("*","Skeleton3D",true,false)[0]
	if soldier:
		attach(skeleton,"Head",sphere(0.15,Color(0.33,0.35,0.24)),Vector3(0,0.1,0.01),Vector3(1.05,0.82,1.12))
		attach(skeleton,"spine_03",box_mesh(Vector3(0.40,0.36,0.24),Color(0.24,0.26,0.19)),Vector3(0,0.0,0.10),Vector3.ONE)
		var rifle: Node3D = load("res://render_src/scifi/Gun_Rifle.gltf").instantiate()
		var holder := BoneAttachment3D.new()
		holder.bone_name = "hand_r"
		skeleton.add_child(holder)
		holder.add_child(rifle)
		rifle.scale = Vector3.ONE*0.75
		rifle.rotation_degrees = Vector3(0,90,-90)
		rifle.position = Vector3(0,0.06,0.02)
		for mesh in rifle.find_children("*","MeshInstance3D",true,false):
			var dark := StandardMaterial3D.new()
			dark.albedo_color = Color(0.13,0.13,0.12)
			dark.roughness = 0.6
			mesh.material_override = dark
	return body

func crate(pos: Vector3, size: float, yaw: float) -> void:
	var node := box(Vector3(size,size,size),pos+Vector3(0,size/2.0,0),Color(0.55,0.42,0.27))
	node.rotation_degrees.y = yaw
	var lid := box(Vector3(size*0.92,0.02,size*0.18),pos+Vector3(0,size+0.01,0),Color(0.42,0.31,0.19))
	lid.rotation_degrees.y = yaw

func sphere(radius: float, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return node

func box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return node

func attach(skeleton: Skeleton3D, bone: String, node: Node3D, offset: Vector3, scl: Vector3) -> void:
	var holder := BoneAttachment3D.new()
	holder.bone_name = bone
	skeleton.add_child(holder)
	holder.add_child(node)
	node.position = offset
	node.scale = scl

func pose(body: Node3D, anim: String, time: float) -> void:
	var player: AnimationPlayer = body.find_children("*","AnimationPlayer",false,false)[0]
	player.play(anim)
	player.seek(time,true)
	player.pause()

func figure_camera() -> void:
	cam.rotation_degrees = Vector3(-52,0,0)
	cam.size = 2.5
	cam.position = Vector3(0,0.85,0)+cam.transform.basis.z*30.0

## One sheet per animation: rows are facings (s,e,n,w), columns are frames.
func render_sheet(body: Node3D, anim: String, frames: int, name: String) -> void:
	var length: float = anim_lib.get_animation(anim).length
	var sheet := Image.create(FRAME.x*frames,FRAME.y*FACING_ORDER.size(),false,Image.FORMAT_RGBA8)
	for row in range(FACING_ORDER.size()):
		body.rotation_degrees.y = FACINGS[FACING_ORDER[row]]
		for column in range(frames):
			var t: float = length*column/frames if frames > 1 else (length-0.01 if anim.begins_with("Death") else 0.0)
			pose(body,anim,t)
			var img := await snap(FRAME)
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img,Rect2i(Vector2i.ZERO,FRAME),Vector2i(column*FRAME.x,row*FRAME.y))
	sheet.save_png(ProjectSettings.globalize_path(OUT+"%s_%s.png" % [name,anim.to_lower()]))
	print("sheet %s %s" % [name,anim])

func render_units() -> void:
	clear_world()
	figure_camera()
	env.ambient_light_energy = 0.9
	var specs := [["Idle",1],["Walk",6],["Pistol_Aim_Neutral",1],["Pistol_Shoot",2],["Crouch_Idle",1],["Death01",1]]
	var soldier := make_figure("gen_soldier_m",false,true)
	for spec in specs: await render_sheet(soldier,spec[0],spec[1],"soldier")
	soldier.free()
	for i in range(6):
		var civ := make_figure("gen_civ_%d" % i,i % 2 == 1,false)
		for spec in [["Idle",1],["Walk",6]]: await render_sheet(civ,spec[0],spec[1],"civ%d" % i)
		civ.free()

# ---------------------------------------------------------------- look test

func load_png(name: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(OUT+name))
	img.convert(Image.FORMAT_RGBA8)
	return img

func frame_of(sheet: Image, facing: int, column: int) -> Image:
	return sheet.get_region(Rect2i(column*FRAME.x,facing*FRAME.y,FRAME.x,FRAME.y))

func stamp(canvas: Image, frame: Image, cell: Vector2i, offset: Vector2i = Vector2i.ZERO, scale: float = 1.0) -> void:
	var f := frame
	if scale != 1.0:
		f = frame.duplicate()
		f.resize(int(FRAME.x*scale),int(FRAME.y*scale),Image.INTERPOLATE_LANCZOS)
	var feet := Vector2i((cell.x-1)*MAP_PX+MAP_PX/2,(cell.y-1)*MAP_PX+int(MAP_PX*0.78))
	var at := feet-Vector2i(f.get_width()/2,int(f.get_height()*0.93))+offset
	canvas.blend_rect(f,Rect2i(Vector2i.ZERO,f.get_size()),at)

func compose_look_test(mission_id: String) -> void:
	var mission: Resource = load("res://missions/%s.tres" % mission_id)
	var canvas := load_png("map_%s.png" % mission_id)
	var idle := load_png("soldier_idle.png")
	var walk := load_png("soldier_walk.png")
	var aim := load_png("soldier_pistol_aim_neutral.png")
	var spawns: Array = mission.squad_spawns
	for i in range(spawns.size()):
		var sheet: Image = [idle,walk,aim,idle][i]
		stamp(canvas,frame_of(sheet,1,2 if sheet == walk else 0),spawns[i]+Vector2i(i,0))
	var civs: Array = mission.civilian_spawns
	for g in range(civs.size()):
		var spots := [Vector2i(-20,-14),Vector2i(18,-12),Vector2i(-14,12),Vector2i(22,14)]
		for k in range(4):
			var sheet := load_png("civ%d_idle.png" % ((g*2+k) % 6))
			stamp(canvas,frame_of(sheet,[0,3,1,0][k],0),civs[g],spots[k],0.72)
	canvas.save_png(ProjectSettings.globalize_path(OUT+"look_test_%s.png" % mission_id))
	print("look test saved")
