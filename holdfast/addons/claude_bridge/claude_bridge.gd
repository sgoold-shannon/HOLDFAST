@tool
extends EditorPlugin
## Starts the HOLDFAST bridge next to the project folder when the editor opens.
## Does nothing on machines without "Claude Bridge.command" beside the project.
func _enter_tree() -> void:
	var bridge := ProjectSettings.globalize_path("res://").path_join("../Claude Bridge.command").simplify_path()
	if not FileAccess.file_exists(bridge): return
	var command := "pgrep -f 'Claude Bridge.command' >/dev/null || nohup '%s' >/dev/null 2>&1 &" % bridge
	OS.create_process("/bin/bash",["-c",command])
