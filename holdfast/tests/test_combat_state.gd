extends "res://tests/test_support.gd"
const CombatState = preload("res://state/combat_state.gd")
func run() -> void:
	var first := CombatState.new()
	var second := CombatState.new()
	first.shot_rng.seed = 3104
	first.soldiers[0]["hp"] = 3
	first.enemies[0]["hp"] = 1
	first.phase = 7
	first.shot_history.append({"target":Vector2i(3,4),"damage":4})
	expect(second.soldiers[0]["hp"]==8 and second.enemies[0]["hp"]==8 and second.phase==1 and second.shot_history.is_empty(),"Models do not share mutable defaults")
	var saved := first.snapshot()
	var expected_roll := first.shot_rng.randi_range(1,100)
	first.soldiers.clear()
	first.enemies.clear()
	first.shot_history.clear()
	first.restore(saved)
	expect(first.snapshot()==saved,"Restored combat snapshot matches exactly")
	expect(first.shot_rng.randi_range(1,100)==expected_roll,"RNG continuation is deterministic")
	saved["soldiers"][0]["hp"] = 0
	saved["history"][0]["damage"] = 99
	expect(first.soldiers[0]["hp"]==3 and first.shot_history[0]["damage"]==4,"Restored model owns independent data")
	var copy := first.snapshot()
	copy["targets"].clear()
	expect(first.enemies.size()==1,"Snapshot edits cannot mutate model")
	print("COMBAT STATE FAILURES: ",failures)
	quit(1 if failures else 0)
