extends RefCounted
## Live combat state, independent of scene, rendering, input and disk access.
var shot_rng := RandomNumberGenerator.new()
var shot_history: Array[Dictionary] = []
var enemies: Array[Dictionary] = [{"cell": Vector2i.ZERO, "hp": 8, "ammo": 4}]
var last_enemy_phase := 0
var enemy_message := "Enemy has not acted yet."
var soldiers: Array[Dictionary] = [
	{"name": "MSG", "mark": "M", "cell": Vector2i.ZERO, "ap": 2, "ammo": 4, "attacked": false, "hp": 8, "extracted": false},
	{"name": "Ortiz", "mark": "O", "cell": Vector2i.ZERO, "ap": 2, "ammo": 4, "attacked": false, "hp": 8, "extracted": false},
	{"name": "Bell", "mark": "B", "cell": Vector2i.ZERO, "ap": 2, "ammo": 4, "attacked": false, "hp": 8, "extracted": false},
	{"name": "Park", "mark": "P", "cell": Vector2i.ZERO, "ap": 2, "ammo": 4, "attacked": false, "hp": 8, "extracted": false}
]
var phase := 1

func snapshot() -> Dictionary:
	return {"soldiers": soldiers.duplicate(true), "targets": enemies.duplicate(true),
		"phase": phase, "rng_seed": shot_rng.seed, "rng_state": shot_rng.state, "history": shot_history.duplicate(true),
		"last_enemy_phase": last_enemy_phase, "enemy_message": enemy_message}


func restore(snapshot: Dictionary) -> void:
	soldiers.assign(snapshot["soldiers"].duplicate(true))
	enemies.assign(snapshot["targets"].duplicate(true))
	phase = snapshot["phase"]
	last_enemy_phase = snapshot["last_enemy_phase"]
	enemy_message = snapshot["enemy_message"]
	shot_rng.seed = snapshot["rng_seed"]
	shot_rng.state = snapshot["rng_state"]
	shot_history.assign(snapshot["history"].duplicate(true))
