extends RefCounted
## The HOLDFAST campaign spine from GDD v3.1 (Sections 08–12): four acts, seventeen
## missions. Only Mission 01 is playable; the rest are PROPOSED in the GDD and shown on
## the operations board so the player can see where Farm Road sits in the story.
## Text is condensed from the GDD; the GDD stays the authority.

const ACTS := [
	{"number":"I","title":"The Breaking of Silence","summary":"Routine professionalism gives way to frightening uncertainty. Unknown machines, a broken warning, and a first glimpse of something no one can explain."},
	{"number":"II","title":"The Hidden War","summary":"Separate the threats: desperate Drover evacuation, Grey extraction, Reptilian conquest. Mistaking one for another costs lives."},
	{"number":"III","title":"The Enemy of My Enemy","summary":"The buried ark is exposed. A hard alliance forms, and the evidence says Earth cannot be held."},
	{"number":"IV","title":"HOLDFAST","summary":"Withdrawal and evacuation. Relationships and preparation become saved lives, and the ark launches from Farm Road."},
]

## status: "playable", "next" (briefed, not built yet) or "planned".
const MISSIONS := [
	{"id":1,"act":0,"title":"Farm Road","status":"playable",
		"brief":"Protect a checkpoint and move civilians east before power loss and machinery block the road. A recovery machine bypasses the squad to take a pump skid: the first contradiction to the invasion story."},
	{"id":2,"act":0,"title":"River Bridge","status":"playable",
		"brief":"Secure a crossing, recover a damaged sensor and escort a civilian column, while reports of selective machine interference clash with real hostile fire elsewhere.",
		"briefing":{
			"objective":"Establish a safe crossing, recover a damaged sensor, and escort a civilian column across.",
			"intel":"Moderate confidence. Reports from the north bank conflict: some describe machines rerouting around people, others describe captives being taken. They may not be the same event.",
			"risks":"A visible Grey operation is working the area and prioritizing captives. An unidentified craft has been reported over the valley; intent unknown.",
			"choice":"Keep the bridge open for people, or reserve a heavy lane for machinery and supply vehicles. There isn't time or capacity to do both.",
			"delay":"A failed crossing forces the column onto a longer convoy route."}},
	{"id":3,"act":0,"title":"Main Street","status":"playable",
		"brief":"A large recovery platform nears critical infrastructure during a town evacuation. Midway, something new arrives and changes the ground itself.",
		"briefing":{
			"objective":"Evacuate the town, stop dangerous platform movement before it reaches the substation, and get the squad out.",
			"intel":"Low confidence. County calls the platform an assault engine. River Bridge witnesses say the machines go around people. An escort unit walks beside it.",
			"risks":"The platform crushes anything in its path. Something unidentified has been reported north-east of town, with the same radio gap as Farm Road.",
			"choice":"Demolish the platform (fast, nothing kept), isolate it at the junction box (intact, inert), or redirect it through the control panel (slowest; it parks across the alley as a barrier).",
			"delay":"If it reaches the substation, power fails and the corridor closes two rounds later."}},
	{"id":4,"act":1,"title":"Interchange","status":"playable",
		"brief":"Reopen a transport junction where armed Drovers recover cargo under pressure. Honor a corridor pause, escort an isolated group, or assault.",
		"briefing":{
			"objective":"Reopen the junction for Ward's convoy: get three civilian groups through and the squad out.",
			"intel":"Moderate confidence. An armed Drover work crew is loading cargo in the middle of the interchange. One group of civilians is stranded on the overpass above them.",
			"risks":"Drover security retaliates when threatened but has never targeted civilians. An unidentified small craft has been seen over the frontage road.",
			"choice":"Negotiate a corridor pause, escort the overpass group around or through the work zone, or assault the crew and take the junction.",
			"delay":"The convoy window closes after round 10. Anyone left behind waits for a later recovery."}},
	{"id":5,"act":1,"title":"Rail Yard","status":"playable",
		"brief":"Free captives or recover an archive from a Grey extraction site while their transport leaves on a visible schedule.",
		"briefing":{
			"objective":"Free the people held in three field pens and get them out the west exit, then get the squad out. Recover the Grey archive or the supply handcar if you can.",
			"intel":"High confidence on the clock: the Grey transport lifts off at the end of round 8. Two Sentries guard it; a third unit is disrupting radios across the yard.",
			"risks":"Sentry beams aim a turn ahead. Marked areas lose electronics: no radio, no lock bypass, no downloads. The Collector loads one pen every two rounds from round 3.",
			"choice":"People, evidence or supplies. The Greys may offer a trade on the channel. It covers exactly what it says.",
			"delay":"Anyone still in a pen when the transport leaves stays behind; anyone aboard is in Grey custody."}},
	{"id":6,"act":1,"title":"County Hospital","status":"playable",
		"brief":"Move patients and staff through a compromised perimeter while Reptilian infiltrators exploit the confusion.",
		"briefing":{
			"objective":"Evacuate the hospital down the east road: walking patients, staff, and a ward of critical patients on gurneys. Get the squad out.",
			"intel":"Moderate confidence. Someone inside is using forged credentials. Movement has been reported north of the perimeter fence. A Drover convoy is expected on the same road.",
			"risks":"The hospital can power only a few systems, and the ambulance needs one. Reptilian forces use sonic attacks and take people, not ground.",
			"choice":"Ambulance for the critical patients or for the walkers; how to treat the convoy; whom to detain, and on what evidence.",
			"delay":"The perimeter collapses after round 10."}},
	{"id":7,"act":1,"title":"Quarry","status":"planned",
		"brief":"Secure an emergency power platform called hostile command infrastructure. The original Drive Rig returns. Demolish, isolate, or recover its controller."},
	{"id":8,"act":2,"title":"Regional Airfield","status":"planned",
		"brief":"Secure transport capacity and a Nordic contact window while Grey forces strip the field."},
	{"id":9,"act":2,"title":"Civic Center","status":"planned",
		"brief":"Extract leaders and civilians from a Reptilian-controlled center tied to a concealed holding facility."},
	{"id":10,"act":2,"title":"The Dam","status":"planned",
		"brief":"Restore safe access and power to a hidden habitat without flooding civilian ground. Kesh offers guidance in exchange for protecting Drover dependents."},
	{"id":11,"act":2,"title":"The Buried Ark","status":"planned",
		"brief":"Reach the sanctuary and protect a parley during a Fallow incursion."},
	{"id":12,"act":3,"title":"Ceasefire Line","status":"planned",
		"brief":"Hold a shared human–Drover corridor against a Fallow advance while a Reptilian raid threatens the transport behind it."},
	{"id":13,"act":3,"title":"Reservoir","status":"planned",
		"brief":"Recover water treatment for waiting evacuees, or a life-support package for the ark. Not both."},
	{"id":14,"act":3,"title":"Mountain Pass","status":"planned",
		"brief":"Move a civilian column between fallback zones while Grey collectors try one last abduction."},
	{"id":15,"act":3,"title":"Substation","status":"planned",
		"brief":"Restore the primary power chain while Fallow terrain effects keep forcing the squad to move."},
	{"id":16,"act":3,"title":"The Valley","status":"planned",
		"brief":"Assign teams to the corridors you've built, then personally recover one threatened relay or transport."},
	{"id":17,"act":3,"title":"Farm Road Revisited","status":"planned",
		"brief":"Hold the original road while people board the ark. The ark launches; Earth falls."},
]

static func mission(id: int) -> Dictionary:
	for entry in MISSIONS:
		if entry["id"] == id: return entry
	return {}

static func label(id: int) -> String:
	var entry := mission(id)
	return "Act %s · Mission %02d · %s" % [ACTS[entry["act"]]["number"],id,entry["title"]]
