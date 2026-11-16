extends RefCounted
## Applies already validated state in dependency order; adapters own the live values.
static func apply(snapshot: Dictionary, adapters: Dictionary) -> void:
	for section in ["extra","rescue","protocol","breaker","evac","machine","tactical"]:
		if adapters.has(section): adapters[section].call(snapshot)
