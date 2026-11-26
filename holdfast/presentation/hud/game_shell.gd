extends Control
## Desktop game screen (1920×1080 landscape). The encounter controller keeps every rule;
## this shell draws the map large on the left and real buttons/panels around it.
## Keyboard shortcuts still go straight to the controller, so they behave exactly as before.

const BoardScene = preload("res://farm_final.tscn")
const RiverScene = preload("res://river_bridge.tscn")
const MainScene = preload("res://main_street.tscn")
const InterchangeScene = preload("res://interchange.tscn")
const RailScene = preload("res://rail_yard.tscn")
const HospitalScene = preload("res://county_hospital.tscn")
const QuarryScene = preload("res://quarry.tscn")
const AirfieldScene = preload("res://regional_airfield.tscn")
const CivicScene = preload("res://civic_center.tscn")
const NordicCraft = preload("res://systems/nordic_craft.gd")
const QuarryWorks = preload("res://systems/quarry_works.gd")
const HospitalPower = preload("res://systems/hospital_power.gd")
const Team = preload("res://systems/fire_team.gd")
const Yard = preload("res://systems/grey_yard.gd")
const Crew = preload("res://systems/drover_crew.gd")
const Fallow = preload("res://systems/fallow_cutter.gd")
const Greys = preload("res://systems/grey_team.gd")
const MapInput = preload("res://presentation/hud/map_input.gd")
const MapLayer = preload("res://presentation/hud/map_layer.gd")
const Command = preload("res://systems/civilian_command.gd")
const Arc = preload("res://data/campaign_arc.gd")
const Record = preload("res://systems/campaign_record.gd")

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
## Campaign record (what each mission leaves behind). Tests get a throwaway file.
var campaign_record_path := ""
var show_operations := false
var last_record_signature := ""
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
	campaign_record_path = Record.PATH if board_campaign_path == "" else board_campaign_path.get_basename()+"-record.save"
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
			["operations","Operations",func(): open_operations()],
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
	widgets["sidebar_scroll"] = scroll
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",8)
	scroll.add_child(body)

	var priority := panel(Color("5a2a22"))
	widgets["priority_box"] = priority
	body.add_child(priority)
	widgets["priority"] = label("",20,Color("ffe1d6"))
	widgets["priority"].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	priority.add_child(widgets["priority"])

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
			["cooling","Cooling move  [Y]",func(): board.use_cooling_move()],
			["lanes_people","Bridge: people first",func(): board.set_lanes("people")],
			["lanes_heavy","Bridge: heavy lane",func(): board.set_lanes("heavy")],
			["sensor","Recover sensor",func(): board.recover_sensor()],
			["interrupt","Interrupt node",func(): board.interrupt_node()],
			["component","Recover component",func(): board.recover_component()],
			["ic_observe","Observe hauler (MSG)",func(): board.observe_hauler()],
			["ic_drone","Observe drone",func(): board.observe_drone()],
			["ic_pause","Transmit pause (MSG)",func(): board.transmit_pause(false)],
			["ic_gift","Pause + return component",func(): board.transmit_pause(true)],
			["suppress","Suppress  (2 rounds)",func(): board.suppress()],
			["restrain","Restrain",func(): board.restrain()],
			["ry_bypass","Bypass lock (Bell)",func(): board.bypass_lock()],
			["ry_cut","Cut lock (2 AP)",func(): board.cut_lock()],
			["ry_download","Download archive",func(): board.download_archive()],
			["ry_brake","Release handcar",func(): board.release_brake()],
			["ry_trade","Accept Grey trade (MSG)",func(): board.accept_trade()],
			["ch_power_ambulance","Power: ambulance",func(): board.toggle_power("ambulance")],
			["ch_power_scanner","Power: scanner",func(): board.toggle_power("scanner")],
			["ch_power_lights","Power: fence lights",func(): board.toggle_power("lights")],
			["ch_load","Load ambulance",func(): board.load_ambulance()],
			["ch_badge","Check credentials",func(): board.check_credentials()],
			["ch_scan","Scan person",func(): board.scan_person()],
			["ch_detain","Detain person",func(): board.detain_person()],
			["ch_monitor","Convoy: monitored passage",func(): board.answer_convoy("monitored")],
			["ch_reserve","Convoy: reserve the road",func(): board.answer_convoy("reserved")],
			["ch_hold","Team: hold by soldier",func(): board.order_team("hold")],
			["ch_protect","Team: protect group",func(): board.order_team("protect")],
			["ch_withdraw","Team: withdraw",func(): board.order_team("withdraw")],
			["q_charge","Set charge (2 AP)",func(): board.set_charge()],
			["q_junction","Kill junction box",func(): board.kill_junction()],
			["q_safeoff","Confirm safe-off",func(): board.confirm_safe_off()],
			["q_controller","Recover controller",func(): board.recover_controller()],
			["q_dig","Dig debris",func(): board.dig()],
			["q_node","Interrupt node",func(): board.interrupt_ridge_node()],
			["q_rig_move","Rig: move to soldier",func(): board.order_rig("move")],
			["q_rig_dig","Rig: dig",func(): board.order_rig("dig")],
			["q_rig_brace","Rig: brace",func(): board.order_rig("brace")],
			["af_contact","Contact the craft (MSG)",func(): board.make_contact()],
			["af_shield","Nordic shield on group",func(): board.request_shield()],
			["af_data","Download sensor data",func(): board.download_sensors()],
			["af_bargain","Accept Grey bargain (MSG)",func(): board.accept_bargain()],
			["af_bypass","Bypass pod lock (Bell)",func(): board.pod_bypass()],
			["af_cut","Cut pod open (2 AP)",func(): board.pod_cut()],
			["af_node","Interrupt node",func(): board.interrupt_runway_node()],
			["af_hold","Team: hold by soldier",func(): board.order_team("hold")],
			["af_protect","Team: protect group",func(): board.order_team("protect")],
			["af_withdraw","Team: withdraw",func(): board.order_team("withdraw")],
			["cc_scout","Scout (Park)",func(): board.scout()],
			["cc_door","Force service door",func(): board.force_door()],
			["cc_records","Download records",func(): board.download_records()],
			["cc_bypass","Bypass pen lock (Bell)",func(): board.bypass_pen()],
			["cc_cut","Cut pen (2 AP)",func(): board.cut_pen()],
			["cc_shield","Ask Aven: shield the convoy",func(): board.shield_convoy()]]:
		var button := action_button(entry[0],entry[1],entry[2])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)

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
			["south","South route",func(): board.order_cohort(board.cohort_selected,"south")],
			["calm","Calm group  [C]",func(): board.calm_cohort(board.cohort_selected)]]:
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

	body.add_child(heading("SQUAD"))
	for index in range(4):
		var button := action_button("squad%d" % index,"",func(): pick_soldier(index))
		button.toggle_mode = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		body.add_child(button)

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
	node.command_model = "authority"
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C and valid_board() and layer.visible and not modal_root.visible:
		run_action(func(): board.calm_cohort(board.cohort_selected))
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	refresh_timer += delta
	if dirty or refresh_timer > 0.1:
		refresh()

func refresh() -> void:
	refresh_timer = 0.0
	dirty = false
	if not ensure_board(): return
	if board.result_ready and not board.return_state["active"]:
		var signature := var_to_str(Record.civic_center_entry(board) if is_civic() else Record.airfield_entry(board) if is_airfield() else Record.quarry_entry(board) if is_quarry() else Record.county_hospital_entry(board) if is_hospital() else Record.rail_yard_entry(board) if is_rail() else Record.interchange_entry(board) if is_interchange() else (Record.main_street_entry(board) if is_main() else (Record.river_bridge_entry(board) if is_river() else Record.farm_road_entry(board))))
		if signature != last_record_signature:
			last_record_signature = signature
			if is_civic(): Record.record_civic_center(campaign_record_path,board)
			elif is_airfield(): Record.record_airfield(campaign_record_path,board)
			elif is_quarry(): Record.record_quarry(campaign_record_path,board)
			elif is_hospital(): Record.record_county_hospital(campaign_record_path,board)
			elif is_rail(): Record.record_rail_yard(campaign_record_path,board)
			elif is_interchange(): Record.record_interchange(campaign_record_path,board)
			elif is_main(): Record.record_main_street(campaign_record_path,board)
			elif is_river(): Record.record_river_bridge(campaign_record_path,board)
			else: Record.record_farm_road(campaign_record_path,board)
	fit_map()
	refresh_top()
	refresh_strip()
	refresh_selected()
	refresh_actions()
	refresh_squad()
	refresh_civilians()
	refresh_threat()
	refresh_priority()
	refresh_modal()

func refresh_top() -> void:
	var returning: bool = board.return_state["active"]
	set_text("mission","Continuity test · Return to Farm Road" if returning else Arc.label(mission_number()))
	set_text("round","Round %d   ·   Closes after round %d   ·   Evacuated %d / 12" % [board.phase,board.deadline(),board.evacuated_people()])
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
		text += ("Hit chance %d%%  (aim 75, range %+d, cover %+d%s)" % [info["chance"],info["range_modifier"],info["cover_modifier"],", elevation %+d" % info["elevation"] if info.get("elevation",0) != 0 else ""]) if info["can_fire"] else "Cannot fire at this square."
		if info["edge"] != "none":
			text += "\n%s cover edge: %s" % [str(info["edge"]).capitalize(),"protected (-25)" if info["protected"] else "flanked (0)"]
		if board.machine_present() and board.pinned_target == board.enemies[0]["cell"]:
			text += "\n%s HP %d/%d. Destroying it deals 4 blast damage to: %s" % ["Platform" if is_main() else "Machine",board.enemies[0]["hp"],board.mission_definition().machine_hp,board.blast_victims()]
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
	var river := is_river()
	for action in ["lanes_people","lanes_heavy","sensor"]: actions[action].visible = river
	var interchange := is_interchange()
	var rail := is_rail()
	var hospital := is_hospital()
	var quarry := is_quarry()
	var airfield := is_airfield()
	var civic := is_civic()
	actions["breaker"].visible = not river and not interchange and not rail and not hospital and not quarry and not airfield and not civic
	for action in ["cc_scout","cc_door","cc_records","cc_bypass","cc_cut","cc_shield"]: actions[action].visible = civic
	if civic:
		gate("cc_scout",board.scout_reason())
		actions["cc_door"].visible = not board.door_open
		gate("cc_door",board.door_reason())
		gate("cc_records",board.records_reason())
		actions["cc_bypass"].visible = board.hatch_found and not board.pen["open"]
		actions["cc_cut"].visible = board.hatch_found and not board.pen["open"]
		gate("cc_bypass",board.bypass_reason())
		gate("cc_cut",board.cut_reason())
		actions["cc_shield"].visible = board.aven_charge and not board.convoy_shield
		gate("cc_shield",board.shield_reason())
	var airfield_actions := ["af_contact","af_shield","af_data","af_bargain","af_bypass","af_cut","af_node","af_hold","af_protect","af_withdraw"]
	for action in airfield_actions: actions[action].visible = airfield
	if airfield:
		gate("af_contact",board.contact_reason())
		gate("af_shield",board.shield_reason())
		gate("af_data",board.data_reason())
		actions["af_bargain"].visible = board.bargain_offered()
		if board.bargain_offered(): gate("af_bargain",board.bargain_reason())
		actions["af_bypass"].visible = board.pod["active"] and not board.pod["open"]
		actions["af_cut"].visible = board.pod["active"] and not board.pod["open"]
		if board.pod["active"]:
			gate("af_bypass",board.pod_bypass_reason())
			gate("af_cut",board.pod_cut_reason())
		gate("af_node","" if can_act and board.fallow["stage"] == "active" else "No node to interrupt.")
		for action in ["af_hold","af_protect","af_withdraw"]: gate(action,board.team_reason())
	for action in ["q_charge","q_junction","q_safeoff","q_controller","q_dig","q_node","q_rig_move","q_rig_dig","q_rig_brace"]: actions[action].visible = quarry
	if quarry:
		gate("q_charge",board.charge_reason())
		gate("q_junction",board.junction_reason())
		gate("q_safeoff",board.safe_off_reason())
		gate("q_controller",board.controller_reason())
		gate("q_dig",board.dig_reason())
		gate("q_node","" if can_act and board.fallow["stage"] == "active" else "No node to interrupt.")
		for action in ["q_rig_move","q_rig_dig","q_rig_brace"]:
			actions[action].visible = board.rig["present"]
			if board.rig["present"]: gate(action,board.rig_reason())
	var hospital_actions := ["ch_power_ambulance","ch_power_scanner","ch_power_lights","ch_load","ch_badge","ch_scan","ch_detain","ch_monitor","ch_reserve","ch_hold","ch_protect","ch_withdraw"]
	for action in hospital_actions: actions[action].visible = hospital
	if hospital:
		for system in ["ambulance","scanner","lights"]:
			var on: bool = HospitalPower.powered(board.power,system)
			actions["ch_power_"+system].text = "Power: %s (%s)" % [{"ambulance":"ambulance","scanner":"scanner","lights":"fence lights"}[system],"ON" if on else "off"]
			gate("ch_power_"+system,board.power_reason(system))
		gate("ch_load",board.load_reason())
		gate("ch_badge",board.screen_reason("credentials"))
		gate("ch_scan",board.screen_reason("scan"))
		gate("ch_detain",board.detain_reason())
		var convoy_open: bool = board.convoy["stage"] == "arrived" and board.convoy["contact"] and board.convoy["choice"] == "none"
		actions["ch_monitor"].visible = convoy_open
		actions["ch_reserve"].visible = convoy_open
		if convoy_open:
			gate("ch_monitor",board.convoy_reason())
			gate("ch_reserve",board.convoy_reason())
		for action in ["ch_hold","ch_protect","ch_withdraw"]: gate(action,board.team_reason())
	for action in ["ry_bypass","ry_cut","ry_download","ry_brake","ry_trade"]: actions[action].visible = rail
	if rail:
		gate("ry_bypass",board.bypass_reason())
		gate("ry_cut",board.cut_reason())
		gate("ry_download",board.download_reason())
		gate("ry_brake",board.brake_reason())
		actions["ry_trade"].visible = board.trade_offered()
		if board.trade_offered(): gate("ry_trade",board.trade_reason())
	elif interchange:
		gate("ic_observe",board.observe_hauler_reason())
		gate("ic_drone",board.observe_drone_reason())
		gate("ic_pause",board.pause_reason(false))
		actions["ic_gift"].visible = board.component_held
		if board.component_held: gate("ic_gift",board.pause_reason(true))
		gate("suppress",board.suppress_reason())
		gate("restrain",board.restrain_reason())
	elif river:
		var lane_reason: String = "" if can_act and board.lanes == "" else ("Lanes already set: " + board.lanes if board.lanes != "" else "Select a soldier at the checkpoint (8,8).")
		gate("lanes_people",lane_reason)
		gate("lanes_heavy",lane_reason)
		gate("sensor","" if can_act and not board.sensor_recovered else ("Sensor recovered." if board.sensor_recovered else "Select a soldier next to the reeds (6,14)."))
	elif returning:
		actions["breaker"].text = "Repair machine  [I]  %d/2" % board.return_state["repair"]
		gate("breaker","" if can_act else "Select an active soldier next to the machine.")
	else:
		var progress: int = board.breaker_progress
		actions["breaker"].text = "Open breaker  [I]" if progress == 0 else ("Isolate drive  [I]" if progress == 1 else "Drive isolated")
		if is_main(): actions["breaker"].text = "Junction box: open  [I]" if progress == 0 else ("Junction box: isolate  [I]" if progress == 1 else "Platform isolated")
		gate("breaker",board.breaker_reason())
	var main := is_main()
	for action in ["interrupt","component"]: actions[action].visible = main
	for action in ["ic_observe","ic_drone","ic_pause","suppress","restrain"]: actions[action].visible = interchange
	if not interchange: actions["ic_gift"].visible = false
	if main:
		var near_node: bool = can_act and Fallow.node_present(board.fallow) and Fallow.distance(board.soldiers[board.active_soldier]["cell"],board.fallow["node"]) <= 1
		gate("interrupt","" if near_node and not board.fallow["interrupted"] and board.soldiers[board.active_soldier]["ap"] >= 1 else ("The node is already interrupted." if board.fallow["interrupted"] else ("No node yet." if not Fallow.node_present(board.fallow) else "Select a soldier with 1 AP next to the node (%d,%d)." % [board.fallow["node"].x,board.fallow["node"].y])))
		var component: Vector2i = board.drover["component"]
		var near_part: bool = can_act and component != board.NONE and not board.drover["recovered"] and Fallow.distance(board.soldiers[board.active_soldier]["cell"],component) <= 1
		gate("component","" if near_part and board.soldiers[board.active_soldier]["ap"] >= 1 else ("Component recovered." if board.drover["recovered"] else ("Nothing dropped yet." if component == board.NONE else "Select a soldier with 1 AP next to the component (%d,%d)." % [component.x,component.y])))
	for action in ["observe","transmit","authenticate","divert"]:
		var legacy := not returning and not river and not interchange and not rail and not hospital and not quarry and not airfield and not civic
		actions[action].visible = legacy
		if legacy: gate(action,board.protocol_reason(action))
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
	set_text("civ_how",(board.screening_summary()+"\n\n" if is_hospital() else "")+"MSG can order any group within %d squares, free. Any other soldier can order a group within %d squares for 1 AP. Gunfire or the machine within %d squares scares a group: SHAKEN groups move 2, PANICKED groups won't take orders and run. MSG within %d squares keeps a group steady, and Calm talks them down (1 AP). Groups walk when you end the turn, toward the CIVILIAN EXIT at (%d, %d)." % [Command.VOICE_RANGE,Command.NEAR_RANGE,Command.THREAT_RANGE,Command.STEADY_RANGE,exit_cell.x,exit_cell.y])
	var selected: int = view["cohort_selected"]
	var selected_cohort: Dictionary = board.cohorts[selected]
	var authority: Dictionary = Command.order_authority(board.soldiers,board.active_soldier,selected_cohort)
	var calm: Dictionary = Command.calm_authority(board.soldiers,board.active_soldier,selected_cohort)
	if view["ended"]: set_text("civ_state","Operation ended: " + view["end_reason"])
	elif selected_cohort["status"] != "active": set_text("civ_state","Group %s is %s." % [selected_cohort["id"],selected_cohort["status"]])
	else: set_text("civ_state","Group %s selected · %s · %s" % [selected_cohort["id"],Command.level_name(selected_cohort),authority["text"]])
	for index in range(3):
		var cohort: Dictionary = view["cohorts"][index]
		var button: Button = actions["group%d" % index]
		var state: String = view["labels"][index] if cohort["status"] == "active" else cohort["status"].to_upper()
		var fear: int = Command.level(board.cohorts[index])
		button.text = "Group %s  ·  HP %d/4  ·  %s%s" % [cohort["id"],cohort["hp"],state,"" if fear == 0 or cohort["status"] != "active" else "  ·  " + Command.level_name(board.cohorts[index])]
		button.add_theme_color_override("font_color",[Color.WHITE,WARN,Color("ff8a80")][fear] if cohort["status"] == "active" else MUTED)
		button.set_pressed_no_signal(index == selected)
		set_text("group_note%d" % index,view["notes"][index]+arrival_text(index))
	var locked: bool = view["ended"] or selected_cohort["status"] != "active" or not authority["ok"]
	for action in ["exit","follow","hold","north","south"]:
		actions[action].disabled = locked
		actions[action].tooltip_text = authority["text"]
	actions["north"].disabled = locked or not view["north_available"]
	actions["follow"].text = "Follow " + view["leader"]
	actions["north"].text = view["north_label"]
	actions["south"].text = view["south_label"]
	gate("calm","" if calm["ok"] and not view["ended"] else calm["text"])
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

## Farm Road's real objective: stop the machine before it reaches its cargo.
func machine_threat_active() -> bool:
	return not board.return_state["active"] and board.machine_present() and board.machine["collected_round"] == 0 and not board.protocol["diverted"] and not board.disabled() and not board.ended

func cargo_round() -> int:
	return board.phase+board.mission_definition().machine_collect_stage-board.machine["stage"]

func refresh_priority() -> void:
	var box: Control = widgets["priority_box"]
	if is_river():
		var greys: Dictionary = board.greys
		var text := ""
		if board.ended: text = ""
		elif board.lanes == "": text = "SET THE BRIDGE LANES — nobody can cross until a soldier at the checkpoint (8,8) chooses: People first (all rows, supplies lost) or Heavy lane (supplies cross, civilians single file)."
		elif not greys["withdrawn"] and not greys["lift"].is_empty():
			var cohort: Dictionary = board.cohorts[greys["lift"]["group"]]
			text = "LIFT on group %s — %d more Grey phase. Shoot the Collector to break it, or get the group into the barn (14–15, 11–12). Distance won't save them." % [cohort["id"],greys["lift"]["count"]]
		elif not greys["withdrawn"] and not greys["aim"].is_empty():
			text = "BEAM aimed at (%d,%d). Move that soldier off the line before you end the turn." % [greys["aim"]["cell"].x,greys["aim"]["cell"].y]
		elif not greys["withdrawn"]:
			text = "GREYS on the far bank. They take people, not ground. They leave after round %d; the crossing closes after round %d." % [Greys.WITHDRAW_ROUND,board.deadline()]
		set_text("priority",text)
		box.visible = text != ""
		return
	if is_civic():
		set_text("priority",civic_priority())
		box.visible = widgets["priority"].text != ""
		return
	if is_airfield():
		set_text("priority",airfield_priority())
		box.visible = widgets["priority"].text != ""
		return
	if is_quarry():
		set_text("priority",quarry_priority())
		box.visible = widgets["priority"].text != ""
		return
	if is_hospital():
		set_text("priority",hospital_priority())
		box.visible = widgets["priority"].text != ""
		return
	if is_rail():
		set_text("priority",rail_priority())
		box.visible = widgets["priority"].text != ""
		return
	if is_interchange():
		set_text("priority",interchange_priority())
		box.visible = widgets["priority"].text != ""
		return
	if is_main():
		set_text("priority",main_priority())
		box.visible = widgets["priority"].text != ""
		return
	if machine_threat_active():
		var turns: int = cargo_round()-board.phase
		var when := "THIS round" if turns <= 0 else ("next round" if turns == 1 else "in %d rounds (round %d)" % [turns,cargo_round()])
		set_text("priority","STOP THE MACHINE — it grabs its cargo %s, then the road closes a round later. Shoot it (Aim → click MACHINE → Fire, %d HP), cut power at breaker B (9,4), or divert it at console C (11,12)." % [when,board.enemies[0]["hp"]])
		box.visible = true
	elif not board.return_state["active"] and board.machine["collected_round"] > 0 and not board.ended:
		set_text("priority","The machine took its cargo. The road closes after round %d — get every group moving now." % board.deadline())
		box.visible = true
	else:
		box.visible = false

func civic_priority() -> String:
	if board.ended: return ""
	for entry in board.garrison["units"]:
		if entry["hp"] > 0 and not entry["aim"].is_empty():
			return "TROOPER AIMING at (%d,%d). Move off the red line. Entrenched troopers also shoot cover away." % [entry["aim"]["cell"].x,entry["aim"]["cell"].y]
	if board.mortar["mark"] != board.NONE: return "MORTAR IMPACT marked (orange 3×3) at (%d,%d): 4 damage and the cover goes. Get clear, or kill the spotter on the annex roof." % [board.mortar["mark"].x,board.mortar["mark"].y]
	if board.mortar["convoy_mark"]: return "THE MORTAR IS ON THE CONVOY. Kill the spotter (annex roof) or each round costs a vehicle."
	if not board.garrison["alarm"]: return "QUIET, FOR NOW — the alarm comes at round %d. A shot inside, the pen or the records terminal trips it early. Park can Scout to mark hidden troopers (and the concealed hatch)." % board.garrison["alarm_round"]
	if board.garrison["load"] > 0: return "DETAINEES BEING MOVED — hit an extraction trooper to break it, or open the pen first."
	return ""

func airfield_priority() -> String:
	if board.ended: return ""
	for entry in board.strip["units"]:
		if entry["hp"] > 0 and not entry["aim"].is_empty() and not board.strip["withdrawn"]:
			return "GREY BEAM aimed at (%d,%d). Move off the red line, or ask Aven for a shield." % [entry["aim"]["cell"].x,entry["aim"]["cell"].y]
	if not board.fallow["marked"].is_empty(): return "FALLOW MARKS on the field (violet). They turn to rift next phase; two on the runway ruins it. A Nordic shield over a group keeps its ground."
	if board.bargain_offered(): return "GREY CHANNEL (this round only): one engine, three rounds, the apron; the people untouched. MSG can accept."
	if not board.craft["contact"] and NordicCraft.window_open(board.craft,board.phase):
		return "MAKE CONTACT — MSG to the hangar 2 hatch (15,3) by the end of round %d. Meanwhile the Greys are stripping the plane's engines." % NordicCraft.WINDOW_ROUND
	return ""

func quarry_priority() -> String:
	if board.ended: return ""
	var works: Dictionary = board.works
	if works["charge_set"] and not works["destroyed"]: return "CHARGE SET — the platform blows next phase. Get everyone clear of it (4 blast damage next to it)."
	if not board.fallow["marked"].is_empty(): return "GROUND MARKED — violet squares turn to rift next phase. Move people off, interrupt the node, or brace the rig beside them."
	if not works["collapsed"]:
		var tunnel := 0
		for cohort in board.cohorts: tunnel += 1 if cohort["status"] == "active" and board.in_tunnel(cohort["cell"]) else 0
		if tunnel > 0: return "%d group%s in the haul tunnel — it collapses after round %d. West mouth: dead trunk + dig (or demolish). Airshaft (11,13): the long way, open now." % [tunnel,"" if tunnel == 1 else "s",QuarryWorks.COLLAPSE_ROUND]
	return ""

func hospital_priority() -> String:
	if board.ended: return ""
	var power: Dictionary = board.power
	if board.phase == 1 and HospitalPower.used(power) == 0:
		return "ASSIGN POWER — MSG at the generator room (2,8). You have %d system%s: ambulance charger, triage scanner or fence lights." % [HospitalPower.capacity(power),"" if HospitalPower.capacity(power) == 1 else "s"]
	if not board.reptilians["cone"].is_empty():
		return "SONIC CONE marked (violet). Anyone in it next phase loses 1 AP; groups in it panic. Spread out and step clear."
	if board.convoy["stage"] == "arrived" and board.convoy["contact"] and board.convoy["choice"] == "none":
		return "KESH ON THE CHANNEL — the Drover convoy needs the road for rounds 5–6. MSG within 6 of it: monitored passage (coupling: +1 power) or reserve the road."
	for entry in board.reptilian_targets():
		return "REPTILIAN TROOPERS inside the fence. They take any group they end next to, gurneys first. Shots on their armor deal 3."
	if not board.screening["acted"] and board.phase <= 3:
		return "SCREEN BEFORE ROUND 3 — at the triage tent (12,6), check credentials (and scan, if powered). Two discrepancies confirm; then detain. Keep a soldier with eyes on the north gate (12,2) in round 3."
	return ""

func rail_priority() -> String:
	if board.ended: return ""
	var yard: Dictionary = board.yard
	if yard["withdrawn"]: return "" if board.remaining_civilians() == 0 else "The transport is gone. Get everyone out the west exit before the yard closes after round %d." % board.deadline()
	for entry in yard["units"]:
		if entry["hp"] > 0 and not entry["aim"].is_empty():
			return "BEAM aimed at (%d,%d). Move that soldier off the red line before you end the turn." % [entry["aim"]["cell"].x,entry["aim"]["cell"].y]
	if not yard["load"].is_empty():
		var cohort: Dictionary = board.cohorts[yard["load"]["group"]]
		return "LOADING group %s next Grey phase. Open their pen or hit the Collector to stop it." % cohort["id"]
	if board.trade_offered():
		return "GREY OFFER on the channel (this round only): survey records for leaving the transport, ramp and terminal alone for %d rounds. It doesn't cover the pens." % Yard.TRADE_ROUNDS
	return "FREE THE PENS — the Collector loads one every two rounds from round %d; the transport lifts after round %d. Bell bypasses a lock (1 AP); anyone can cut one (2 AP)." % [Yard.FIRST_LOAD,Yard.DEPART_ROUND]

func interchange_priority() -> String:
	if board.ended: return ""
	var crew: Dictionary = board.crew
	for entry in crew["units"]:
		if Crew.hostile(crew,board.phase) and not entry["aim"].is_empty() and Crew.unit_fighting(entry):
			return "DROVER SECURITY AIMING at (%d,%d). Move that soldier off the red line, or Suppress the shooter (−20 Aim)." % [entry["aim"]["cell"].x,entry["aim"]["cell"].y]
	if board.drone_visible() and not board.drone["observed"] and not board.drone["fired"]:
		return "GREY DRONE at (%d,%d). It isn't Drover. Observe it (1 AP, any soldier in sight) so everyone sees whose it is, or shoot it down (4 HP)." % [board.drone["cell"].x,board.drone["cell"].y]
	if Crew.pause_active(crew):
		return "PAUSE HOLDING through round %d. Civilians can cross the work zone; soldiers stay on the green lane (row %d) near the hauler." % [crew["pause"]["until"],board.LANE_ROW]
	if not crew["left"] and crew["pause"]["state"] == "none" and crew["agreement"] == "none":
		return "OPEN THE JUNCTION — civilians won't enter the Drover work zone. MSG within %d of the hauler can Transmit a pause%s, or take the frontage road, or assault. They leave after round %d; the convoy window closes after round %d." % [Crew.VOICE_RANGE,"" if board.acknowledged else " (Observe the hauler first: no ACK-01 on record)",Crew.LEAVE_ROUND,board.deadline()]
	return ""

func main_priority() -> String:
	if board.ended: return ""
	var fallow: Dictionary = board.fallow
	if Fallow.cutter_alive(fallow) and not fallow["marked"].is_empty():
		return "GROUND MARKED — %d violet squares turn to rift next turn: anyone on them takes 4 damage. Move people off, interrupt the node (%d,%d) to buy a turn, or kill the cutter (%d HP)." % [fallow["marked"].size(),fallow["node"].x,fallow["node"].y,fallow["cutter"]["hp"]]
	if fallow["stage"] == "signaled":
		return "SOMETHING IS COMING — a distortion at the north-east end of the alley (%d,%d). It arrives next turn." % [fallow["entry"].x,fallow["entry"].y]
	if machine_threat_active():
		var turns: int = cargo_round()-board.phase
		var when := "THIS round" if turns <= 0 else ("next round" if turns == 1 else "in %d rounds (round %d)" % [turns,cargo_round()])
		return "STOP THE PLATFORM — it reaches the substation %s, then the corridor closes two rounds later. Shoot it (%d HP), cut power at junction box JB (%d,%d), or redirect it at control panel CP (%d,%d)." % [when,board.enemies[0]["hp"],board.BREAKER_CELL.x,board.BREAKER_CELL.y,board.CONSOLE_CELL.x,board.CONSOLE_CELL.y]
	if board.machine["collected_round"] > 0:
		return "Substation down. The corridor closes after round %d — get every group moving now." % board.deadline()
	return ""

func refresh_threat() -> void:
	set_text("intent",board.enemy_intent())
	set_text("danger",board.danger_summary())
	set_text("enemy",board.enemy_message)
	var machine: Dictionary = board.machine
	var forecast := "none"
	if machine["collected_round"] > 0: forecast = "round %d" % (machine["collected_round"]+1)
	elif board.machine_present(): forecast = "round %d" % (cargo_round()+1)
	var road := "Road closes after round %d." % board.deadline()
	if not board.return_state["active"] and board.machine_present() and machine["collected_round"] == 0 and not board.protocol["diverted"] and not board.disabled():
		road += " If the machine reaches its cargo, the road closes early (after %s). Stop it — shoot it (Aim → Fire) or cut its power at the breaker B (%d,%d) — or divert it with the console C." % [forecast,board.BREAKER_CELL.x,board.BREAKER_CELL.y]
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
			"acts":
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation",12)
				for act in item[1]:
					var column := VBoxContainer.new()
					column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					column.custom_minimum_size = Vector2(320,0)
					column.add_theme_constant_override("separation",6)
					column.add_child(heading(act["title"]))
					var summary := label(act["summary"],16,MUTED)
					summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					column.add_child(summary)
					for card in act["cards"]:
						var tint: Color = {"playable":Color("2f6b57"),"next":Color("304965")}.get(card["status"],Color("22312a"))
						var box := panel(tint)
						box.tooltip_text = card["brief"]
						box.mouse_filter = Control.MOUSE_FILTER_PASS
						var lines := VBoxContainer.new()
						lines.add_theme_constant_override("separation",2)
						lines.add_child(label(card["title"],19,Color.WHITE if card["status"] != "planned" else MUTED))
						lines.add_child(label(card["state"],15,GOLD if card["status"] != "planned" else Color("7c8782")))
						box.add_child(lines)
						column.add_child(box)
					row.add_child(column)
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
	if show_operations: return operations_content()
	if start_menu: return start_content()
	if should_brief(): return briefing_content()
	if confirm_new: return new_game_content()
	if board.has_meta("hud_help"): return help_content()
	if board.roster_open: return roster_content()
	if board.scene_view != "": return story_content()
	if board.result_ready: return results_content()
	if board.isolate_pending: return breaker_content()
	return {}

func should_brief() -> bool:
	if is_river() or is_main() or is_interchange() or is_rail() or is_hospital() or is_quarry() or is_airfield() or is_civic(): return not board.has_meta("hud_briefed") and board.scene_view == "" and not board.result_ready and board.phase == 1
	return not board.has_meta("hud_briefed") and board.scene_view == "" and not board.roster_open and not board.result_ready and board.phase == 1 and machine_threat_active()

func briefing_content() -> Dictionary:
	if is_civic():
		var brief: Dictionary = Arc.mission(9)["briefing"]
		var lines: Array = [["heading","ACT III · THE ENEMY OF MY ENEMY"],["title","MISSION 09: CIVIC CENTER"]]
		for key in ["objective","intel","risks","choice","delay"]:
			lines.append(["text","%s:  %s" % [{"objective":"Objective","intel":"Intel","risks":"Known risks","choice":"The choice","delay":"If it goes wrong"}[key],brief[key]],22])
		var carry: Array[String] = []
		if board.files: carry.append("The Hospital harvest files give you the service door code and the concealed hatch: both open from the start.")
		if board.leaked: carry.append("The Hospital infiltrator reached your base: your movements leaked, and the alarm comes at round 3.")
		if not board.hospital_taken.is_empty(): carry.append("County Hospital group %s is among the detainees." % ", ".join(board.hospital_taken))
		if board.aven_charge: carry.append("Aven has a charge left: she can shield the convoy once.")
		if not carry.is_empty(): lines.append(["text","From earlier missions:  " + " ".join(carry),21,GOLD])
		lines.append(["heading","HOW IT PLAYS"])
		lines.append(["text","1. Troopers inside are hidden until a soldier is within 3, or Park scouts (1 AP, reveals within 6, including the concealed hatch). Seen troopers leave a ? where they were last seen.\n2. The west service door (5,7) gets you inside past the main entrance.\n3. The alarm (round %d, or a shot inside, the pen, or the terminal) splits the garrison: extraction troopers move the detainees out; territorial troopers dig in, aim a turn ahead and shoot cover away.\n4. The mortar marks a 3×3 impact a phase ahead; once the convoy leaves, it shells the convoy. Kill the spotter on the annex roof (stairs at 17,6).\n5. The convoy takes the council: it leaves when they reach the gate, or at round %d." % [board.garrison["alarm_round"],board.CONVOY_LEAVES],22])
		lines.append(["row",[["Got it",func(): board.set_meta("hud_briefed",true)]]])
		return {"items":lines}
	if is_airfield():
		var brief: Dictionary = Arc.mission(8)["briefing"]
		var lines: Array = [["heading","ACT III · THE ENEMY OF MY ENEMY"],["title","MISSION 08: REGIONAL AIRFIELD"]]
		for key in ["objective","intel","risks","choice","delay"]:
			lines.append(["text","%s:  %s" % [{"objective":"Objective","intel":"Intel","risks":"Known risks","choice":"The choice","delay":"If it goes wrong"}[key],brief[key]],22])
		var carry: Array[String] = []
		if board.river_shield: carry.append("The craft may be the one that shielded your column at River Bridge: it has 1 protection charge left, not 2.")
		if board.intel_line: carry.append("The full Rail Yard archive opens a Grey channel: one stated bargain in round 3.")
		if board.pod["active"]: carry.append("%s is in a Grey pod on the apron." % board.pod["origin"].replace(" (in Grey custody)",""))
		carry.append("%s holds the terminal (%d standing)." % [board.team["name"],Team.standing(board.team)])
		lines.append(["text","From earlier missions:  " + " ".join(carry),21,GOLD])
		lines.append(["heading","HOW IT PLAYS"])
		lines.append(["text","1. MSG at the hangar 2 hatch (15,3): Contact the craft by round 6. Then he can ask for a Nordic shield over the selected group (3×3; each one spends a charge), and anyone at the hatch can download the sensor data (2 steps).\n2. The Grey Collector strips the plane's engines one at a time; hit it to break a strip. Sentries fire only once you interfere.\n3. The Fallow mark ground a turn before it turns to rift. Two rift squares on the runway ruin it.\n4. Your supporting team takes one order a turn.",22])
		lines.append(["row",[["Got it",func(): board.set_meta("hud_briefed",true)]]])
		return {"items":lines}
	if is_quarry():
		var brief: Dictionary = Arc.mission(7)["briefing"]
		var lines: Array = [["heading","ACT II · THE HIDDEN WAR"],["title","MISSION 07: QUARRY"]]
		for key in ["objective","intel","risks","choice","delay"]:
			lines.append(["text","%s:  %s" % [{"objective":"Objective","intel":"Intel","risks":"Known risks","choice":"The choice","delay":"If it goes wrong"}[key],brief[key]],22])
		var carry: Array[String] = []
		carry.append("The Drive Rig is here (you preserved the Farm Road machine)." if board.rig_available else "No Drive Rig: the Farm Road machine wasn't preserved.")
		if board.missing_part: carry.append("The Interchange cargo you seized was this platform's part: controller recovery takes 4 steps.")
		if board.hatch_open: carry.append("The Drovers opened a maintenance hatch (7,13) on the long route: you kept their convoy's route at the hospital.")
		if board.surveyed: carry.append("Rail Yard surveys show the loose debris: digging is 1 AP a square.")
		lines.append(["text","From earlier missions:  " + " ".join(carry),21,GOLD])
		lines.append(["heading","HOW IT PLAYS"])
		lines.append(["text","1. Demolish: Set charge next to the platform (2 AP); it blows next phase and clears the west mouth.\n2. Isolate: Kill junction box West (6,11) and East (17,10), then Confirm safe-off at the platform. Then dig the 3 debris squares.\n3. Controller: Recover controller at the platform, one step a round. The mouth stays live, so the tunnel groups go out the airshaft (11,13).\n4. The upper bench is high ground: +10 shooting down, −10 shooting up.\n5. The Fallow come over the ridge in round 4. Ground next to a braced rig is safe from their marks.",22])
		lines.append(["row",[["Got it",func(): board.set_meta("hud_briefed",true)]]])
		return {"items":lines}
	if is_hospital():
		var brief: Dictionary = Arc.mission(6)["briefing"]
		var lines: Array = [["heading","ACT II · THE HIDDEN WAR"],["title","MISSION 06: COUNTY HOSPITAL"]]
		for key in ["objective","intel","risks","choice","delay"]:
			lines.append(["text","%s:  %s" % [{"objective":"Objective","intel":"Intel","risks":"Known risks","choice":"The choice","delay":"If it goes wrong"}[key],brief[key]],22])
		var carry: Array[String] = []
		if board.rail_cells: carry.append("Rail Yard generator cells: +1 power system.")
		if board.field_contact: carry.append("Kesh is your field contact: you can negotiate the convoy (monitored passage gives +1 power).")
		else: carry.append("No Drover field contact: the convoy will come through regardless.")
		lines.append(["text","From earlier missions:  " + " ".join(carry),21,GOLD])
		lines.append(["heading","HOW IT PLAYS"])
		lines.append(["text","1. MSG assigns power at the generator room (2,8). The ambulance won't run without its charger.\n2. Ambulance: a soldier at the bay loads the selected group next to it (1 AP). One group a trip, about two trips. Group C (gurneys) walks 1 square a turn.\n3. Screening at the triage tent (12,6): check credentials, scan if powered, and watch the north gate in round 3. Two discrepancies confirm. Detain is 1 AP next to the group, and a wrong call is recorded.\n4. Reptilians take a group they end their move next to. Their sonic cone is marked a turn ahead.\n5. Guard Team Marsh takes one order a turn: hold by a soldier, protect the selected group, or withdraw.",22])
		lines.append(["row",[["Got it",func(): board.set_meta("hud_briefed",true)]]])
		return {"items":lines}
	if is_rail():
		var brief: Dictionary = Arc.mission(5)["briefing"]
		var lines: Array = [["heading","ACT II · THE HIDDEN WAR"],["title","MISSION 05: RAIL YARD"]]
		for key in ["objective","intel","risks","choice","delay"]:
			lines.append(["text","%s:  %s" % [{"objective":"Objective","intel":"Intel","risks":"Known risks","choice":"The choice","delay":"If it goes wrong"}[key],brief[key]],22])
		var carry: Array[String] = []
		if not board.river_taken.is_empty(): carry.append("River Bridge group %s is in the pens." % ", ".join(board.river_taken))
		if board.drone_evidence: carry.append("Bell knows the Grey data format from the Interchange drone: the archive is a 1-step download.")
		if not carry.is_empty(): lines.append(["text","From earlier missions:  " + " ".join(carry),21,GOLD])
		lines.append(["heading","HOW IT PLAYS"])
		lines.append(["text","1. Pens: Bell bypasses a lock (1 AP, not in a blackout); anyone cuts one (2 AP, works in a blackout). Freed groups come out shaken.\n2. The Collector marks a pen in rounds 3, 5 and 7 and takes it the round after. Open that pen or hit the Collector.\n3. Violet squares go dark next round: no radio (MSG only reaches adjacent groups), no bypass, no download.\n4. The archive (%d step%s) is by the transport; the handcar rolls itself west once its brake is off.\n5. Shooting a Grey, opening a pen, the terminal, or a soldier within 3 of the transport turns the Sentries." % [board.archive["needed"],"" if board.archive["needed"] == 1 else "s"],22])
		lines.append(["row",[["Got it",func(): board.set_meta("hud_briefed",true)]]])
		return {"items":lines}
	if is_interchange():
		var brief: Dictionary = Arc.mission(4)["briefing"]
		var lines: Array = [["heading","ACT II · THE HIDDEN WAR"],["title","MISSION 04: INTERCHANGE"]]
		for key in ["objective","intel","risks","choice","delay"]:
			lines.append(["text","%s:  %s" % [{"objective":"Objective","intel":"Intel","risks":"Known risks","choice":"The choice","delay":"If it goes wrong"}[key],brief[key]],22])
		var carry: Array[String] = []
		if board.acknowledged: carry.append("ACK-01 on record: they'll take a pause request straight away.")
		if board.wary: carry.append("You preserved the Main Street platform: the crew is wary, and answers its first provocation with a warning shot.")
		if board.component_held: carry.append("You have the Main Street component: hand it back with the request for a 5-round pause.")
		if board.sensor: carry.append("The River Bridge sensor shows the Grey drone from the moment it arrives.")
		if not carry.is_empty(): lines.append(["text","From earlier missions:  " + " ".join(carry),21,GOLD])
		lines.append(["heading","HOW IT PLAYS"])
		lines.append(["text","1. Civilians won't walk into the armed work zone (columns 9–13, barrier to barrier). A soldier who gets within 2 of the hauler without a pause provokes security.\n2. PAUSE: MSG within %d of the hauler transmits (1 AP). It starts in their next phase and lasts %d rounds; groups cross, soldiers keep to the green lane.\n3. ESCORT: group C is on the overpass. The east end collapsed, so the only way down is the west ramp (6,4).\n4. ASSAULT: Suppress (1 AP, 2 rounds of ammo) gives a target −20 Aim; Restrain takes a suppressed Drover at %d HP or less alive.\n5. Watch the south. Something grey is watching the crew." % [Crew.VOICE_RANGE,Crew.PAUSE_ROUNDS,Crew.RESTRAIN_HP],22])
		lines.append(["row",[["Got it",func(): board.set_meta("hud_briefed",true)]]])
		return {"items":lines}
	if is_main():
		var brief: Dictionary = Arc.mission(3)["briefing"]
		var lines: Array = [["heading","ACT I · THE BREAKING OF SILENCE"],["title","MISSION 03: MAIN STREET"]]
		for key in ["objective","intel","risks","choice","delay"]:
			lines.append(["text","%s:  %s" % [{"objective":"Objective","intel":"Intel","risks":"Known risks","choice":"The choice","delay":"If it goes wrong"}[key],brief[key]],22])
		lines.append(["heading","HOW IT PLAYS"])
		lines.append(["text","1. The platform (%d HP) grinds down Main Street toward the substation. Shoot it, cut power at the junction box JB (%d,%d), or redirect it through the control panel CP (%d,%d) like the Farm Road console.\n2. Drover security walks beside it. It isn't a target.\n3. Watch the north-east end of the alley. Whatever comes through marks ground in violet, and next turn that ground turns to rift: impassable, and 4 damage to anyone standing on it. A soldier next to its node can Interrupt (1 AP) to buy a turn.\n4. Main Street is fast; the north alley is the way round when the street gets cut." % [board.mission_definition().machine_hp,board.BREAKER_CELL.x,board.BREAKER_CELL.y,board.CONSOLE_CELL.x,board.CONSOLE_CELL.y],22])
		lines.append(["row",[["Got it",func(): board.set_meta("hud_briefed",true)]]])
		return {"items":lines}
	if is_river():
		var briefing: Dictionary = Arc.mission(2)["briefing"]
		var items: Array = [["heading","ACT I · THE BREAKING OF SILENCE"],["title","MISSION 02: RIVER BRIDGE"]]
		for key in ["objective","intel","risks","choice","delay"]:
			items.append(["text","%s:  %s" % [{"objective":"Objective","intel":"Intel","risks":"Known risks","choice":"The choice","delay":"If it goes wrong"}[key],briefing[key]],22])
		items.append(["heading","HOW IT PLAYS"])
		items.append(["text","1. A soldier at the checkpoint (8,8) sets the bridge lanes (1 AP). Until then, nobody crosses.\n2. The Collector marks a group with LIFT 2. Once it's locked on, only hitting the Collector or getting the group into the barn breaks it.\n3. The Sentry leaves you alone until you shoot a Grey or crowd the Collector. Then it aims a beam: move off the red line.\n4. Optional: recover the sensor in the reeds (6,14). The Greys leave after round %d; dusk closes the crossing after round %d." % [Greys.WITHDRAW_ROUND,board.deadline()],22])
		items.append(["row",[["Got it",func(): board.set_meta("hud_briefed",true)]]])
		return {"items":items}
	return {"items":[["heading","ACT I · THE BREAKING OF SILENCE"],["title","MISSION 01: FARM ROAD"],
		["text","You have two jobs, and they pull against each other.",25,GOLD],
		["heading","1.  STOP THE MACHINE (first)"],
		["text","The machine heads for its cargo. When it gets there (round %d), the road closes the next round. Shoot it, cut its power at breaker B (9,4), or divert it at console C (11,12). The red box at the top right counts down and lists how." % cargo_round(),23],
		["heading","2.  HERD THE CIVILIANS"],
		["text","12 civilians in groups A, B and C. MSG is your PSYOP NCO: he can order any group within %d squares for free (the gold outline on the map). Other soldiers can order a group within %d squares for 1 AP. Orders stick, and groups walk when you end the turn.\nCrowds scare easily. The machine or gunfire within %d squares makes a group SHAKEN (slower), then PANICKED (they ignore orders and run). Keep MSG within %d squares to hold them steady, and use Calm to talk them down." % [Command.VOICE_RANGE,Command.NEAR_RANGE,Command.THREAT_RANGE,Command.STEADY_RANGE],23],
		["heading","3.  GET YOUR SQUAD OUT"],
		["text","Move soldiers onto an EXIT square and press Extract [E]. MSG must get out.",23],
		["row",[["Got it",func(): board.set_meta("hud_briefed",true)]]]]}

func open_operations() -> void:
	show_operations = true
	dirty = true

func close_operations() -> void:
	show_operations = false

func noop() -> void:
	pass

func replay_farm_road() -> void:
	show_operations = false
	start_new()

## The campaign at a glance: four acts, seventeen missions, what Farm Road left behind.
func operations_content() -> Dictionary:
	var record := Record.load_record(campaign_record_path)
	var entry: Dictionary = record["missions"].get(1,{})
	var river: Dictionary = record["missions"].get(2,{})
	var main: Dictionary = record["missions"].get(3,{})
	var junction: Dictionary = record["missions"].get(4,{})
	var rail_entry: Dictionary = record["missions"].get(5,{})
	var hospital_entry: Dictionary = record["missions"].get(6,{})
	var quarry_entry: Dictionary = record["missions"].get(7,{})
	var airfield_entry: Dictionary = record["missions"].get(8,{})
	var civic_entry: Dictionary = record["missions"].get(9,{})
	var acts: Array = []
	for act_index in range(Arc.ACTS.size()):
		var act: Dictionary = Arc.ACTS[act_index]
		var cards: Array = []
		for mission in Arc.MISSIONS:
			if mission["act"] != act_index: continue
			var state := ""
			match mission["status"]:
				"playable":
					var done: Dictionary = record["missions"].get(mission["id"],{})
					var detail := ""
					if not done.is_empty():
						match mission["id"]:
							1: detail = "machine %s" % done["machine"]
							2: detail = "%d taken" % (done["taken"].size()*4) if not done["taken"].is_empty() else "supplies %s" % done["supplies"]
							3: detail = "platform %s" % done.get("platform","?")
							4: detail = "agreement %s" % str(done.get("agreement","?")).replace("_"," ")
							5: detail = "%d aboard · archive %s" % [done.get("aboard",[]).size()*4,done.get("archive","none")]
							6: detail = "infiltrator %s" % str(done.get("infiltrator","?")).replace("_"," ")
							7: detail = "habitat %s" % done.get("habitat","?")
							8: detail = "contact %s" % ("made" if done.get("contact",false) else "missed")
							_: detail = "records %s" % ("taken" if done.get("records",false) else "lost")
					state = ("PLAYED · %d/12 out · %s" % [done["evacuated"],detail] if not done.is_empty() and not done["retry_required"] else ("RETRY NEEDED" if not done.is_empty() else "PLAY NOW"))
				"next": state = "NEXT · in development"
				_: state = "planned"
			cards.append({"title":"%02d  %s" % [mission["id"],mission["title"]],"state":state,"status":mission["status"],"brief":mission["brief"]})
		var complete := (act_index == 0 and Record.act_one_complete(record)) or (act_index == 1 and Record.act_two_complete(record))
		acts.append({"title":"ACT %s · %s%s" % [act["number"],act["title"].to_upper(),"  ·  COMPLETE" if complete else ""],"summary":act["summary"],"cards":cards})
	var next: Dictionary = Arc.mission(9)
	var briefing: Dictionary = next["briefing"]
	var items: Array = [["title","OPERATIONS BOARD · TASK FORCE ALDER"],
		["text","Earth may be lost, but humanity does not have to be. Seventeen missions across four acts; Farm Road is where it starts, and where it ends.",21,MUTED],
		["acts",acts],
		["heading","WHAT THE TASK FORCE KNOWS"]]
	for line in Record.knowledge(entry): items.append(["text",line,20,TEXT])
	if not main.is_empty():
		items.append(["text","OBSERVED: on Main Street a new threat marked ground and transformed it a turn later. It didn't negotiate and answered to neither the machines nor the Greys.",20,TEXT])
	if Record.act_one_complete(record):
		items.append(["text","ASSESSMENT, accepted locally: these are not one invasion. Ward wants independent corroboration.",20,GOLD])
	items.append(["heading","WHAT FARM ROAD CARRIES FORWARD"])
	if not river.is_empty():
		items.append(["text","OBSERVED: at River Bridge the Greys went for people, not ground; the Farm Road machine went around them. Two different patterns.",20,TEXT])
	items.append(["heading","WHAT CARRIES FORWARD"])
	for line in Record.carry_forward(entry): items.append(["text","•  "+line,20,GOLD])
	for line in Record.carry_forward_river(river): items.append(["text","•  "+line,20,GOLD])
	for line in Record.carry_forward_main(main): items.append(["text","•  "+line,20,GOLD])
	for line in Record.carry_forward_interchange(junction): items.append(["text","•  "+line,20,GOLD])
	for line in Record.carry_forward_rail(rail_entry): items.append(["text","•  "+line,20,GOLD])
	for line in Record.carry_forward_hospital(hospital_entry): items.append(["text","•  "+line,20,GOLD])
	for line in Record.carry_forward_quarry(quarry_entry): items.append(["text","•  "+line,20,GOLD])
	for line in Record.carry_forward_airfield(airfield_entry): items.append(["text","•  "+line,20,GOLD])
	for line in Record.carry_forward_civic(civic_entry): items.append(["text","•  "+line,20,GOLD])
	items.append(["heading","MISSION 09 · CIVIC CENTER  (playable)"])
	for key in ["objective","intel","risks","choice","delay"]:
		items.append(["text","%s:  %s" % [{"objective":"Objective","intel":"Intel","risks":"Known risks","choice":"The choice","delay":"If it goes wrong"}[key],briefing[key]],20,TEXT])
	items.append(["row",[["Back",close_operations],["Play 01: Farm Road",replay_farm_road],["Play 02: River Bridge",play_river_bridge],["Play 03: Main Street",play_main_street],["Play 04: Interchange",play_interchange],["Play 05: Rail Yard",play_rail_yard]]])
	items.append(["row",[["Play 06: County Hospital",play_county_hospital],["Play 07: Quarry",play_quarry],["Play 08: Regional Airfield",play_airfield],["Play 09: Civic Center",play_civic]]])
	return {"items":items}

func play_river_bridge() -> void:
	launch(RiverScene)

func play_main_street() -> void:
	launch(MainScene)

func play_interchange() -> void:
	launch(InterchangeScene)

func play_rail_yard() -> void:
	launch(RailScene)

func play_county_hospital() -> void:
	launch(HospitalScene)

func play_quarry() -> void:
	launch(QuarryScene)

func play_airfield() -> void:
	launch(AirfieldScene)

func play_civic() -> void:
	launch(CivicScene)

func launch(scene: PackedScene) -> void:
	show_operations = false
	start_menu = false
	if valid_board(): board.queue_free()
	board = null
	var fresh = scene.instantiate()
	fresh.auto_resume = false
	fresh.record_path = campaign_record_path
	holder.add_child(fresh)
	modal_signature = ""
	dirty = true

func is_river() -> bool:
	return valid_board() and board.has_method("set_lanes")

func is_main() -> bool:
	return valid_board() and board.has_method("interrupt_node")

func is_interchange() -> bool:
	return valid_board() and board.has_method("transmit_pause")

func is_rail() -> bool:
	return valid_board() and board.has_method("bypass_lock")

func is_hospital() -> bool:
	return valid_board() and board.has_method("load_ambulance")

func is_quarry() -> bool:
	return valid_board() and board.has_method("confirm_safe_off")

func is_airfield() -> bool:
	return valid_board() and board.has_method("make_contact")

func is_civic() -> bool:
	return valid_board() and board.has_method("download_records")

func mission_number() -> int:
	if is_civic(): return 9
	if is_airfield(): return 8
	if is_quarry(): return 7
	if is_hospital(): return 6
	if is_rail(): return 5
	if is_interchange(): return 4
	return 3 if is_main() else (2 if is_river() else 1)

func start_content() -> Dictionary:
	var where := "Return to Farm Road (deployment %d)" % board.campaign.get("deployment",2) if board.return_state["active"] else "Farm Road"
	var machine := "machine destroyed — no enemy on this map" if not board.machine_present() else "machine still active"
	return {"items":[["title","HOLDFAST"],
		["text","Saved game found: %s, round %d, %d / 12 civilians evacuated, %s." % [where,board.phase,board.evacuated_people(),machine],24],
		["option","New game  —  Farm Road, deployment 1, machine active (old save kept as a backup)",start_new],
		["option","Continue saved game",continue_saved],
		["option","Operations board  —  the campaign so far",open_operations]]}

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
		for file in ["holdfast_d1_campaign.save","holdfast_c2_campaign.save","holdfast_d1.save","holdfast_campaign_record.save"]:
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
		["text","Civilians: MSG orders any group inside the gold outline for free; other soldiers order groups within 2 squares for 1 AP. Calm (C) settles a scared group.",22],
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
	var opening_choice: bool = board.scene_view == "opening" and board.scene_page == 0 and not board.scene_options().is_empty()
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
		["Roster / service history  [G]",func(): board.open_roster()],
		["Operations board",open_operations]]
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
