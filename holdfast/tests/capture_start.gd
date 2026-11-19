extends SceneTree
## Renders the launch screen with the player's real saves (read-only) and saves a PNG.
func _initialize() -> void:
	call_deferred("go")
func go() -> void:
	var shell = load("res://game.tscn").instantiate()
	root.add_child(shell)
	current_scene = shell
	for i in range(10): await process_frame
	print("START_MENU ",shell.start_menu," modal ",shell.modal_root.visible)
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://").path_join("../.bridge/results/start.png").simplify_path())
	shell.start_menu = false
	shell.board.auto_resume = false
	quit(0)
