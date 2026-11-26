extends RefCounted
## Rendered-art presentation for missions that have a sprite set (res://assets/sprites/map_<id>.png):
## the map background, animated soldiers and civilian groups, and feedback effects (move tweens,
## tracers, muzzle flashes, hit flashes, damage numbers, rift bursts) plus their sounds.
## Purely presentation: it watches the board's state between draws and never changes it.
## Sprites come from tools/sprite_render.gd (Quaternius CC0 kits); see assets/CREDITS.md.
const SPRITES := "res://assets/sprites/"
const SFX := "res://assets/sfx/"
const FRAME := Vector2(128,160)
const MAP_PX := 96.0
const FACING_ROW := {"s":0,"e":1,"n":2,"w":3}
const CIV_SPOTS: Array[Vector2] = [Vector2(-8,-6),Vector2(7,-5),Vector2(-6,6),Vector2(9,7)]

var mission_id := ""
var background: Texture2D
var sheets := {}
var soldiers := {}        # index -> {"cell","pos","from","to","start","dur","facing","aim_until","hp","ammo","flash_until"}
var groups := {}          # cohort index -> same shape, plus "hp"
var effects: Array = []   # {"kind","a","b","start","dur","text","color"}
var rifts := 0
var cutter_hp := -1
var interrupts := 0
var players: Array = []
var ambience: AudioStreamPlayer = null
var scale := 36.0/MAP_PX  # board units per sprite pixel

## The art set for this board, created on first use; null when the mission has no art.
static func for_board(board) -> RefCounted:
	if board.has_meta("sprite_art"): return board.get_meta("sprite_art")
	var id: String = board.mission_definition().mission_id if "mission_id" in board.mission_definition() else ""
	var art: RefCounted = null
	if id != "" and ResourceLoader.exists(SPRITES+"map_%s.png" % id):
		art = load("res://presentation/sprite_art.gd").new()
		art.setup(board,id)
	board.set_meta("sprite_art",art)
	return art

func setup(board, id: String) -> void:
	mission_id = id
	background = load(SPRITES+"map_%s.png" % id)
	for name in ["soldier_idle","soldier_walk","soldier_pistol_aim_neutral","soldier_pistol_shoot","soldier_crouch_idle","soldier_death01"]:
		sheets[name] = load(SPRITES+name+".png")
	for i in range(6):
		sheets["civ%d_idle" % i] = load(SPRITES+"civ%d_idle.png" % i)
		sheets["civ%d_walk" % i] = load(SPRITES+"civ%d_walk.png" % i)
	if "fallow" in board and not board.fallow.is_empty():
		rifts = board.fallow.get("rifts",[]).size()
		cutter_hp = board.fallow["cutter"]["hp"]
		interrupts = board.fallow.get("interrupts",0)

func now() -> float:
	return Time.get_ticks_msec()/1000.0

func animating() -> bool:
	if not effects.is_empty(): return true
	var t := now()
	for state in soldiers.values():
		if t < state["start"]+state["dur"] or t < state["aim_until"] or t < state["flash_until"]: return true
	for state in groups.values():
		if t < state["start"]+state["dur"]: return true
	return false

# ---------------------------------------------------------------- background

func draw_background(board, projection) -> void:
	var grid: Vector2i = board.GRID_SIZE
	var origin: Vector2 = projection.cell_anchor(Vector2i.ONE)
	board.draw_texture_rect(background,Rect2(origin,Vector2(grid)*board.CELL_SIZE),false)

# ---------------------------------------------------------------- state watching

func cell_center(projection, cell: Vector2i) -> Vector2:
	return projection.cell_anchor(cell)+Vector2(18,18)

func facing_for(delta: Vector2) -> String:
	if absf(delta.x) >= absf(delta.y): return "e" if delta.x >= 0 else "w"
	return "s" if delta.y > 0 else "n"

func track(table: Dictionary, key: int, cell: Vector2i, projection, start_facing: String) -> Dictionary:
	var t := now()
	var target := cell_center(projection,cell)
	if not table.has(key):
		table[key] = {"cell":cell,"pos":target,"from":target,"to":target,"start":t,"dur":0.0,"facing":start_facing,"aim_until":0.0,"hp":-999,"ammo":-1,"flash_until":0.0}
	var state: Dictionary = table[key]
	if state["cell"] != cell:
		var current: Vector2 = position_of(state)
		state["from"] = current
		state["to"] = target
		state["start"] = t
		state["dur"] = clampf(current.distance_to(target)/36.0*0.14,0.15,0.9)
		state["facing"] = facing_for(target-current)
		state["cell"] = cell
	return state

func position_of(state: Dictionary) -> Vector2:
	var t := now()
	if state["dur"] <= 0.0 or t >= state["start"]+state["dur"]: return state["to"]
	var k: float = (t-state["start"])/state["dur"]
	return state["from"].lerp(state["to"],k)

func moving(state: Dictionary) -> bool:
	return state["dur"] > 0.0 and now() < state["start"]+state["dur"]

## Called once per draw before anything is drawn: turns state changes into effects and sounds.
func watch(board, projection) -> void:
	var t := now()
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		var state := track(soldiers,index,soldier["cell"],projection,"e")
		if moving(state) and state.get("step_sound",-1.0) != state["start"]:
			state["step_sound"] = state["start"]
			play(board,"step_%d.ogg" % (index % 5),-10.0)
		if state["ammo"] >= 0 and soldier["ammo"] < state["ammo"]:
			var target: Vector2i = board.sight_target()
			var aim_at: Vector2 = cell_center(projection,target) if board.cell_is_in_bounds(target) else state["to"]+Vector2(36,0)
			state["facing"] = facing_for(aim_at-state["to"])
			state["aim_until"] = t+0.9
			effects.append({"kind":"tracer","a":state["to"]+Vector2(0,-14),"b":aim_at,"start":t,"dur":0.18})
			effects.append({"kind":"flash","a":state["to"]+Vector2(0,-14)+(aim_at-state["to"]).normalized()*14,"start":t,"dur":0.09})
			play(board,"rifle_%d.wav" % (randi() % 3),-4.0)
		if state["hp"] != -999 and soldier["hp"] < state["hp"]:
			state["flash_until"] = t+0.3
			effects.append({"kind":"text","a":state["to"]+Vector2(0,-40),"text":"-%d" % (state["hp"]-soldier["hp"]),"color":Color("ff6a5c"),"start":t,"dur":1.1})
			play(board,"hit_soldier.ogg",-3.0)
		state["hp"] = soldier["hp"]
		state["ammo"] = soldier["ammo"]
	for index in range(board.cohorts.size()):
		var cohort: Dictionary = board.cohorts[index]
		var state := track(groups,index,cohort["cell"],projection,"s")
		var hp: int = cohort.get("hp",4)
		if state["hp"] != -999 and hp < state["hp"]:
			effects.append({"kind":"text","a":state["to"]+Vector2(0,-34),"text":"-%d" % (state["hp"]-hp),"color":Color("ffb75a"),"start":t,"dur":1.1})
		state["hp"] = hp
	if "fallow" in board and not board.fallow.is_empty():
		var fallow: Dictionary = board.fallow
		var now_rifts: Array = fallow.get("rifts",[])
		if now_rifts.size() > rifts:
			for i in range(rifts,now_rifts.size()):
				effects.append({"kind":"rift","a":cell_center(projection,now_rifts[i]),"start":t+0.04*(i-rifts),"dur":0.9})
			play(board,"rift_fold.ogg",-2.0)
		rifts = now_rifts.size()
		var hp: int = fallow["cutter"]["hp"]
		if cutter_hp >= 0 and hp < cutter_hp:
			effects.append({"kind":"sparks","a":cell_center(projection,fallow["cutter"]["cell"]),"start":t,"dur":0.5})
			effects.append({"kind":"text","a":cell_center(projection,fallow["cutter"]["cell"])+Vector2(0,-30),"text":"-%d" % (cutter_hp-hp),"color":Color("d9b8ff"),"start":t,"dur":1.1})
			play(board,"hit_alien.ogg",-3.0)
		cutter_hp = hp
		if fallow.get("interrupts",0) > interrupts:
			effects.append({"kind":"ring","a":cell_center(projection,fallow["node"]),"start":t,"dur":0.6})
			play(board,"node.ogg",-6.0)
		interrupts = fallow.get("interrupts",0)
	effects = effects.filter(func(effect): return t < effect["start"]+effect["dur"])
	ensure_ambience(board)

# ---------------------------------------------------------------- figures

func frame(sheet: Texture2D, facing: String, column: int) -> Rect2:
	return Rect2(Vector2(column*FRAME.x,FACING_ROW[facing]*FRAME.y),FRAME)

func draw_figure(board, sheet: Texture2D, facing: String, column: int, feet: Vector2, size: float = 1.0, tint: Color = Color.WHITE) -> void:
	var drawn := FRAME*scale*size*1.2
	var at := feet-Vector2(drawn.x/2.0,drawn.y*0.93)
	board.draw_texture_rect_region(sheet,Rect2(at,drawn),frame(sheet,facing,column),tint)

func draw_soldier(board, index: int, projection, color: Color, selected: bool) -> void:
	var soldier: Dictionary = board.soldiers[index]
	if not soldiers.has(index): return
	var state: Dictionary = soldiers[index]
	var center := position_of(state)
	var feet := center+Vector2(0,10)
	var t := now()
	# Ground marker: role color, selection ring.
	board.draw_set_transform(feet,0.0,Vector2(1,0.45))
	board.draw_circle(Vector2.ZERO,13,Color(0,0,0,0.35))
	board.draw_arc(Vector2.ZERO,13,0,TAU,28,Color.WHITE if selected else color,3.0 if selected else 2.0)
	board.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	var condition: String = soldier.get("condition","active")
	var tint := Color(1,0.55,0.5) if t < state["flash_until"] else Color.WHITE
	if condition in ["critical","stable","dead"]:
		draw_figure(board,sheets["soldier_death01"],state["facing"],0,feet+Vector2(0,4),1.0,tint.darkened(0.25 if condition == "dead" else 0.0))
	elif moving(state):
		draw_figure(board,sheets["soldier_walk"],state["facing"],int(t*10.0) % 6,feet,1.0,tint)
	elif t < state["aim_until"]:
		var shooting: bool = t < state["aim_until"]-0.7
		draw_figure(board,sheets["soldier_pistol_shoot" if shooting else "soldier_pistol_aim_neutral"],state["facing"],int(t*20.0) % 2 if shooting else 0,feet,1.0,tint)
	else:
		draw_figure(board,sheets["soldier_idle"],state["facing"],0,feet,1.0,tint)
	# Name tag under the feet and a health bar when hurt.
	board.draw_rect(Rect2(feet+Vector2(-9,6),Vector2(18,11)),Color(0.05,0.07,0.06,0.85))
	board.draw_string(board.font,feet+Vector2(-9,15),soldier["mark"],HORIZONTAL_ALIGNMENT_CENTER,18,10,color)
	var max_hp: float = 8.0
	if soldier["hp"] < max_hp and condition == "active":
		var top := feet+Vector2(-12,-72)
		board.draw_rect(Rect2(top,Vector2(24,3)),Color(0,0,0,0.7))
		board.draw_rect(Rect2(top,Vector2(24*clampf(soldier["hp"]/max_hp,0,1),3)),Color("7fe08a") if soldier["hp"] > 4 else Color("ffb75a"))

func draw_cohorts(board, projection) -> void:
	var t := now()
	for index in range(board.cohorts.size()):
		var cohort: Dictionary = board.cohorts[index]
		if cohort["status"] != "active" or not groups.has(index): continue
		var state: Dictionary = groups[index]
		var center := position_of(state)
		var walking := moving(state)
		var count: int = clampi(cohort.get("hp",4),1,4)
		for k in range(count):
			var variant := (index*2+k) % 6
			var facing: String = state["facing"] if walking else ["s","w","e","s"][k]
			var sheet: Texture2D = sheets["civ%d_walk" % variant] if walking else sheets["civ%d_idle" % variant]
			var column := (int(t*10.0)+k*2) % 6 if walking else 0
			draw_figure(board,sheet,facing,column,center+CIV_SPOTS[k]+Vector2(0,8),0.6)

# ---------------------------------------------------------------- effects

func draw_effects(board, projection) -> void:
	var t := now()
	# The Fallow's marked ground pulses so the threat reads before it folds.
	if "fallow" in board and not board.fallow.is_empty():
		var pulse := 0.25+0.2*sin(t*5.0)
		for cell in board.fallow.get("marked",[]):
			board.draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(2,2),Vector2(32,32)),Color(0.75,0.4,1.0,pulse),false,2.0)
	for effect in effects:
		var k: float = clampf((t-effect["start"])/effect["dur"],0.0,1.0)
		if t < effect["start"]: continue
		match effect["kind"]:
			"tracer":
				board.draw_line(effect["a"],effect["b"],Color(1.0,0.92,0.6,1.0-k),2.0)
				board.draw_line(effect["a"].lerp(effect["b"],k),effect["a"].lerp(effect["b"],minf(1.0,k+0.25)),Color(1,1,0.85,1.0-k),3.0)
			"flash":
				board.draw_circle(effect["a"],6.0*(1.0-k)+2.0,Color(1.0,0.85,0.4,1.0-k))
			"text":
				board.draw_string(board.font,effect["a"]+Vector2(-20,-18.0*k),effect["text"],HORIZONTAL_ALIGNMENT_CENTER,40,15,Color(effect["color"],1.0-k*k))
			"rift":
				board.draw_circle(effect["a"],16.0*k+2.0,Color(0.45,0.15,0.75,0.55*(1.0-k)))
				board.draw_arc(effect["a"],22.0*k+4.0,0,TAU,24,Color(0.85,0.6,1.0,1.0-k),2.0)
			"sparks":
				for i in range(8):
					var angle: float = TAU*i/8.0+effect["start"]
					var from: Vector2 = effect["a"]+Vector2.from_angle(angle)*8.0*k
					board.draw_line(from,from+Vector2.from_angle(angle)*6.0,Color(0.9,0.75,1.0,1.0-k),2.0)
			"ring":
				board.draw_arc(effect["a"],6.0+18.0*k,0,TAU,24,Color(0.6,0.9,1.0,1.0-k),2.0)

# ---------------------------------------------------------------- sound

func play(board, file: String, volume_db: float = 0.0) -> void:
	if not board.is_inside_tree() or DisplayServer.get_name() == "headless": return
	var stream: AudioStream = load(SFX+file) if ResourceLoader.exists(SFX+file) else null
	if stream == null: return
	var player: AudioStreamPlayer = null
	for candidate in players:
		if is_instance_valid(candidate) and not candidate.playing:
			player = candidate
			break
	if player == null:
		if players.size() >= 8: return
		player = AudioStreamPlayer.new()
		board.add_child(player)
		players.append(player)
	player.stream = stream
	player.volume_db = volume_db
	player.play()

func ensure_ambience(board) -> void:
	if ambience != null and is_instance_valid(ambience): return
	if not board.is_inside_tree() or DisplayServer.get_name() == "headless": return
	if not ResourceLoader.exists(SFX+"amb_city.ogg"): return
	ambience = AudioStreamPlayer.new()
	var stream: AudioStream = load(SFX+"amb_city.ogg")
	if stream is AudioStreamOggVorbis: stream.loop = true
	ambience.stream = stream
	ambience.volume_db = -14.0
	board.add_child(ambience)
	ambience.play()
