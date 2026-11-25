extends RefCounted
## Evidence-based screening (County Hospital). GDD v3.1 §20/§26: disguise is a bounded
## infiltration tool; two corroborating discrepancies and a nonlethal containment path;
## suspicion is not a confirmed target, and false accusations have real consequences.
## State is one plain dictionary on the board (board.screening).
const ACT_ROUND := 3           # the infiltrator goes to the fence gate in this round's phase
const CONFIRM := 2             # corroborating discrepancies needed to confirm
const PEOPLE := [
	{"name":"R. Vance","role":"orderly"},
	{"name":"Dr. E. Hale","role":"staff physician"},
	{"name":"T. Moreno","role":"patient's husband"}]

## One person of interest per group. `infiltrator` is the group index of the disguised one;
## the next group's person has an innocent credential problem; the third is clean.
static func initial(infiltrator: int) -> Dictionary:
	var people: Array = []
	for index in range(PEOPLE.size()):
		people.append({"name":PEOPLE[index]["name"],"role":PEOPLE[index]["role"],"group":index,
			"credentials":"unchecked","behavior":false,"scanner":"unscanned","status":"with group"})
	return {"infiltrator":infiltrator,"innocent_badge":(infiltrator+1) % PEOPLE.size(),"people":people,
		"acted":false,"witnessed":false,"false_detentions":[],"log":[]}

static func discrepancies(screening: Dictionary, index: int) -> int:
	var person: Dictionary = screening["people"][index]
	var count := 0
	if person["credentials"] == "discrepancy": count += 1
	if person["behavior"]: count += 1
	if person["scanner"] == "anomaly": count += 1
	return count

static func confirmed(screening: Dictionary, index: int) -> bool:
	return discrepancies(screening,index) >= CONFIRM

static func check_credentials(screening: Dictionary, index: int) -> String:
	var person: Dictionary = screening["people"][index]
	if person["credentials"] != "unchecked": return "%s's credentials were already checked: %s." % [person["name"],person["credentials"]]
	if index == screening["infiltrator"]:
		person["credentials"] = "discrepancy"
		return "%s's badge was issued two days after the hospital went to emergency staffing. Discrepancy." % person["name"]
	if index == screening["innocent_badge"]:
		person["credentials"] = "discrepancy"
		return "%s has no badge, only a temp agency slip. Discrepancy, and an ordinary one." % person["name"]
	person["credentials"] = "consistent"
	return "%s's credentials check out." % person["name"]

static func scan(screening: Dictionary, index: int) -> String:
	var person: Dictionary = screening["people"][index]
	if person["scanner"] != "unscanned": return "%s was already scanned: %s." % [person["name"],person["scanner"]]
	person["scanner"] = "anomaly" if index == screening["infiltrator"] else "clean"
	return "Triage scanner on %s: %s." % [person["name"],"body temperature and pulse don't fit a human baseline. Anomaly" if person["scanner"] == "anomaly" else "clean"]

## Contain (confirmed) or detain (not yet). Returns the outcome line.
static func detain(screening: Dictionary, index: int) -> String:
	var person: Dictionary = screening["people"][index]
	var proof := confirmed(screening,index)
	if index == screening["infiltrator"]:
		person["status"] = "contained" if proof else "detained_thin"
		screening["log"].append(person["status"])
		return "%s is held. %s Their bag holds Reptilian logistics sheets: people listed as stock." % [person["name"],"Two discrepancies corroborate it." if proof else "On thin evidence, but it was them."]
	person["status"] = "falsely_detained"
	screening["false_detentions"].append(person["name"])
	screening["log"].append("false:%s" % person["name"])
	return "%s is held, and it's wrong. %s The group around them panics." % [person["name"],"Two discrepancies, and still innocent." if proof else "One odd badge isn't proof."]

static func infiltrator_free(screening: Dictionary) -> bool:
	return screening["people"][screening["infiltrator"]]["status"] == "with group"

## Round 3: the infiltrator slips off to the fence gate and opens it, unless held.
static func act(screening: Dictionary, board) -> String:
	if screening["acted"] or board.phase < ACT_ROUND or not infiltrator_free(screening): return ""
	var group: Dictionary = board.cohorts[screening["infiltrator"]]
	if not ["active","riding"].has(group["status"]): return ""
	screening["acted"] = true
	var witnesses: Array[String] = []
	for index in range(board.soldiers.size()):
		if board.soldier_can_act(index) and board.sight_preview(board.soldiers[index]["cell"],board.GATE)["clear"]:
			witnesses.append(board.soldiers[index]["name"])
	if not witnesses.is_empty():
		screening["witnessed"] = true
		screening["people"][screening["infiltrator"]]["behavior"] = true
		return "%s saw %s slip out to the north fence gate and open it. Discrepancy." % [", ".join(witnesses),screening["people"][screening["infiltrator"]]["name"]]
	return "Someone opened the north fence gate. Nobody had eyes on it."

static func result(screening: Dictionary, board) -> String:
	var person: Dictionary = screening["people"][screening["infiltrator"]]
	if person["status"] != "with group": return person["status"]
	return "reached_base" if board.cohorts[person["group"]]["status"] == "extracted" else "at_large"
