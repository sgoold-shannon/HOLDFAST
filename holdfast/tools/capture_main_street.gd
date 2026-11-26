extends SceneTree
## Dev tool: opens the HUD on Main Street, plays a few actions and saves screenshots.
## Run without --headless:  godot --path holdfast --script res://tools/capture_main_street.gd

func wait(seconds: float) -> void:
	var end := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec() < end: await process_frame

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://tools/%s.png" % name))
	print("saved ",name," ",img.get_size())

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var shell = load("res://game.tscn").instantiate()
	shell.board_auto_resume = false
	shell.board_campaign_path = "user://capture-campaign.save"
	root.add_child(shell)
	current_scene = shell
	await wait(0.5)
	shell.play_main_street()
	await wait(0.5)
	var board = shell.board
	board.set_meta("hud_briefed",true)
	board.finish_opening()
	shell.refresh()
	await wait(1.0)
	await shot("cap_main_1_start")
	board.select_soldier(0)
	board.try_move(board.soldiers[0]["cell"]+Vector2i(3,0))
	await wait(0.25)
	await shot("cap_main_2_moving")
	await wait(1.0)
	for r in range(3):
		board.next_phase()
		await wait(0.4)
	shell.refresh()
	board.select_soldier(1)
	await wait(1.0)
	await shot("cap_main_3_round4")
	for r in range(3):
		board.next_phase()
		await wait(0.4)
	shell.refresh()
	if board.fallow["stage"] != "waiting":
		var cutter: Vector2i = board.fallow["cutter"]["cell"]
		for index in range(4):
			board.select_soldier(index)
			board.sight_mode = true
			board.pinned_target = cutter
			if board.fire_block_reason() == "":
				board.try_fire()
				break
		await wait(0.06)
		await shot("cap_main_4_shot")
	board.next_phase()
	await wait(0.15)
	await shot("cap_main_5_fold")
	# Visual check of the feedback effects: fake a shot and a wound (presentation only).
	board.sight_mode = false
	board.pinned_target = board.fallow["cutter"]["cell"]
	board.soldiers[1]["ammo"] -= 1
	board.soldiers[2]["hp"] -= 3
	board.queue_redraw()
	await wait(0.07)
	await shot("cap_main_6_effects")
	quit(0)
