extends Node
## Presentation-only magnifier. All game hit tests already invert the canvas transform.
const PAGE := Vector2(1144, 1224)
var magnification := 3.0
var origin := Vector2.ZERO
var camera: Camera2D
var caption: Label

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_top = -64
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
	magnification = value
	origin = Vector2.ZERO
	_apply()

func _apply() -> void:
	if not is_instance_valid(camera):
		return
	var view := get_viewport().get_visible_rect().size
	var visible := Vector2(view.x, view.y - 64) / magnification
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
