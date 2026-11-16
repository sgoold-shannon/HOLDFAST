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
				if phase >= hooks["deadline"].call():
					hooks["finish"].call("Road closed")
				elif hooks["squad_out"].call() and hooks["remaining_civilians"].call() == 0:
					hooks["finish"].call("Evacuation resolved")
				else:
					hooks["begin_player"].call()
	hooks["after_turn"].call()
