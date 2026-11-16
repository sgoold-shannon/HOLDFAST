extends RefCounted
## Completion policy reads mission data and live facts; it never changes the encounter.
static func deadline(mission: Resource, collected_round: int) -> int:
	if mission.collection_shortens_deadline and collected_round > 0:
		return mini(mission.closing_round, collected_round+1)
	return mission.closing_round

static func completion_reason(mission: Resource, phase: int, collected_round: int,
		squad_out: bool, remaining_civilians: int) -> String:
	# Deadline takes priority when both conditions become true during the final civilian phase.
	if phase >= deadline(mission,collected_round): return mission.closure_reason
	if squad_out and remaining_civilians == 0: return mission.evacuation_reason
	return ""

static func squad_exit(mission: Resource, cell: Vector2i) -> bool:
	return mission.squad_exits.has(cell)
