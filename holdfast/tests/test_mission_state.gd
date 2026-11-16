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
	var StoryState = preload("res://state/story_state.gd")
	var story := StoryState.new()
	var other_story := StoryState.new()
	story.knowledge[0].append("witnessed")
	story.powered_gate_groups.append("A")
	story.preference = "patients"
	expect(other_story.knowledge[0].is_empty() and other_story.powered_gate_groups.is_empty() and other_story.preference=="unset","Story instances are independent")
	var story_copy := story.snapshot()
	other_story.restore(story_copy)
	expect(other_story.snapshot()==story_copy,"Story restoration round trip")
	story_copy["knowledge"][0].clear()
	expect(other_story.knowledge[0]==["witnessed"] and story.knowledge[0]==["witnessed"],"Story capture and restore detach nested knowledge")
	var CampaignState = preload("res://state/campaign_state.gd")
	var campaign := CampaignState.new()
	var other_campaign := CampaignState.new()
	campaign.campaign = {"members":[{"history":["rescued"]}]}
	campaign.return_state["active"] = true
	expect(other_campaign.campaign.is_empty() and not other_campaign.return_state["active"],"Campaign and return instances are independent")
	var campaign_copy := campaign.snapshot()
	other_campaign.restore_campaign(campaign_copy["campaign"])
	other_campaign.restore_return(campaign_copy["return_map"])
	expect(other_campaign.snapshot()==campaign_copy,"Campaign/return restoration round trip")
	campaign_copy["campaign"]["members"][0]["history"].clear()
	campaign_copy["return_map"]["active"] = false
	expect(other_campaign.campaign["members"][0]["history"]==["rescued"] and other_campaign.return_state["active"],"Campaign restore owns nested history")
	var ResultState = preload("res://state/result_state.gd")
	var result := ResultState.new()
	var other_result := ResultState.new()
	result.rescue_events.append({"id":"rescue-1","kind":"stabilized"})
	expect(other_result.rescue_events.is_empty(),"Rescue records are per instance")
	other_result.pending_finish_reason = "pending"
	var events := result.snapshot()
	other_result.restore(events,true)
	expect(other_result.result_ready and other_result.pending_finish_reason=="" and other_result.snapshot()==events,"Result restore resets pending finalization")
	events[0]["kind"] = "changed"
	expect(other_result.rescue_events[0]["kind"]=="stabilized" and result.rescue_events[0]["kind"]=="stabilized","Rescue records are detached")
	print("MISSION STATE FAILURES: ",failures)
	quit(1 if failures else 0)
