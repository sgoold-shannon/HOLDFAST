extends Control
## Desktop game screen (1920×1080 landscape). The encounter controller keeps every rule;
## this shell draws the map large on the left and real buttons/panels around it.
## Keyboard shortcuts still go straight to the controller, so they behave exactly as before.

const BoardScene = preload("res://farm_final.tscn")
const MapInput = preload("res://presentation/hud/map_input.gd")
const MapLayer = preload("res://presentation/hud/map_layer.gd")

const SIDEBAR_WIDTH := 600.0
const TOP_HEIGHT := 64.0
const STRIP_HEIGHT := 92.0
const BG := Color("0e1412")
const PANEL := Color("18231f")
const CARD := Color("22312a")
const ACCENT := Color("8be6de")
const GOLD := Color("f7cd6c")
const WARN := Color("ffb75a")
const MUTED := Color("aebbb6")
const TEXT := Color("e2e9e5")

var board = null
var layer: CanvasLayer
var ui: Control
var holder: Node2D
var map_view: Control
var widgets := {}
var actions := {}
var modal_root: Control
var modal_box: VBoxContainer
var modal_signature := ""
var refresh_timer := 0.0
var dirty := true
## Tests point these at throwaway files so the player's campaign is never touched.
var board_auto_resume := true
var board_campaign_path := ""
var confirm_new := false
## Shown at launch when a saved campaign exists: New game or Continue.
var start_menu := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var readability = get_node_or_null("/root/Readability")
	if readability: readability.shell_mode = true
	layer = CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	visibility_changed.connect(func(): layer.visible = is_visible_in_tree())
	build_ui()
	start_menu = board_auto_resume and board_campaign_path == "" and (FileAccess.file_exists("user://holdfast_d1_campaign.save") or FileAccess.file_exists("user://holdfast_c2_campaign.save"))
	var fresh = BoardScene.instantiate()
	fresh.auto_resume = board_auto_resume
	if board_campaign_path != "": fresh.campaign_path = board_campaign_path
	holder.add_child(fresh)
	refresh()

# ---------------------------------------------------------------- layout

func build_ui() -> void:
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = make_theme()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(background)
	build_top_bar()
	build_map()
	build_sidebar()
	build_modal()

func build_top_bar() -> void:
	var bar := panel(PANEL)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = TOP_HEIGHT
	ui.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",18)
	bar.add_child(row)
	row.add_child(label("HOLDFAST",28,ACCENT))
	widgets["mission"] = label("",24,TEXT)
	row.add_child(widgets["mission"])
	widgets["round"] = label("",22,GOLD)
	widgets["round"].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	widgets["round"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	widgets["round"].clip_text = true
	widgets["round"].text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(widgets["round"])
	for entry in [["save","Save  [K]",func(): board.save_encounter()],
			["load","Load  [L]",func(): board.load_encounter()],
			["log","Scene log  [Tab]",func(): board.toggle_log()],
			["roster","Roster  [G]",func(): board.open_roster()],
			["help","Controls",func(): show_help()]]:
		var top_button := action_button(entry[0],entry[1],entry[2],0)
		top_button.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(top_button)
	var extras := MenuButton.new()
	extras.text = "Extras ▾"
	extras.focus_mode = Control.FOCUS_NONE
	extras.custom_minimum_size = Vector2(140,0)
	extras.get_popup().add_item("3D preview",0)
	extras.get_popup().add_item("Visual benchmark",1)
	extras.get_popup().add_separator()
	extras.get_popup().add_item("New game (start over at Farm Road)",2)
	extras.get_popup().add_theme_font_size_override("font_size",22)
	extras.get_popup().id_pressed.connect(open_extra)
	row.add_child(extras)

func build_map() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_top = TOP_HEIGHT
	column.offset_right = -SIDEBAR_WIDTH
	column.add_theme_constant_override("separation",0)
	ui.add_child(column)
	map_view = Control.new()
	map_view.clip_contents = true
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_view.mouse_filter = Control.MOUSE_FILTER_STOP
	map_view.gui_input.connect(_on_map_input)
	map_view.mouse_exited.connect(clear_hover)
	map_view.resized.connect(fit_map)
	column.add_child(map_view)
	holder = Node2D.new()
	holder.child_entered_tree.connect(_on_holder_child)
	map_view.add_child(holder)
	var strip := panel(PANEL)
	strip.custom_minimum_size = Vector2(0,STRIP_HEIGHT)
	column.add_child(strip)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation",4)
	strip.add_child(lines)
	widgets["status"] = label("",23,GOLD)
	widgets["status"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.add_child(widgets["status"])
	widgets["hint"] = label("",19,MUTED)
	lines.add_child(widgets["hint"])

func build_sidebar() -> void:
	var side := panel(PANEL)
	side.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -SIDEBAR_WIDTH
	side.offset_top = TOP_HEIGHT
	side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side.clip_contents = true
	ui.add_child(side)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	side.add_child(column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_NONE
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	scroll.add_child(body)

	body.add_child(heading("SELECTED SOLDIER"))
	widgets["selected"] = label("",22,TEXT)
	widgets["selected"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(widgets["selected"])
	widgets["preview"] = label("",19,ACCENT)
	widgets["preview"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(widgets["preview"])

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",8)
	grid.add_theme_constant_override("v_separation",8)
	body.add_child(grid)
	for entry in [
			["mode","Aim  [T]",func(): board.toggle_sight()],
			["fire","Fire  [F]",func(): board.try_fire()],
			["reload","Reload  [R]",func(): board.try_reload()],
			["extract","Extract  [E]",func(): board.try_extract()],
			["stabilize","Stabilize  [S]",func(): board.try_stabilize()],
			["pickup","Pick up  [U]",func(): board.try_pickup()],
			["drop","Put down  [J]",func(): toggle_drop()],
			["casualty","Next casualty  [V]",func(): board.cycle_casualty()],
			["breaker","Breaker  [I]",func(): board.try_breaker()],
			["observe","Observe  [O]",func(): board.protocol_action("observe")],
			["transmit","Transmit  [P]",func(): board.protocol_action("transmit")],
			["authenticate","Authenticate  [A]",func(): board.protocol_action("authenticate")],
			["divert","Divert  [D]",func(): board.protocol_action("divert")],
			["cooling","Cooling move  [Y]",func(): board.use_cooling_move()]]:
		var button := action_button(entry[0],entry[1],entry[2])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)

	body.add_child(heading("SQUAD"))
	for index in range(4):
		var button := action_button("squad%d" % index,"",func(): pick_soldier(index))
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_child(button)

	body.add_child(heading("CIVILIANS"))
	widgets["civ_how"] = label("",18,MUTED)
	widgets["civ_how"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(widgets["civ_how"])
	widgets["civ_state"] = label("",20,GOLD)
	widgets["civ_state"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(widgets["civ_state"])
	for index in range(3):
		var button := action_button("group%d" % index,"",func(): pick_group(index))
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_child(button)
		widgets["group_note%d" % index] = label("",17,MUTED)
		widgets["group_note%d" % index].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(widgets["group_note%d" % index])
	var orders := GridContainer.new()
	orders.columns = 2
	orders.add_theme_constant_override("h_separation",8)
	orders.add_theme_constant_override("v_separation",8)
	body.add_child(orders)
	for entry in [["exit","Move to EXIT",func(): board.order_exit(board.cohort_selected)],
			["follow","Follow soldier",func(): board.order_cohort(board.cohort_selected,"follow")],
			["hold","Hold position",func(): board.order_cohort(board.cohort_selected,"hold")],
			["north","North route",func(): board.order_cohort(board.cohort_selected,"north")],
			["south","South route",func(): board.order_cohort(board.cohort_selected,"south")]]:
		var button := action_button(entry[0],entry[1],entry[2])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		orders.add_child(button)
	widgets["close_warning"] = label("",19,WARN)
	widgets["close_warning"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(widgets["close_warning"])
	var close_row := HBoxContainer.new()
	body.add_child(close_row)
	for entry in [["close","Close operation early",func(): board.request_close()],
			["cancel_close","Cancel",func(): board.close_pending = false]]:
		var button := action_button(entry[0],entry[1],entry[2])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		close_row.add_child(button)

	body.add_child(heading("THREAT"))
	for key in ["intent","danger","enemy","forecast","return_info"]:
		widgets[key] = label("",19,WARN if key == "intent" else TEXT)
		widgets[key].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(widgets[key])

	var end_turn := action_button("next","End turn  [N]",func(): board.next_phase())
	end_turn.custom_minimum_size = Vector2(0,72)
	end_turn.add_theme_font_size_override("font_size",28)
	style_button(end_turn,Color("2f6b57"))
	column.add_child(end_turn)
	style_button(actions["fire"],Color("713f36"))

func build_modal() -> void:
	modal_root = ColorRect.new()
	(modal_root as ColorRect).color = Color(0,0,0,0.72)
	modal_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_root.visible = false
	ui.add_child(modal_root)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_root.add_child(center)
	var frame := panel(PANEL)
	frame.custom_minimum_size = Vector2(1400,0)
	center.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1360,880)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_NONE
	frame.add_child(scroll)
	modal_box = VBoxContainer.new()
	modal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_box.add_theme_constant_override("separation",12)
	scroll.add_child(modal_box)

func fit_map() -> void:
	if map_view == null or holder == null: return
	var area := map_view.size
	var crop := MapLayer.CROP
	var scale_value := minf(area.x/crop.size.x,area.y/crop.size.y)
	if scale_value <= 0.0: return
	holder.scale = Vector2.ONE*scale_value
	holder.position = (area-crop.size*scale_value)/2.0-crop.position*scale_value

# ---------------------------------------------------------------- board lifecycle

func valid_board() -> bool:
	return board != null and is_instance_valid(board) and not board.is_queued_for_deletion()

func _on_holder_child(node: Node) -> void:
	if "hud_mode" in node:
		adopt(node)
	elif node is Node2D:
		# The ending logic test is a separate full-page fixture: show it on its own.
		call_deferred("show_fixture",node)

func adopt(node) -> void:
	node.hud_mode = true
	for child in node.get_children():
		if child is Camera2D: child.enabled = false
	board = node
	modal_signature = ""
	dirty = true
	node.queue_redraw()

func ensure_board() -> bool:
	if valid_board(): return true
	board = null
	for child in holder.get_children():
		if "hud_mode" in child and not child.is_queued_for_deletion():
			adopt(child)
			return true
	return false

func show_fixture(node: Node2D) -> void:
	if not is_instance_valid(node): return
	node.reparent(get_tree().root,false)
	var view := get_viewport().get_visible_rect().size
	var fit := minf(view.x/1144.0,view.y/1224.0)
	node.scale = Vector2.ONE*fit
	node.position = Vector2((view.x-1144.0*fit)/2.0,0)
	layer.visible = false
	node.tree_exited.connect(func():
		layer.visible = is_visible_in_tree()
		dirty = true)

# ---------------------------------------------------------------- input

func _on_map_input(event: InputEvent) -> void:
	if not valid_board(): return
	if not (event is InputEventMouse): return
	var local: Vector2 = (event.position-holder.position)/holder.scale.x
	var cell: Vector2i = board.local_to_cell(local)
	if event is InputEventMouseMotion:
		MapInput.hover(board,cell if board.cell_is_in_bounds(cell) else board.NONE)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			MapInput.click(board,cell)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if board.drop_mode: board.drop_mode = false
			elif board.sight_mode and board.pinned_target != board.NONE: board.pinned_target = board.NONE
			else: board.run_tactical_command("clear")
			board.queue_redraw()
		dirty = true
		map_view.accept_event()

func clear_hover() -> void:
	if valid_board(): MapInput.hover(board,board.NONE)

func run_action(callable: Callable) -> void:
	if not valid_board(): return
	callable.call()
	board.queue_redraw()
	dirty = true

func toggle_drop() -> void:
	if board.drop_mode: board.drop_mode = false
	else: board.request_drop()

func pick_soldier(index: int) -> void:
	if board.roster_open or board.scene_view != "" or board.ended: return
	board.select_soldier(index)

func pick_group(index: int) -> void:
	board.cohort_selected = index
	board.status_text = "Group %s selected. Choose an order below." % board.cohorts[index]["id"]

func open_extra(id: int) -> void:
	if id == 2:
		confirm_new = true
		dirty = true
		return
	var readability = get_node_or_null("/root/Readability")
	if readability == null: return
	if id == 0: readability.open_preview()
	else: readability.open_benchmark()

func show_help() -> void:
	board.set_meta("hud_help",true)
	dirty = true

# ---------------------------------------------------------------- refresh

func _process(delta: float) -> void:
	refresh_timer += delta
	if dirty or refresh_timer > 0.1:
		refresh()

func refresh() -> void:
	refresh_timer = 0.0
	dirty = false
	if not ensure_board(): return
	fit_map()
	refresh_top()
	refresh_strip()
	refresh_selected()
	refresh_actions()
	refresh_squad()
	refresh_civilians()
	refresh_threat()
	refresh_modal()

func refresh_top() -> void:
	var returning: bool = board.return_state["active"]
	set_text("mission","Return to Farm Road · deployment %d" % board.campaign.get("deployment",2) if returning else "Farm Road")
	set_text("round","Round %d   ·   Road closes after round %d   ·   Evacuated %d / 12" % [board.phase,board.deadline(),board.evacuated_people()])
	actions["roster"].disabled = not board.result_ready
	actions["log"].disabled = board.roster_open

func refresh_strip() -> void:
	set_text("status",board.status_text)
	var hint := "Left-click: select a soldier, then click a green (1 AP) or blue (2 AP) square to move   ·   Right-click: clear   ·   N: end turn"
	if board.drop_mode: hint = "PUT DOWN: click a square next to the carrier.   Right-click cancels."
	elif board.sight_mode: hint = "AIM MODE: click a target square to pin it, check the hit chance at right, then Fire [F].   Right-click unpins.   T: back to moving."
	elif board.ended: hint = "Operation over. " + board.save_feedback
	set_text("hint",hint)

func refresh_selected() -> void:
	var index: int = board.active_soldier
	if index >= 0 and index < board.soldiers.size():
		var soldier: Dictionary = board.soldiers[index]
		var lines := "%s  ·  %s\nHP %d/8   ·   AP %d   ·   Ammo %d   ·   Attack %s" % [soldier["name"],board.soldier_role(index),soldier["hp"],soldier["ap"],soldier["ammo"],"used" if soldier["attacked"] else "ready"]
		if soldier.get("carrying",-1) >= 0:
			lines += "\nCarrying %s: 2 squares per move, no firing or machinery." % board.soldiers[soldier["carrying"]]["name"]
		set_text("selected",lines)
	else:
		set_text("selected","No soldier selected. Click one of your soldiers on the map or in Squad below.")
	set_text("preview",preview_text())

func preview_text() -> String:
	if board.sight_mode:
		var target: Vector2i = board.sight_target()
		if board.active_soldier < 0 or not board.cell_is_in_bounds(target):
			return "Aim mode: hover or click a target square."
		var info: Dictionary = board.sight_preview(board.soldiers[board.active_soldier]["cell"],target)
		var text := "%s (%d, %d) · distance %d · %s\n" % ["Pinned" if board.pinned_target != board.NONE else "Target",target.x,target.y,info["distance"],"clear sight" if info["clear"] else "WALL BLOCKS SHOT"]
		text += ("Hit chance %d%%  (aim 75, range %+d, cover %+d)" % [info["chance"],info["range_modifier"],info["cover_modifier"]]) if info["can_fire"] else "Cannot fire at this square."
		if info["edge"] != "none":
			text += "\n%s cover edge: %s" % [str(info["edge"]).capitalize(),"protected (-25)" if info["protected"] else "flanked (0)"]
		if board.machine_present() and board.pinned_target == board.enemies[0]["cell"]:
			text += "\nMachine HP %d/16. Destroying it deals 4 blast damage to: %s" % [board.enemies[0]["hp"],board.blast_victims()]
		return text
	var path: Array = board.path_to(board.hovered_cell)
	if path.size() > 0:
		return "Move to (%d, %d): %d squares for %d AP" % [board.hovered_cell.x,board.hovered_cell.y,path.size()-1,board.move_cost(board.hovered_cell)]
	return "Green squares: 1 AP (up to 4).  Blue squares: 2 AP (5–8)."

func refresh_actions() -> void:
	var returning: bool = board.return_state["active"]
	var can_act: bool = board.soldier_can_act(board.active_soldier) and not board.ended
	actions["mode"].text = "Back to moving  [T]" if board.sight_mode else "Aim  [T]"
	gate("fire",board.fire_block_reason())
	gate("reload","" if can_act else "Select an active soldier.")
	gate("extract","" if can_act else "Select an active soldier.")
	var target: int = board.target_for_rescue()
	var casualty: bool = target >= 0 and board.casualty_available(target)
	gate("stabilize","" if can_act and casualty else "Mark a casualty and select an adjacent rescuer.")
	gate("pickup","" if can_act and casualty else "Mark a casualty and select an adjacent rescuer.")
	var carrying: bool = can_act and board.soldiers[board.active_soldier].get("carrying",-1) >= 0
	actions["drop"].text = "Cancel put down" if board.drop_mode else "Put down  [J]"
	gate("drop","" if carrying or board.drop_mode else "Only a soldier carrying a casualty can put them down.")
	actions["casualty"].text = "Casualty: %s  [V]" % (board.soldiers[target]["name"] if casualty else "none")
	if returning:
		actions["breaker"].text = "Repair machine  [I]  %d/2" % board.return_state["repair"]
		gate("breaker","" if can_act else "Select an active soldier next to the machine.")
	else:
		var progress: int = board.breaker_progress
		actions["breaker"].text = "Open breaker  [I]" if progress == 0 else ("Isolate drive  [I]" if progress == 1 else "Drive isolated")
		gate("breaker",board.breaker_reason())
	for action in ["observe","transmit","authenticate","divert"]:
		actions[action].visible = not returning
		if not returning: gate(action,board.protocol_reason(action))
	actions["cooling"].visible = returning
	if returning:
		gate("cooling","" if board.cooling_ready() and board.return_state["bonus_event"] == "" else "Cooling move unavailable or already used.")
	actions["next"].text = "End turn %d  [N]" % board.phase
	actions["next"].disabled = board.ended

func refresh_squad() -> void:
	for index in range(4):
		var button: Button = actions["squad%d" % index]
		if index >= board.soldiers.size():
			button.visible = false
			continue
		var soldier: Dictionary = board.soldiers[index]
		var health := "%d HP" % soldier["hp"]
		match soldier.get("condition","active"):
			"critical": health = "CRITICAL (bleeds %d)" % soldier.get("bleed",0)
			"stable": health = "STABLE"
			"dead": health = "DEAD"
		if soldier["extracted"]: health = "EXTRACTED"
		if soldier.get("actor_id","original") == "": health = "UNFILLED"
		button.text = "%s  ·  %s  ·  %s  ·  %d AP" % [soldier["mark"],soldier["name"],health,soldier["ap"]]
		button.set_pressed_no_signal(index == board.active_soldier)
		button.add_theme_color_override("font_color",board.soldier_color(index))

func refresh_civilians() -> void:
	var view: Dictionary = board.civilian_panel_snapshot()
	var exit_cell: Vector2i = view["exit"]
	set_text("civ_how","12 civilians in 3 groups (A, B, C — little blue tags on the map). You can give ONE group an order per turn, and orders stick. Groups only walk when you press End turn: up to 3 squares toward the teal CIVILIAN EXIT at (%d, %d). Give a different group its order each turn." % [exit_cell.x,exit_cell.y])
	set_text("civ_state","Operation ended: " + view["end_reason"] if view["ended"] else ("Group order already used this turn" if view["order_used"] else "One free group order available this turn"))
	for index in range(3):
		var cohort: Dictionary = view["cohorts"][index]
		var button: Button = actions["group%d" % index]
		button.text = "Group %s  ·  4 people  ·  HP %d/4  ·  %s" % [cohort["id"],cohort["hp"],view["labels"][index] if cohort["status"] == "active" else cohort["status"].to_upper()]
		button.set_pressed_no_signal(index == view["cohort_selected"])
		set_text("group_note%d" % index,view["notes"][index]+arrival_text(index))
	var locked: bool = view["order_used"] or view["ended"]
	for action in ["exit","follow","hold","north","south"]: actions[action].disabled = locked
	actions["north"].disabled = locked or not view["north_available"]
	actions["follow"].text = "Follow " + view["leader"]
	actions["north"].text = view["north_label"]
	actions["south"].text = view["south_label"]
	var left := 0
	for soldier in view["soldiers"]: left += 0 if soldier["extracted"] else 1
	set_text("close_warning","Close now? %d civilians will be stranded and %d soldiers left behind." % [view["remaining"],left] if view["close_pending"] else "")
	actions["close"].text = "Confirm: leave them behind" if view["close_pending"] else "Close operation early"
	actions["close"].disabled = view["ended"]
	if not actions["close"].has_meta("pending") or actions["close"].get_meta("pending") != view["close_pending"]:
		actions["close"].set_meta("pending",view["close_pending"])
		style_button(actions["close"],Color("713f36") if view["close_pending"] else Color("343b38"))
	actions["cancel_close"].visible = view["close_pending"]

func arrival_text(index: int) -> String:
	var cohort: Dictionary = board.cohorts[index]
	if cohort["status"] != "active" or cohort["order"] == "hold": return ""
	var path: Array = board.route_preview(cohort,cohort["order"])
	if path.is_empty(): return ""
	var arrival: int = board.phase+ceili(path.size()/3.0)-1
	if arrival > board.deadline():
		return "  ·  TOO SLOW: needs until round %d, road closes after round %d" % [arrival,board.deadline()]
	return "  ·  reaches EXIT end of round %d" % arrival

func refresh_threat() -> void:
	set_text("intent",board.enemy_intent())
	set_text("danger",board.danger_summary())
	set_text("enemy",board.enemy_message)
	var machine: Dictionary = board.machine
	var forecast := "none"
	if machine["collected_round"] > 0: forecast = "round %d" % (machine["collected_round"]+1)
	elif board.machine_present(): forecast = "round %d" % (board.phase+4-machine["stage"])
	var road := "Road closes after round %d." % board.deadline()
	if not board.return_state["active"] and board.machine_present() and machine["collected_round"] == 0 and not board.protocol["diverted"] and not board.disabled():
		road += " If the machine reaches its cargo, the road closes early (after %s). Stop it — shoot it (Aim → Fire) or cut its power at the breaker B (9,4) — or divert it with the console C." % forecast
	set_text("forecast",road)
	if board.return_state["active"]:
		set_text("return_info",board.machine_outcome()+"\nCooling: "+("available" if board.cooling_ready() else "unavailable")+" — one free civilian move of up to 3 squares.")
	else:
		set_text("return_info",board.machine_outcome())

# ---------------------------------------------------------------- modals

func refresh_modal() -> void:
	var content := modal_content()
	var signature := var_to_str(strip_callables(content))
	if signature == modal_signature: return
	modal_signature = signature
	for child in modal_box.get_children(): child.free()
	modal_root.visible = not content.is_empty()
	if content.is_empty(): return
	for item in content["items"]:
		match item[0]:
			"title": modal_box.add_child(label(item[1],34,GOLD))
			"heading": modal_box.add_child(heading(item[1]))
			"text":
				var text := label(item[1],item[2] if item.size() > 2 else 24,item[3] if item.size() > 3 else TEXT)
				text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				modal_box.add_child(text)
			"option":
				var option := modal_button(item[1],item[2])
				option.alignment = HORIZONTAL_ALIGNMENT_LEFT
				modal_box.add_child(option)
			"row":
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation",12)
				for entry in item[1]:
					var button := modal_button(entry[0],entry[1])
					button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					button.disabled = entry.size() > 2 and entry[2]
					row.add_child(button)
				modal_box.add_child(row)
			"split":
				var split := HBoxContainer.new()
				split.add_theme_constant_override("separation",24)
				var list := VBoxContainer.new()
				list.custom_minimum_size = Vector2(380,0)
				for entry in item[1]:
					var button := modal_button(entry[0],entry[1])
					button.toggle_mode = true
					button.set_pressed_no_signal(entry[2])
					button.alignment = HORIZONTAL_ALIGNMENT_LEFT
					list.add_child(button)
				split.add_child(list)
				var details := label(item[2],21,TEXT)
				details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				split.add_child(details)
				modal_box.add_child(split)

## Callables are recreated every refresh; compare only the visible data.
func strip_callables(value):
	if value is Callable: return "<action>"
	if value is Array:
		var copy := []
		for item in value: copy.append(strip_callables(item))
		return copy
	if value is Dictionary:
		var copy := {}
		for key in value: copy[key] = strip_callables(value[key])
		return copy
	return value

func modal_content() -> Dictionary:
	if start_menu: return start_content()
	if confirm_new: return new_game_content()
	if board.has_meta("hud_help"): return help_content()
	if board.roster_open: return roster_content()
	if board.scene_view != "": return story_content()
	if board.result_ready: return results_content()
	if board.isolate_pending: return breaker_content()
	return {}

func start_content() -> Dictionary:
	var where := "Return to Farm Road (deployment %d)" % board.campaign.get("deployment",2) if board.return_state["active"] else "Farm Road"
	var machine := "machine destroyed — no enemy on this map" if not board.machine_present() else "machine still active"
	return {"items":[["title","HOLDFAST"],
		["text","Saved game found: %s, round %d, %d / 12 civilians evacuated, %s." % [where,board.phase,board.evacuated_people(),machine],24],
		["option","New game  —  Farm Road, deployment 1, machine active (old save kept as a backup)",start_new],
		["option","Continue saved game",continue_saved]]}

func start_new() -> void:
	start_menu = false
	new_game()

func continue_saved() -> void:
	start_menu = false

func new_game_content() -> Dictionary:
	return {"items":[["title","START A NEW GAME?"],
		["text","This starts over at Farm Road, deployment 1, with the machine active. Your current campaign is kept as a backup file, not deleted.",24],
		["row",[["Start new game",func(): new_game()],["Cancel",func(): confirm_new = false]]]]}

func new_game() -> void:
	confirm_new = false
	var dir := DirAccess.open("user://")
	if dir and board_campaign_path == "":
		var stamp := Time.get_datetime_string_from_system().replace(":","-")
		for file in ["holdfast_d1_campaign.save","holdfast_c2_campaign.save","holdfast_d1.save"]:
			if dir.file_exists(file): dir.rename(file,file+"."+stamp+".bak")
	if valid_board(): board.queue_free()
	board = null
	var fresh = BoardScene.instantiate()
	fresh.auto_resume = false
	if board_campaign_path != "": fresh.campaign_path = board_campaign_path
	holder.add_child(fresh)
	modal_signature = ""

func help_content() -> Dictionary:
	return {"items":[["title","CONTROLS"],
		["text","Mouse: left-click a soldier to select it, then click a highlighted square to move (green = 1 AP, blue = 2 AP). Right-click clears the selection. Click a civilian group on the map, or in the Civilians panel, to give it an order."],
		["text","Aiming: press Aim (T), click the target square to pin it, read the hit chance in the sidebar, then Fire (F)."],
		["text","Rescue: click a downed soldier to mark them, select an adjacent soldier, then Stabilize (S) or Pick up (U). Put down (J), then click a square."],
		["text","Keys: T aim/move · F fire · R reload · E extract · N end turn · I breaker · O/P/A/D protocol · S/U/J/V rescue · Y cooling move · K save · L load · Tab scene log · G roster · Esc clear/back."],
		["row",[["Close",func(): board.remove_meta("hud_help")]]]]}

func story_content() -> Dictionary:
	var pages: Array = board.current_pages()
	var page: Dictionary = pages[clampi(board.scene_page,0,pages.size()-1)]
	var heading_text: String = {"log":"SCENE LOG","opening":"OPENING","debrief":"DEBRIEF"}.get(board.scene_view,"SCENE")
	var items: Array = [["heading",heading_text+"   ·   page %d / %d" % [board.scene_page+1,pages.size()]],
		["title",page["speaker"]],["text",page["text"],25],["text",page["tag"],19,ACCENT]]
	var options: Array = board.scene_options()
	for index in range(options.size()):
		items.append(["option","%d.  %s" % [index+1,options[index]],func(): board.choose_scene_option(index)])
	var opening_choice: bool = board.scene_view == "opening" and board.scene_page == 0
	var next_text := "Choose an option above" if opening_choice else ("Next  [Enter]" if board.scene_page+1 < pages.size() else ("Begin mission  [Enter]" if board.scene_view == "opening" else "Return  [Enter]"))
	items.append(["row",[[next_text,func(): board.advance_scene(),opening_choice],
		["Skip opening  [Esc]" if board.scene_view == "opening" else "Back  [Esc]",func(): story_back()],
		["Close log  [Tab]" if board.scene_view == "log" else "Scene log  [Tab]",func(): board.toggle_log()]]])
	return {"items":items}

func story_back() -> void:
	if board.scene_view == "opening": board.finish_opening()
	elif board.scene_view == "log": board.toggle_log()
	else: board.scene_view = ""

func results_content() -> Dictionary:
	var view: Dictionary = board.results_panel_snapshot()
	var items: Array = [["heading","MISSION RECORD"],["title",view["title"]],
		["text","Round %d  ·  %s" % [view["phase"],view["end_reason"]],22,MUTED],
		["text","MSG lost: this attempt cannot continue. Retry or load a save." if view["retry"] else "MSG recovered. Casualties and losses below stay on record.",23]]
	items.append(["heading","SQUAD"])
	for index in range(view["soldiers"].size()):
		items.append(["text","%s — %s" % [view["soldiers"][index]["name"],view["dispositions"][index]],21])
	items.append(["heading","CIVILIANS  ·  %d evacuated  ·  %d stranded" % [view["evacuated"],12-view["evacuated"]]])
	for cohort in view["cohorts"]:
		items.append(["text","Group %s (4 people): %s" % [cohort["id"],"EVACUATED" if cohort["status"] == "extracted" else "STRANDED — fate unconfirmed"],21])
	items.append(["heading","MACHINERY"])
	items.append(["text",view["outcome"]+"\n"+view["feeder"],21])
	if view["result_feedback"] != "": items.append(["text",view["result_feedback"],20,GOLD])
	var committed: bool = board.campaign["committed"]
	var buttons: Array = [["Roster  [Q]" if committed else ("Retry mission  [Q]" if view["retry"] else "Replay mission  [Q]"),func(): board.restart_attempt()],
		["Load save  [L]",func(): board.load_encounter()],
		["Save this state  [K]",save_result]]
	items.append(["row",buttons])
	var more: Array = [["Debrief  [B]",func(): board.begin_debrief(),board.retry_required()],
		["Roster / service history  [G]",func(): board.open_roster()]]
	if board.ending_available(): more.append(["Ending logic test  [Z]",func(): board.open_ending_test()])
	items.append(["row",more])
	return {"items":items}

func save_result() -> void:
	board.save_encounter()
	board.result_feedback = board.save_feedback

func roster_content() -> Dictionary:
	var view: Dictionary = board.roster_panel_snapshot()
	var campaign: Dictionary = view["campaign"]
	var list: Array = []
	for index in range(campaign["members"].size()):
		var member: Dictionary = campaign["members"][index]
		list.append(["%s%s — %s" % [member["name"]," (new)" if member["replacement"] else "",member["status"].replace("_"," ").to_upper()],func(): pick_roster(index),index == view["roster_index"]])
	var actor: Dictionary = campaign["members"][view["roster_index"]]
	var details := "%s · %s · HP %d/8\n\n%s" % [actor["name"],["MSG","Medic","Engineer","Recon"][actor["role"]],actor["hp"],"\n".join(view["details"])]
	var action := "Deploy roster  [Enter]"
	var blocked: bool = not view["deploy"]
	if campaign["deployment"] == 2: action = "Two-deployment test complete" if campaign["committed"] else "Finish this deployment first"
	elif not campaign["committed"]: action = "Retry required before continuing"
	elif not view["deploy"]: action = "MSG needs staging care first"
	var deploy := [action,func(): board.start_second_deployment(),blocked]
	if board.ending_available(): deploy = ["Ending logic test  [Z]",func(): board.open_ending_test(),false]
	return {"items":[["heading","ROSTER  ·  DEPLOYMENT %d / 2  ·  %d mission records" % [campaign["deployment"],campaign["missions"].size()]],
		["text","Confirmed deaths stay in service records. Replacements are separate people.",20,MUTED],
		["split",list,details],
		["text","Next deployment: survivors keep their remaining HP. Ammo, AP and medic charges refill at staging. Deployment 2 returns to the same map with new civilians.",19,MUTED],
		["row",[["Staging care  [T]" if view["care"] else "No patients need staging care",func(): board.provide_staging_care(),not view["care"]],
			deploy,["Back  [Esc]",func(): board.roster_open = false]]],
		["text",view["result_feedback"],19,GOLD]]}

func pick_roster(index: int) -> void:
	board.roster_index = index
	board.history_page = 0

func breaker_content() -> Dictionary:
	return {"items":[["title","ISOLATE THE DRIVE?  (1 AP)"],
		["text","Stops the machine and clears its charged shot.\nThe feeder loses power: civilian gates (11,7) and (11,10) lock.\nNorth route becomes (11,7) → (11,4); south becomes (11,10) → (11,11).\nGroups already heading for a waypoint use the bypass.\nSoldiers keep manual access. The machine stays for later repair.\nA collected skid and an advanced deadline are NOT reversed.",24],
		["row",[["Confirm isolate  [I]",func(): board.try_breaker(true)],["Cancel  [Esc]",func(): board.isolate_pending = false]]]]}

# ---------------------------------------------------------------- widget helpers

func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font = ThemeDB.fallback_font
	theme.default_font_size = 22
	var states := {"normal":Color("304965"),"hover":Color("3d5c80"),"pressed":Color("476b59"),"disabled":Color("2a302d"),"focus":Color(0,0,0,0)}
	for state in states:
		var box := StyleBoxFlat.new()
		box.bg_color = states[state]
		box.set_corner_radius_all(6)
		box.content_margin_left = 14
		box.content_margin_right = 14
		box.content_margin_top = 8
		box.content_margin_bottom = 8
		if state == "focus": box.draw_center = false
		theme.set_stylebox(state,"Button",box)
	theme.set_stylebox("hover_pressed","Button",theme.get_stylebox("pressed","Button"))
	theme.set_color("font_color","Button",Color.WHITE)
	theme.set_color("font_disabled_color","Button",Color("7c8782"))
	theme.set_color("font_pressed_color","Button",Color.WHITE)
	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = PANEL
	panel_box.content_margin_left = 18
	panel_box.content_margin_right = 18
	panel_box.content_margin_top = 10
	panel_box.content_margin_bottom = 10
	theme.set_stylebox("panel","PanelContainer",panel_box)
	theme.set_color("font_color","Label",TEXT)
	return theme

func panel(color: Color) -> PanelContainer:
	var box := PanelContainer.new()
	if color != PANEL:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		box.add_theme_stylebox_override("panel",style)
	return box

func label(text: String, size_value: int, color: Color) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size",size_value)
	item.add_theme_color_override("font_color",color)
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return item

func heading(text: String) -> Label:
	var item := label(text,20,ACCENT)
	item.add_theme_constant_override("line_spacing",0)
	return item

func action_button(key: String, text: String, callable: Callable, width: float = 0.0) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(width,52)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(func(): run_action(callable))
	actions[key] = button
	return button

func modal_button(text: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0,60)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.add_theme_font_size_override("font_size",24)
	button.pressed.connect(func(): run_action(callable))
	return button

func style_button(button: Button, color: Color) -> void:
	var box: StyleBoxFlat = ui.theme.get_stylebox("normal","Button").duplicate()
	box.bg_color = color
	button.add_theme_stylebox_override("normal",box)
	var hover: StyleBoxFlat = box.duplicate()
	hover.bg_color = color.lightened(0.15)
	button.add_theme_stylebox_override("hover",hover)

func gate(key: String, reason: String) -> void:
	actions[key].disabled = reason != ""
	actions[key].tooltip_text = reason

func set_text(key: String, text: String) -> void:
	if widgets[key].text != text: widgets[key].text = text
