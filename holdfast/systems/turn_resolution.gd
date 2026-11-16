extends RefCounted
## Explicit phase sequence. Hooks contain mission policies, not a scene dependency.
## after_turn runs even on a halted turn, preserving result finalization/knowledge hooks.
static func resolve(phase: int, hooks: Dictionary) -> void:
	if not hooks["ended"].call():
		if hooks["before_machine"].call():
			hooks["prepare_machine"].call()
			hooks["machine"].call()
			if not hooks["ended"].call():
				hooks["civilians"].call()
				var reason: String = hooks["completion"].call(phase)
				if reason != "":
					hooks["finish"].call(reason)
				else:
					hooks["begin_player"].call()
	hooks["after_turn"].call()
