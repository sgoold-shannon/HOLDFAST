extends SceneTree
## Renders River Bridge mid-mission (not a test; nothing saved).
func _initialize() -> void:
	call_deferred("go")
func go() -> void:
	var shell = load("res://game.tscn").instantiate()
	shell.board_auto_resume = false
	shell.board_campaign_path = OS.get_cache_dir().path_join("capture-river.save")
	root.add_child(shell)
	current_scene = shell
	await process_frame
	shell.play_river_bridge()
	await process_frame
	var board = shell.board
	board.finish_opening()
	board.set_meta("hud_briefed",true)
	board.soldiers[0]["cell"] = Vector2i(7,8)
	board.select_soldier(0)
	board.set_lanes("heavy")
	for i in range(3):
		board.select_soldier(0)
		for g in range(3):
			if board.cohorts[g]["order"] == "hold": board.order_exit(g)
		board.next_phase()
	board.select_soldier(1)
	for i in range(8): await process_frame
	var out := ProjectSettings.globalize_path("res://").path_join("../.bridge/results/").simplify_path()
	root.get_texture().get_image().save_png(out.path_join("river.png"))
	quit(0)
