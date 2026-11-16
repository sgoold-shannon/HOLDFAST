extends RefCounted
## Translate interface events into intent; never execute gameplay or consume modal input.
const KEYS := {KEY_K:"save",KEY_L:"load",KEY_E:"extract",KEY_F:"fire",
	KEY_R:"reload",KEY_T:"mode",KEY_N:"next",KEY_ESCAPE:"clear"}
static func key_command(event: InputEvent) -> String:
	if event is InputEventKey and event.pressed and not event.echo:
		return KEYS.get(event.keycode,"")
	return ""

static func button_command(point: Vector2, buttons: Dictionary) -> String:
	for command in buttons:
		if buttons[command].has_point(point): return command
	return ""
