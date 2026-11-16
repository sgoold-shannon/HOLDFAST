extends "res://tests/test_support.gd"
const Persistence = preload("res://systems/encounter_persistence.gd")
func run() -> void:
	var board = new_board("persistence")
	var before: Dictionary = board.encounter_snapshot()
	for alias in [board.SaveStore.SAVE_PATH,board.FARM_SLOT,board.EVAC_SLOT,board.OPTIONS_SLOT,
		board.PROTOCOL_SLOT,board.RESCUE_SLOT,board.RESULT_SLOT,board.STORY_SLOT,board.TACTICAL_SLOT]:
		expect(board.encounter_slot(alias)==board.RETURN_SLOT,"Legacy slot alias maps to active encounter")
	expect(board.encounter_slot(test_path("custom.save"))==test_path("custom.save"),"Custom save path remains unchanged")
	var campaign_slot: String = board.campaign_path
	board.campaign_path = test_path("absent-directory/checkpoint.save")
	var partial_path := test_path("partial-success.save")
	expect(board.save_encounter(partial_path),"Requested save success remains true when checkpoint fails")
	expect(Persistence.read(partial_path)["snapshot"]==before,"Requested slot survives checkpoint failure")
	expect(board.save_feedback!="C2 saved: deployment, roster, service history and current actions.","Checkpoint failure is shown in feedback")
	board.campaign_path = campaign_slot
	expect(not board.save_encounter(test_path("absent-directory/request.save")),"Requested-slot failure returns false")
	expect(not FileAccess.file_exists(campaign_slot),"Requested-slot failure does not attempt checkpoint")

	var path := test_path("valid.save")
	expect(Persistence.write(before,path)=="","Existing format writes successfully")
	var applied := []
	var apply := func(snapshot: Dictionary): applied.append(snapshot)
	expect(Persistence.restore(path,before["layout"],"Wrong encounter",apply)=="","Valid matching save restores")
	expect(applied.size()==1 and applied[0]==before,"Restore applies exact saved data once")
	applied.clear()
	expect(Persistence.restore(path,"different-layout","Wrong encounter",apply)=="Wrong encounter","Mismatched encounter rejected")
	expect(applied.is_empty(),"Mismatch never invokes restore callback")
	expect(Persistence.restore(test_path("missing.save"),before["layout"],"Wrong encounter",apply)!="","Missing save rejected")
	var corrupt := test_path("corrupt.save")
	var file := FileAccess.open(corrupt,FileAccess.WRITE)
	file.store_buffer(PackedByteArray([1,2]))
	file.close()
	expect(Persistence.restore(corrupt,before["layout"],"Wrong encounter",apply)!="","Corrupt save rejected")
	expect(applied.is_empty(),"Read failures never invoke restore callback")
	var bytes_before := FileAccess.get_file_as_bytes(path)
	expect(Persistence.write({},path)!="","Invalid state cannot overwrite a valid slot")
	expect(FileAccess.get_file_as_bytes(path)==bytes_before,"Failed validation retains prior save bytes")
	for rejected in [corrupt,test_path("missing.save")]:
		expect(not board.load_encounter(rejected),"Controller reports failed load")
		expect(board.encounter_snapshot()==before,"Failed load leaves live encounter unchanged")
	var sandbox = load("res://battlefield.tscn").instantiate()
	root.add_child(sandbox)
	var other := test_path("sandbox.save")
	expect(sandbox.save_encounter(other),"Legacy sandbox save writes")
	expect(not board.load_encounter(other),"Main encounter rejects sandbox slot")
	expect(board.encounter_snapshot()==before,"Wrong encounter leaves live state unchanged")
	board.select_soldier(0)
	expect(board.load_encounter(path),"Main controller restores matching save")
	expect(board.encounter_snapshot()==before,"Controller round trip preserves exact state")

	var sequence = preload("res://systems/campaign_persistence.gd")
	for fail_at in ["","campaign","report","complete"]:
		var calls := []
		var captures := []
		var snapshotter := func():
			captures.append(true)
			return {"capture":captures.size()}
		var writer := func(data: Dictionary, slot: String) -> String:
			calls.append(slot)
			expect(data["capture"]==calls.size(),"Snapshot captured for each attempted write")
			return "disk failure" if slot==fail_at else ""
		var error: String = sequence.campaign_result(snapshotter,"campaign","report","complete",true,writer)
		var expected: Array = ["campaign"] if fail_at=="campaign" else (["campaign","report"] if fail_at=="report" else ["campaign","report","complete"])
		expect(calls==expected and captures.size()==calls.size(),"Checkpoint sequence stops at first failure")
		expect(error==("" if fail_at=="" else "disk failure"),"Checkpoint error propagated")
	var written := []
	var capture := func(): return {}
	var record_write := func(_data: Dictionary, slot: String) -> String:
		written.append(slot)
		return ""
	sequence.campaign_result(capture,"campaign","report","complete",false,record_write)
	expect(written==["campaign","report"],"Retry-required outcome preserves completion slot")
	written.clear()
	sequence.report(capture,"report","complete",true,record_write)
	expect(written==["report","complete"],"Debrief writes report before completion")
	var migration = preload("res://systems/save_migration.gd")
	var legacy := {"layout":"gdd3.1-c2-roster","campaign":{"marker":1}}
	var reader := func(_slot: String): return {"error":"","snapshot":legacy}
	var migrated := []
	var migration_writer := func(data: Dictionary, slot: String) -> String:
		migrated.append([data,slot])
		return ""
	var prepared: Dictionary = migration.return_slot("old","campaign","gdd3.1-d1-return",reader,migration_writer)
	expect(prepared=={"path":"campaign","error":""},"Successful migration selects campaign slot")
	expect(migrated[0][0]["layout"]=="gdd3.1-d1-return" and migrated[0][0].has("return_map"),"Migration adds return state")
	expect(legacy["layout"]=="gdd3.1-c2-roster" and not legacy.has("return_map"),"Migration does not mutate source")
	var reject := func(_data: Dictionary, _slot: String) -> String: return "write failed"
	prepared = migration.return_slot("old","campaign","gdd3.1-d1-return",reader,reject)
	expect(prepared=={"path":"old","error":"write failed"},"Failed migration retains source and reports failure")
	var unreadable := func(_slot: String): return {"error":"missing"}
	migrated.clear()
	prepared = migration.return_slot("old","campaign","gdd3.1-d1-return",unreadable,migration_writer)
	expect(prepared["path"]=="old" and migrated.is_empty(),"Unreadable source is left to normal loader without writing")

	var snapshot_service = preload("res://systems/encounter_snapshot.gd")
	var detached: Dictionary = board.encounter_snapshot()
	var live_before: Dictionary = board.encounter_snapshot()
	detached["combat"]["soldiers"][0]["hp"] = 0
	detached["machine"]["stage"] = 99
	detached["evac"]["cohorts"].clear()
	detached["campaign"]["members"].clear()
	detached["story"]["knowledge"].clear()
	detached["return_map"].clear()
	expect(board.encounter_snapshot()==live_before,"Assembled snapshot owns its nested state")
	var restore_order := []
	var adapters := {}
	for section in ["return_map","results","story","campaign"]:
		adapters[section] = func(data: Dictionary):
			expect(data==live_before,"Restoration receives the validated snapshot")
			restore_order.append(section)
	snapshot_service.restore_extras(live_before,adapters)
	expect(restore_order==["return_map","results","story","campaign"],"Extra-state restore order is explicit")
	expect(live_before.keys()==["layout","combat","ui","machine","evac","breaker","protocol","rescue_target","rescue_events","story","campaign","return_map"],"Existing serialized field order preserved")

	var restorer = preload("res://systems/encounter_restore.gd")
	var section_order := []
	var sections := {}
	# Deliberately register in reverse order; dependencies are enforced by the service.
	for section in ["tactical","machine","evac","breaker","protocol","rescue","extra"]:
		sections[section] = func(_data: Dictionary): section_order.append(section)
	restorer.apply(before,sections)
	expect(section_order==["extra","rescue","protocol","breaker","evac","machine","tactical"],"Mission state precedes tactical rebuild regardless of registration order")
	section_order.clear()
	restorer.apply(before,{"tactical":sections["tactical"]})
	expect(section_order==["tactical"],"Sandbox restore needs only tactical state")
	board.drop_mode = true
	board.isolate_pending = true
	board.close_pending = true
	board.hovered_cell = Vector2i(4,4)
	board.roster_open = true
	expect(board.load_encounter(path),"Full restore succeeds with transient controls open")
	expect(not board.drop_mode and not board.isolate_pending and not board.close_pending and not board.roster_open and board.hovered_cell==board.NONE,"Restore clears stale input modes")
	expect(board.encounter_snapshot()==before,"Shared section restoration preserves saved state")
	expect(board.load_encounter(path) and board.encounter_snapshot()==before,"Repeated restore is stable")
	var completion = preload("res://systems/encounter_completion.gd")
	var result = preload("res://state/result_state.gd").new()
	var dispositions := [{"extracted":false,"condition":"active"},
		{"extracted":false,"condition":"dead"},{"extracted":true,"condition":"stable"}]
	var completion_order := []
	var close := func(reason: String):
		expect(reason=="Road closed","Completion passes the pending reason unchanged")
		completion_order.append("close")
	var report := func():
		expect(result.result_ready and result.pending_finish_reason=="","Report captures finalized state")
		expect(dispositions[0]["left_behind"] and not dispositions[1]["left_behind"] and not dispositions[2]["left_behind"],"Only living unextracted soldiers are left behind")
		completion_order.append("report")
	var commit := func(): completion_order.append("commit")
	var save := func(): completion_order.append("campaign")
	expect(not completion.finalize(result,dispositions,close,report,commit,save),"No pending completion is a no-op")
	expect(completion_order.is_empty(),"No-op completion performs no writes")
	result.pending_finish_reason = "Road closed"
	expect(completion.finalize(result,dispositions,close,report,commit,save),"Pending completion finalizes")
	expect(completion_order==["close","report","commit","campaign"],"Report precedes roster commit and campaign persistence")
	result.pending_finish_reason = "duplicate"
	expect(not completion.finalize(result,dispositions,close,report,commit,save) and completion_order.size()==4,"Repeated deferred completion cannot duplicate history or writes")
	result.result_ready = false
	result.pending_finish_reason = "Road closed"
	completion_order.clear()
	expect(completion.finalize(result,dispositions,close,report),"Earlier result gate needs no campaign callbacks")
	expect(completion_order==["close","report"],"Earlier gate writes only its report")
	var legacy_snapshot := before.duplicate(true)
	legacy_snapshot["layout"] = "gdd3.1-c2-roster"
	legacy_snapshot.erase("return_map")
	var legacy_path := test_path("legacy-c2.save")
	expect(Persistence.write(legacy_snapshot,legacy_path)=="","Legacy campaign fixture is valid")
	var legacy_bytes := FileAccess.get_file_as_bytes(legacy_path)
	board.campaign_path = test_path("upgraded-campaign.save")
	expect(board.load_encounter(legacy_path),"Main entry point upgrades and loads older campaign")
	expect(board.encounter_snapshot()==before,"Migration retains campaign data and initializes return state")
	expect(Persistence.read(board.campaign_path)["snapshot"]==before,"Upgraded campaign is persisted in the current slot")
	expect(FileAccess.get_file_as_bytes(legacy_path)==legacy_bytes,"Migration leaves legacy source untouched")
	board.campaign_path = test_path("absent-directory/upgrade.save")
	board.result_feedback = "unchanged"
	expect(not board.load_encounter(legacy_path),"Failed migration write stops loading")
	expect(board.encounter_snapshot()==before and board.result_feedback=="unchanged","Migration failure preserves encounter and existing result feedback")
	sandbox.free()
	board.free()
	print("PERSISTENCE BOUNDARY FAILURES: ",failures)
	quit(1 if failures else 0)
