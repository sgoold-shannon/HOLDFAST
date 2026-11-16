extends "res://tests/test_support.gd"
const MachineState = preload("res://state/machine_state.gd")
const EvacuationState = preload("res://state/evacuation_state.gd")
func run() -> void:
	var machine := MachineState.new()
	var other_machine := MachineState.new()
	machine.machine["hostile"] = true
	machine.protocol["observed"] = true
	machine.breaker_progress = 2
	expect(not other_machine.machine["hostile"] and not other_machine.protocol["observed"] and other_machine.breaker_progress==0,"Machine instances own distinct state")
	var saved := machine.snapshot()
	machine.restore_machine(other_machine.machine)
	machine.restore_protocol(other_machine.protocol)
	other_machine.machine["stage"] = 7
	other_machine.protocol["waypoint"] = 3
	expect(machine.machine["stage"]==0 and machine.protocol["waypoint"]==0,"Machine restore copies source data")
	saved["machine"]["stage"] = 8
	saved["protocol"]["waypoint"] = 2
	expect(machine.machine["stage"]==0 and machine.protocol["waypoint"]==0,"Machine snapshots are detached")
	var evac := EvacuationState.new()
	var other_evac := EvacuationState.new()
	evac.cohorts[0]["manifest"][0] = "changed"
	evac.order_used = true
	evac.ended = true
	evac.end_reason = "Road closed"
	evac.last_civilian_phase = 5
	expect(other_evac.cohorts[0]["manifest"][0]=="A-01" and not other_evac.order_used and not other_evac.ended,"Civilian instances own nested manifests and phase state")
	var snapshot := evac.snapshot()
	other_evac.restore(snapshot)
	expect(other_evac.snapshot()==snapshot,"Civilian snapshot round trip")
	snapshot["cohorts"][0]["manifest"].clear()
	expect(other_evac.cohorts[0]["manifest"].size()==4 and evac.cohorts[0]["manifest"].size()==4,"Civilian restore and capture are detached")
	print("MISSION STATE FAILURES: ",failures)
	quit(1 if failures else 0)
