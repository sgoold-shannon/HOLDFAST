extends RefCounted
## The parley (Mission 11): terms built while MSG sits at the table and the Fallow are kept off
## it. GDD v3.1 §21: prior actions widen terms; poor relations still permit a narrow bargain;
## generous terms add berths only if life support can carry them. State: board.parley.
const WORKING := 8
const GENEROUS := 15

static func initial(start: int, kesh: bool, aven: bool) -> Dictionary:
	return {"terms":start,"start":start,"kesh":kesh,"aven":aven,"sat":0,"log":[]}

static func gain(parley: Dictionary) -> int:
	return 1+(1 if parley["kesh"] else 0)+(1 if parley["aven"] else 0)

## Environment phase: if the board says the parley sits, terms go up.
static func session(parley: Dictionary, sits: bool, phase: int) -> String:
	if not sits: return ""
	var amount := gain(parley)
	parley["terms"] += amount
	parley["sat"] += 1
	parley["log"].append("sat:%d" % phase)
	return "The parley sits: terms +%d (%d)." % [amount,parley["terms"]]

static func agreement(parley: Dictionary, life_intact: bool) -> String:
	if parley["terms"] >= GENEROUS and life_intact: return "generous"
	if parley["terms"] >= WORKING: return "working"
	return "narrow"
