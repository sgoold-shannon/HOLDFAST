extends SceneTree
## Balance runs for River Bridge (isolated; nothing saved).
const GreyTeam = preload("res://systems/grey_team.gd")
func _initialize() -> void:
	call_deferred("go")
func fresh():
	var b = load("res://river_bridge.tscn").instantiate()
	b.auto_resume = false
	root.add_child(b)
	b.command_model = "authority"
	b.finish_opening()
	return b
func play(tag: String, lane: String, fight: bool) -> void:
	var b = fresh()
	var log := []
	for turn in range(12):
		b.select_soldier(0)
		if turn == 0:
			b.soldiers[0]["cell"] = Vector2i(7,8)
			b.select_soldier(0)
			b.set_lanes(lane)
		# MSG keeps up with the column (teleport-free: just try to step east each turn)
		if turn > 0 and b.soldier_can_act(0):
			var target: Vector2i = b.soldiers[0]["cell"]+Vector2i(3,0)
			if b.move_cost(target) > 0: b.try_move(target)
		for i in range(3):
			var c = b.cohorts[i]
			if c["status"] != "active": continue
			if c.get("panic",0) > 0: b.calm_cohort(i)
			if c["order"] == "hold": b.order_exit(i)
		if fight and not b.greys["withdrawn"]:
			var col := GreyTeam.unit(b.greys,"collector")
			for s in [1,2,3]:
				if col.is_empty() or not b.soldier_can_act(s): continue
				b.select_soldier(s)
				b.pinned_target = col["cell"]
				b.sight_mode = true
				b.try_fire()
				b.sight_mode = false
		var r: int = b.phase
		b.next_phase()
		var line := ""
		for c in b.cohorts: line += "%s%s%s " % [c["id"],c["cell"],{"active":"","extracted":"+","taken":"T","stranded":"x"}[c["status"]]]
		log.append("r%d %s | %s" % [r,line,b.enemy_message.left(90)])
		if b.ended: break
	var out := 0
	for c in b.cohorts: out += 4 if c["status"] == "extracted" else 0
	print("%-26s out=%d/12 taken=%s greys=%s end=%s" % [tag,out,b.greys["taken"],b.greys["withdraw_reason"],b.end_reason])
	for l in log: print("   ",l)
	b.free()
func go() -> void:
	play("people, ignore greys","people",false)
	play("people, shoot collector","people",true)
	play("heavy, ignore greys","heavy",false)
	play("heavy, shoot collector","heavy",true)
	quit(0)
