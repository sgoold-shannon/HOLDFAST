extends RefCounted
## Ordered checkpoints retain earlier successful files and stop at the first failure.
const Persistence = preload("res://systems/encounter_persistence.gd")
static func write_sequence(snapshot: Callable, paths: Array[String], writer: Callable = Persistence.write) -> String:
	for path in paths:
		var problem: String = writer.call(snapshot.call(),path)
		if problem != "": return problem
	return ""

static func report(snapshot: Callable, report_path: String, completion_path: String, may_continue: bool, writer: Callable = Persistence.write) -> String:
	var paths: Array[String] = [report_path]
	if may_continue: paths.append(completion_path)
	return write_sequence(snapshot,paths,writer)

static func campaign_result(snapshot: Callable, campaign_path: String, report_path: String, completion_path: String, may_continue: bool, writer: Callable = Persistence.write) -> String:
	var paths: Array[String] = [campaign_path,report_path]
	if may_continue: paths.append(completion_path)
	return write_sequence(snapshot,paths,writer)
