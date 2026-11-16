extends RefCounted
## Explicit current-encounter schema; dictionary order preserves existing binary snapshots.
static func assemble(layout: String, sections: Dictionary) -> Dictionary:
	return {"layout":layout,"combat":sections["combat"].duplicate(true),
		"ui":sections["ui"].duplicate(true),"machine":sections["machine"].duplicate(true),
		"evac":sections["evac"].duplicate(true),"breaker":sections["breaker"],
		"protocol":sections["protocol"].duplicate(true),"rescue_target":sections["rescue_target"],
		"rescue_events":sections["rescue_events"].duplicate(true),"story":sections["story"].duplicate(true),
		"campaign":sections["campaign"].duplicate(true),"return_map":sections["return_map"].duplicate(true)}

static func restore_extras(snapshot: Dictionary, adapters: Dictionary) -> void:
	# Return-map policy must be present before any other restored state is interpreted.
	for section in ["return_map","results","story","campaign"]:
		adapters[section].call(snapshot)
