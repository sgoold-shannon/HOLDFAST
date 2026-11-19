extends SceneTree
## Balance runs for the authority model on a fresh Farm Road (isolated saves).
func _initialize() -> void:
	call_deferred("go")
func fresh(tag: String):
	var b = load("res://farm_final.tscn").instantiate()
	b.auto_resume = false
	b.campaign_path = OS.get_cache_dir().path_join("simc-%s.save" % tag)
	root.add_child(b)
	b.report_path = OS.get_cache_dir().path_join("simc-%s-r.save" % tag)
	b.completion_path = OS.get_cache_dir().path_join("simc-%s-c.save" % tag)
	b.command_model = "authority"
	b.finish_opening()
	return b
func play(tag: String, stop_machine: bool, msg_walks: bool) -> void:
	var b = fresh(tag)
	if stop_machine: b.enemies[0]["hp"] = 0
	var log := []
	for turn in range(12):
		b.select_soldier(0)
		if msg_walks and turn == 0: b.try_move(b.soldiers[0]["cell"]+Vector2i(2,1))
		for i in range(3):
			var c = b.cohorts[i]
			if c["status"] != "active": continue
			if c.get("panic",0) > 0: b.calm_cohort(i)
			if c["order"] == "hold": b.order_exit(i)
		var r: int = b.phase
		b.next_phase()
		var s := ""
		for c in b.cohorts: s += "%s%s%s " % [c["id"],c["cell"],["","!","!!"][c.get("panic",0)] if c["status"]=="active" else "+"]
		log.append("r%d %s" % [r,s])
		if b.ended: break
	var saved := 0
	for c in b.cohorts: saved += 4 if c["status"] == "extracted" else 0
	print("%-34s saved=%d/12 deadline=%d end=%s" % [tag,saved,b.deadline(),b.end_reason])
	for line in log: print("    ",line)
func go() -> void:
	play("machine runs, MSG stays",false,false)
	play("machine runs, MSG steps up",false,true)
	play("machine stopped, MSG stays",true,false)
	play("machine stopped, MSG steps up",true,true)
	quit(0)
