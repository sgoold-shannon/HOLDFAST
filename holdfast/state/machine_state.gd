extends RefCounted
## Machine route, isolation and communication state; no scene or UI references.
var machine := {"stage": 0, "hostile": false, "pending_shot": Vector2i(-1, -1), "collected_round": 0, "departed": false}
var breaker_progress := 0
var protocol := {"observed": false, "acknowledged": false, "pause_pending": false,
	"pause_used": false, "authenticated": false, "route_set": false,
	"diverted": false, "waypoint": 0, "component_collected": false, "betrayed": false}
func snapshot() -> Dictionary:
	return {"machine":machine.duplicate(true),"breaker":breaker_progress,"protocol":protocol.duplicate(true)}
func restore_machine(data: Dictionary) -> void:
	machine = data.duplicate(true)
func restore_protocol(data: Dictionary) -> void:
	protocol = data.duplicate(true)
