extends SceneTree
## Renders the operations board after a quick isolated Farm Road finish (not a test).
func _initialize() -> void:
	call_deferred("go")
func go() -> void:
	var shell = load("res://game.tscn").instantiate()
	shell.board_auto_resume = false
	shell.board_campaign_path = OS.get_cache_dir().path_join("capture-ops.save")
	root.add_child(shell)
	current_scene = shell
	await process_frame
	if FileAccess.file_exists(shell.campaign_record_path): DirAccess.remove_absolute(shell.campaign_record_path)
	var board = shell.board
	board.finish_opening()
	board.set_meta("hud_briefed",true)
	board.protocol["acknowledged"] = true
	board.cohorts[0]["status"] = "extracted"
	board.cohorts[1]["status"] = "extracted"
	board.enemies[0]["hp"] = 0
	board.soldiers[0]["extracted"] = true
	board.request_close()
	board.request_close()
	for i in range(6): await process_frame
	shell.open_operations()
	for i in range(8): await process_frame
	var out := ProjectSettings.globalize_path("res://").path_join("../.bridge/results/").simplify_path()
	root.get_texture().get_image().save_png(out.path_join("operations.png"))
	shell.widgets.get("sidebar_scroll")
	quit(0)
