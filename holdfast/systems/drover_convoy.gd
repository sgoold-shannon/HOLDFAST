extends RefCounted
## Drover convoy (County Hospital). With Interchange field contact the MSG chooses a monitored
## passage (road closed two rounds, coupling spliced in afterwards) or reserves the road for
## humans (they divert). Without contact they come through regardless. State: board.convoy.
const ARRIVE_ROUND := 4          # on the map from this round (arrives in the round-3 phase)
const PASS_FROM := 5
const PASS_TO := 6
const SHOVE_DAMAGE := 2
const NONE := Vector2i(-1,-1)

static func initial(contact: bool) -> Dictionary:
	return {"stage":"waiting","contact":contact,"choice":"none","log":[]}

static func passing(convoy: Dictionary) -> bool:
	return convoy["stage"] == "passing"

static func choose(convoy: Dictionary, choice: String) -> String:
	if convoy["stage"] != "arrived": return "The convoy isn't waiting for an answer."
	if not convoy["contact"]: return "Without field contact there's nobody on their side to agree with."
	if convoy["choice"] != "none": return "Already answered: " + convoy["choice"]
	convoy["choice"] = choice
	convoy["log"].append("choice:%s" % choice)
	return "Monitored passage agreed: rounds %d–%d, one soldier watching. They'll splice a power coupling in afterwards." % [PASS_FROM,PASS_TO] if choice == "monitored" else "Road reserved for people. The convoy will divert north. Kesh notes it."

## The Drover phase.
static func act(convoy: Dictionary, board) -> String:
	var phase: int = board.phase
	match convoy["stage"]:
		"waiting":
			if phase < ARRIVE_ROUND-1: return ""
			convoy["stage"] = "arrived"
			return "A Drover convoy pulls up at the east end of the road%s." % (". Kesh is on the channel: they need the road for two rounds" if convoy["contact"] else ". Nobody answers on their channel")
		"arrived":
			if phase < PASS_FROM-1: return ""
			if convoy["choice"] == "reserved":
				convoy["stage"] = "diverted"
				return "The convoy turns north and goes round. The road stays yours."
			if convoy["choice"] == "none": convoy["choice"] = "contested"
			convoy["stage"] = "passing"
			var shoved: String = board.shove_off_road(SHOVE_DAMAGE) if convoy["choice"] == "contested" else ""
			return ("The convoy rolls onto the road under watch." if convoy["choice"] == "monitored" else "The convoy pushes onto the road without stopping.") + ("" if shoved == "" else " " + shoved)
		"passing":
			if phase < PASS_TO: return ""
			convoy["stage"] = "gone"
			if convoy["choice"] == "monitored":
				board.power["coupling"] = 1
				convoy["log"].append("coupling")
				return "The convoy clears the road. Their crew splices a power coupling into the hospital panel: one more system."
			return "The convoy clears the road and is gone."
	return ""
