extends Node
## Presentation-only magnifier. All game hit tests already invert the canvas transform.
const PAGE := Vector2(1144, 1224)
const TOOLBAR_HEIGHT := 64.0
var preview_open := false
var fit_enabled := false
var toolbar: PanelContainer
var magnification := 3.0
var origin := Vector2.ZERO
var camera: Camera2D
var caption: Label

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var preview_button := Button.new()
	preview_button.text = "3D Preview"
	preview_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	preview_button.offset_left = -180
	preview_button.offset_right = -16
	preview_button.offset_top = 12
	preview_button.offset_bottom = 58
	preview_button.add_theme_font_size_override("font_size",22)
	preview_button.focus_mode = Control.FOCUS_NONE
	preview_button.pressed.connect(open_preview)
	layer.add_child(preview_button)
	var art_button := Button.new()
	art_button.text = "Visual benchmark"
	art_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	art_button.offset_left = -400
	art_button.offset_right = -190
	art_button.offset_top = 12
	art_button.offset_bottom = 58
	art_button.add_theme_font_size_override("font_size",20)
	art_button.pressed.connect(open_benchmark)
	layer.add_child(art_button)
	var panel := PanelContainer.new()
	toolbar = panel
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -TOOLBAR_HEIGHT
	layer.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	caption = Label.new()
	caption.add_theme_font_size_override("font_size", 24)
	row.add_child(caption)
	for entry in [["Fit", 1.0], ["2×", 2.0], ["3×", 3.0]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(85, 60)
		button.add_theme_font_size_override("font_size", 26)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_set_zoom.bind(float(entry[1])))
		row.add_child(button)
	var hint := Label.new()
	hint.text = "Scroll to pan • Shift: sideways • Home: top"
	hint.add_theme_font_size_override("font_size", 22)
	row.add_child(hint)

func _process(_delta: float) -> void:
	var active := get_viewport().get_camera_2d()
	if active != camera:
		camera = active
		origin = Vector2.ZERO
	_apply()

func _set_zoom(value: float) -> void:
	fit_enabled = is_equal_approx(value,1.0)
	magnification = value
	origin = Vector2.ZERO
	_apply()

func _apply() -> void:
	if not is_instance_valid(camera):
		return
	var view := get_viewport().get_visible_rect().size
	var toolbar_height := maxf(TOOLBAR_HEIGHT,toolbar.size.y)
	var available := Vector2(view.x,maxf(1.0,view.y-toolbar_height))
	if fit_enabled:
		magnification = minf(available.x/PAGE.x,available.y/PAGE.y)
	var visible := available / magnification
	origin = origin.clamp(Vector2.ZERO, (PAGE - visible).max(Vector2.ZERO))
	camera.zoom = Vector2.ONE * magnification
	camera.position = origin + view / (2.0 * magnification)
	camera.force_update_scroll()
	caption.text = " View %d%% " % int(magnification * 100)

func _input(event: InputEvent) -> void:
	var pan := Vector2.ZERO
	if event is InputEventPanGesture:
		pan = event.delta * 32.0 / magnification
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: pan.y = -80.0 * event.factor
			MOUSE_BUTTON_WHEEL_DOWN: pan.y = 80.0 * event.factor
			MOUSE_BUTTON_WHEEL_LEFT: pan.x = -80.0 * event.factor
			MOUSE_BUTTON_WHEEL_RIGHT: pan.x = 80.0 * event.factor
		if event.shift_pressed:
			pan = Vector2(pan.y, pan.x)
		pan /= magnification
	elif event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		origin = Vector2.ZERO
		_apply()
		get_viewport().set_input_as_handled()
		return
	if pan != Vector2.ZERO:
		origin += pan
		_apply()
		get_viewport().set_input_as_handled()

func open_preview() -> void:
	open_visual("res://map_preview_3d.tscn")

func open_benchmark() -> void:
	open_visual("res://visual_benchmark.tscn")

func open_visual(scene_path: String) -> void:
	if preview_open: return
	var board := get_tree().current_scene
	if not board is Node2D: return
	var preview = load(scene_path).instantiate()
	var previous_mode := board.process_mode
	var was_visible: bool = board.visible
	preview_open = true
	board.hide()
	board.process_mode = Node.PROCESS_MODE_DISABLED
	preview.tree_exited.connect(func():
		preview_open = false
		if is_instance_valid(board):
			board.process_mode = previous_mode
			board.visible = was_visible)
	get_tree().root.add_child(preview)
