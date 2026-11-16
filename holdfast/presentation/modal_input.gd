extends RefCounted
## Translate a modal event into an intent. The controller retains visibility and precedence.
static func command(event: InputEvent, local_point: Vector2, keys: Dictionary, buttons: Dictionary, rows: Array = []) -> String:
	if event is InputEventKey and event.pressed and not event.echo:
		return keys.get(event.keycode,"")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for action in buttons:
			if buttons[action].has_point(local_point): return action
		for index in range(rows.size()):
			if rows[index].has_point(local_point): return "row:%d" % index
	return ""
