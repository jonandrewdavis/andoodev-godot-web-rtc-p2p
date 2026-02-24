# Autoload script that tiles multiple game instances across the screen.
# Add this as an autoload in Project Settings.

extends Node

## Target monitor index. Set to -1 for auto-detect (uses current screen),
## or 0, 1, 2, etc. to specify a particular monitor.
@export var target_monitor: int = -1

## Gap between tiled windows in pixels.
@export var window_margin_gap: int = 0


func _ready() -> void:
	# Subscribe to debugger messages
	EngineDebugger.register_message_capture("tile-run-instances", _on_tile_instances)
	EngineDebugger.send_message.call_deferred("tile-run-instances:get_id", [])


## Handle debugger messages for tile-run-instances addon
func _on_tile_instances(message: String, data: Array) -> bool:
	if message != "session_id":
		return false

	var info: Dictionary = data[0]
	var my_session_id: int = info.get("id", -1)
	var active_sessions: Array = info.get("all", [])

	if active_sessions.size() <= 1:
		return true

	# Find our index in the list of active sessions
	for instance_index in active_sessions.size():
		if active_sessions[instance_index] == my_session_id:
			# Position the window around 
			_tile_window(instance_index, active_sessions.size())
			break

	return true


## Positions this window in a grid layout based on instance index and total count.
func _tile_window(instance_index: int, total_instances: int) -> void:
	var window := get_window()
	var screen := _get_target_screen()
	var screen_rect := DisplayServer.screen_get_usable_rect(screen)
	var window_size := Vector2i(window.get_visible_rect().size)

	# Move window to target screen first (if different)
	window.current_screen = screen

	var grid := _calculate_grid_layout(total_instances)
	var position := _get_grid_position(instance_index, grid, screen_rect, window_size)

	window.position = position


## Returns the monitor index to use for tiling.
func _get_target_screen() -> int:
	var screen_count := DisplayServer.get_screen_count()

	if target_monitor < 0:
		# Auto-detect: use current screen
		return get_window().current_screen
	elif target_monitor < screen_count:
		# Use the specified monitor
		return target_monitor
	else:
		# Invalid monitor specified, fall back to primary
		push_warning("tile-run-instances: Monitor %d not found (only %d available), using primary" % [target_monitor, screen_count])
		return DisplayServer.get_primary_screen()


## Calculates the grid dimensions (columns x rows) for a given number of instances.
func _calculate_grid_layout(total: int) -> Vector2i:
	if total <= 1:
		return Vector2i(1, 1)
	elif total == 2:
		return Vector2i(2, 1)  # 2 columns, 1 row (side by side)
	elif total <= 4:
		return Vector2i(2, 2)  # 2x2 grid
	elif total <= 6:
		return Vector2i(3, 2)  # 3 columns, 2 rows
	elif total <= 9:
		return Vector2i(3, 3)  # 3x3 grid
	else:
		# For 10+ instances, calculate a roughly square grid
		var cols := ceili(sqrt(float(total)))
		var rows := ceili(float(total) / float(cols))
		return Vector2i(cols, rows)


## Calculates the screen position for a window in the grid.
func _get_grid_position(instance_index: int, grid: Vector2i, screen_rect: Rect2i, window_size: Vector2i) -> Vector2i:
	# Calculate which row and column this instance belongs to
	var col := instance_index % grid.x
	var row := instance_index / grid.x

	# Calculate the size of each cell in the grid (including margins)
	var cell_width := window_size.x + window_margin_gap
	var cell_height := window_size.y + window_margin_gap

	# Calculate total grid size
	var total_grid_width := grid.x * cell_width - window_margin_gap
	var total_grid_height := grid.y * cell_height - window_margin_gap

	# Calculate top-left corner of the grid (centered on screen)
	var grid_origin := Vector2i(
		screen_rect.position.x + (screen_rect.size.x - total_grid_width) / 2,
		screen_rect.position.y + (screen_rect.size.y - total_grid_height) / 2
	)

	# Calculate this window's position within the grid
	var position := Vector2i(
		grid_origin.x + col * cell_width,
		grid_origin.y + row * cell_height
	)

	return position
