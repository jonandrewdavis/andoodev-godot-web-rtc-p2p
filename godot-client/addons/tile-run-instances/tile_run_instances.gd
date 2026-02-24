# Editor debugger plugin that tracks active debug sessions.
# Used by tile_run_instances_global.gd to determine how many instances are running.

@tool
extends EditorDebuggerPlugin

## Debugger message prefix, used to tell msgs are coming from this addon
const MESSAGE_PREFIX := "tile-run-instances"


func _has_capture(prefix: String) -> bool:
	return prefix == MESSAGE_PREFIX


## Intercepts debugger messages sent from game instances,
## responds with info on how to tile their windows.
func _capture(message: String, data: Array, session_id: int) -> bool:
	if message != "%s:get_id" % MESSAGE_PREFIX:
		return false

	# Collect all active debug session indices
	var active_session_indices: Array[int] = []
	var sessions := get_sessions()

	for i in sessions.size():
		if sessions[i].is_active():
			active_session_indices.push_back(i)

	# Send back this session's ID and the list of all active sessions
	var response := {
		"id": session_id,
		"all": active_session_indices
	}
	get_session(session_id).send_message("%s:session_id" % MESSAGE_PREFIX, [response])

	return true
