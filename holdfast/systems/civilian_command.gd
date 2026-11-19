extends RefCounted
## Civilian command and panic for the desktop game ("authority" model).
## MSG (PSYOP) directs any group within his voice range for free and keeps nearby
## crowds steady; other soldiers can direct or settle a group they're close to for 1 AP.
## Machine activity and gunfire near a group shake it, then panic it.
## All tuning numbers live here.
const VOICE_RANGE := 6    # MSG orders a group this many squares away (walking distance), free
const NEAR_RANGE := 2     # any other soldier orders or settles a group this close, 1 AP
const STEADY_RANGE := 3   # MSG this close stops a group getting more scared
const THREAT_RANGE := 3   # machine, its target square, or gunfire this close scares a group
const CALM := 0
const SHAKEN := 1
const PANICKED := 2
const MOVE_BUDGET := [3, 2, 1]   # squares per turn: calm, shaken, panicked (panicked scatter)
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func msg_index(soldiers: Array) -> int:
	for index in range(soldiers.size()):
		if soldiers[index]["name"] == "MSG": return index
	return 0

## Standing and on the map: can speak even with 0 AP left.
static func standing(soldiers: Array, index: int) -> bool:
	if index < 0 or index >= soldiers.size(): return false
	var soldier: Dictionary = soldiers[index]
	return not soldier["extracted"] and soldier["hp"] > 0 and soldier.get("condition","active") == "active" and soldier.get("carried_by",-1) == -1

static func level(cohort: Dictionary) -> int:
	return cohort.get("panic",CALM)

static func level_name(cohort: Dictionary) -> String:
	return ["calm","SHAKEN","PANICKED"][level(cohort)]

## Who can give this group an order right now: {"ok", "by", "cost", "text"}.
static func order_authority(soldiers: Array, active: int, cohort: Dictionary) -> Dictionary:
	var msg := msg_index(soldiers)
	if level(cohort) == PANICKED:
		return {"ok":false,"by":-1,"cost":0,"text":"Panicked: calm them first"}
	if standing(soldiers,msg) and distance(soldiers[msg]["cell"],cohort["cell"]) <= VOICE_RANGE:
		return {"ok":true,"by":msg,"cost":0,"text":"MSG in range (free)"}
	if standing(soldiers,active) and distance(soldiers[active]["cell"],cohort["cell"]) <= NEAR_RANGE:
		if soldiers[active]["ap"] >= 1:
			return {"ok":true,"by":active,"cost":1,"text":"%s nearby (1 AP)" % soldiers[active]["name"]}
		return {"ok":false,"by":-1,"cost":0,"text":"%s has no AP left" % soldiers[active]["name"]}
	return {"ok":false,"by":-1,"cost":0,"text":"Out of range: MSG within %d squares, or a soldier within %d (1 AP)" % [VOICE_RANGE,NEAR_RANGE]}

## Who can calm this group: MSG (1 AP, fully calm) or a nearby soldier (1 AP, one step calmer).
static func calm_authority(soldiers: Array, active: int, cohort: Dictionary) -> Dictionary:
	if level(cohort) == CALM:
		return {"ok":false,"by":-1,"cost":0,"steps":0,"text":"Already calm"}
	var msg := msg_index(soldiers)
	if standing(soldiers,msg) and soldiers[msg]["ap"] >= 1 and distance(soldiers[msg]["cell"],cohort["cell"]) <= VOICE_RANGE:
		return {"ok":true,"by":msg,"cost":1,"steps":PANICKED,"text":"MSG talks them down (1 AP)"}
	if standing(soldiers,active) and soldiers[active]["ap"] >= 1 and distance(soldiers[active]["cell"],cohort["cell"]) <= NEAR_RANGE:
		return {"ok":true,"by":active,"cost":1,"steps":1,"text":"%s settles them a little (1 AP)" % soldiers[active]["name"]}
	return {"ok":false,"by":-1,"cost":0,"steps":0,"text":"Need MSG within %d squares with 1 AP, or a soldier within %d" % [VOICE_RANGE,NEAR_RANGE]}

static func threatened(cohort: Dictionary, threats: Array) -> bool:
	for cell in threats:
		if distance(cell,cohort["cell"]) <= THREAT_RANGE: return true
	return false

## End-of-round fear check. Returns the new level.
static func update_panic(cohort: Dictionary, threats: Array, soldiers: Array) -> int:
	if cohort["status"] != "active": return level(cohort)
	var msg := msg_index(soldiers)
	var msg_steady: bool = standing(soldiers,msg) and distance(soldiers[msg]["cell"],cohort["cell"]) <= STEADY_RANGE
	var escort := msg_steady
	for index in range(soldiers.size()):
		if standing(soldiers,index) and distance(soldiers[index]["cell"],cohort["cell"]) <= NEAR_RANGE: escort = true
	var now := level(cohort)
	if threatened(cohort,threats):
		if not msg_steady: now = mini(PANICKED,now+1)
	elif escort:
		now = maxi(CALM,now-1)
	cohort["panic"] = now
	return now

## A panicked group runs one square away from the nearest threat, or freezes.
static func scatter_step(cohort: Dictionary, threats: Array, safe: Callable) -> Vector2i:
	var here: Vector2i = cohort["cell"]
	var best := here
	var best_score := nearest(here,threats)
	for direction in DIRECTIONS:
		var next := here+direction
		if safe.call(next) and nearest(next,threats) > best_score:
			best = next
			best_score = nearest(next,threats)
	return best

static func nearest(cell: Vector2i, threats: Array) -> int:
	var best := 1000
	for threat in threats: best = mini(best,distance(cell,threat))
	return best
