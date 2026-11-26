extends SceneTree
## Prints sizes of the 3D sources the sprite renderer uses (dev tool, not part of the game).

func aabb_of(node: Node) -> AABB:
	var box := AABB()
	var first := true
	for child in node.find_children("*","MeshInstance3D",true,false):
		var mesh: MeshInstance3D = child
		var b: AABB = mesh.global_transform * mesh.get_aabb()
		if first: box = b
		else: box = box.merge(b)
		first = false
	return box

func _init() -> void:
	var names := ["city/Street_Asphalt_6x6","city/Street_4Lane","city/Street_2Lane","city/Sidewalk_Straight_3m","city/Sidewalk_Corner_Flat_3m","city/Floor_2x2","city/Roof_2x2","city/Roof_4x4","city/Brick_Plain_1","city/Building_Small_1","city/Building_Medium_2_001","city/Building_Large_2","city/Prop_ACUnit","city/Prop_Bollard","city/Prop_Planter_Single","city/Decal_Crosswalk","city/Cornice_Brick_Center","scifi/Prop_Crate","scifi/Prop_Crate_Large","scifi/Prop_Barrel1","scifi/Gun_Rifle","scifi/Enemy_QuadShell","scifi/Enemy_Trilobite","characters/Superhero_Male_FullBody"]
	var root3 := Node3D.new()
	get_root().add_child(root3)
	for n in names:
		var path := "res://render_src/%s.gltf" % n
		var scene: PackedScene = load(path)
		if scene == null:
			print("MISSING ",path)
			continue
		var inst := scene.instantiate()
		root3.add_child(inst)
		print("%-40s %s" % [n,aabb_of(inst)])
		inst.queue_free()
	var anim: PackedScene = load("res://render_src/anim/UAL1_Standard.glb")
	var a := anim.instantiate()
	root3.add_child(a)
	var players := a.find_children("*","AnimationPlayer",true,false)
	if not players.is_empty():
		var p: AnimationPlayer = players[0]
		print("ANIMS: ", ", ".join(p.get_animation_list()))
	var skels := a.find_children("*","Skeleton3D",true,false)
	if not skels.is_empty(): print("UAL bones: ",skels[0].get_bone_count()," first: ",skels[0].get_bone_name(0)," path ",a.get_path_to(skels[0]))
	var hero: Node = load("res://render_src/characters/Superhero_Male_FullBody.gltf").instantiate()
	root3.add_child(hero)
	var hs := hero.find_children("*","Skeleton3D",true,false)
	if not hs.is_empty():
		var s: Skeleton3D = hs[0]
		var bones := []
		for i in range(s.get_bone_count()): bones.append(s.get_bone_name(i))
		print("HERO bones: ",s.get_bone_count()," path ",hero.get_path_to(s)," ",", ".join(bones.slice(0,60)))
	print("HERO meshes: ",", ".join(hero.find_children("*","MeshInstance3D",true,false).map(func(m): return m.name)))
	quit(0)
