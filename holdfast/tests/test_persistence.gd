extends "res://tests/test_support.gd"
const Persistence = preload("res://systems/encounter_persistence.gd")
func run() -> void:
	var board = new_board("persistence")
	var before: Dictionary = board.encounter_snapshot()
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
	sandbox.free()
	board.free()
	print("PERSISTENCE BOUNDARY FAILURES: ",failures)
	quit(1 if failures else 0)
