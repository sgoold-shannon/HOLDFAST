extends SceneTree
## Renders the Farm Road briefing and the priority box on a fresh, isolated board.
func _initialize() -> void:
	call_deferred("go")
func go() -> void:
	var shell = load("res://game.tscn").instantiate()
	shell.board_auto_resume = false
	shell.board_campaign_path = OS.get_cache_dir().path_join("capture-brief.save")
	root.add_child(shell)
	current_scene = shell
	await process_frame
	shell.board.finish_opening()
	for i in range(8): await process_frame
	var out := ProjectSettings.globalize_path("res://").path_join("../.bridge/results/").simplify_path()
	root.get_texture().get_image().save_png(out.path_join("brief.png"))
	shell.board.set_meta("hud_briefed",true)
	shell.board.select_soldier(0)
	for i in range(8): await process_frame
	root.get_texture().get_image().save_png(out.path_join("priority.png"))
	quit(0)
