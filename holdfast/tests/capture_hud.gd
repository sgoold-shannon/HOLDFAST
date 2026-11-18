extends SceneTree
## Renders the desktop HUD once and saves a screenshot (not part of the test suite).
## Usage: Godot --path holdfast --script res://tests/capture_hud.gd -- <output.png>
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://").path_join("../.bridge/results/hud.png").simplify_path()
	var shell = load("res://game.tscn").instantiate()
	shell.board_auto_resume = false
	shell.board_campaign_path = OS.get_cache_dir().path_join("holdfast-capture-campaign.save")
	root.add_child(shell)
	current_scene = shell
	for i in range(10): await process_frame
	root.get_texture().get_image().save_png(output.get_basename()+"-opening.png")
	shell.board.finish_opening()
	shell.board.select_soldier(0)
	shell.board.hovered_cell = shell.board.soldiers[0]["cell"]+Vector2i(2,0)
	shell.board.queue_redraw()
	for i in range(10): await process_frame
	root.get_texture().get_image().save_png(output)
	print("CAPTURED ",output)
	quit(0)
