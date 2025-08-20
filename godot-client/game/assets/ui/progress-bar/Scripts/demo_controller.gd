extends Node
## Multi-bar auto demo script for progress bars

"""
	Auto demo script that finds all progress bars under this node and controls them.
	Bars decrease until empty, then increase until full, then repeat the cycle.
"""

# Demo settings
@export var decrease_amount: float = 10.0      # Amount to decrease each time
@export var increase_amount: float = 10.0      # Amount to increase each time
@export var decrease_interval: float = 0.5     # Time between decreases (seconds)
@export var increase_interval: float = 0.1     # Time between increases (seconds) - faster

# Internal variables
var progress_bars: Array[ColorRect] = []
var bar_states: Array[String] = []             # "decreasing" or "increasing"
var bar_timers: Array[float] = []              # Individual timer for each bar

func _ready():
	find_progress_bars()
	setup_progress_bars()

func find_progress_bars():
	"""Find all ColorRect nodes with progress bar scripts under this node"""
	progress_bars.clear()
	bar_states.clear()
	bar_timers.clear()
	
	_search_for_bars(self)

func _search_for_bars(node: Node):
	"""Recursively search for ColorRect nodes with progress bar functionality"""
	for child in node.get_children():
		if child is ColorRect and child.has_method("decrease_bar_value"):
			progress_bars.append(child)
			bar_states.append("decreasing")    # Start in decreasing state
			bar_timers.append(0.0)             # Initialize timer for this bar
		
		# Continue searching in children
		_search_for_bars(child)

func setup_progress_bars():
	"""Initialize all progress bars"""
	for bar in progress_bars:
		bar.set_bar_value(100.0, false)        # Start at full

func _process(delta: float):
	if progress_bars.is_empty():
		return
		
	# Update each bar's individual timer
	for i in range(progress_bars.size()):
		bar_timers[i] += delta
		
		var current_interval = decrease_interval if bar_states[i] == "decreasing" else increase_interval
		
		if bar_timers[i] >= current_interval:
			bar_timers[i] = 0.0
			update_bar(i)
	
	# Exit on ESC
	if Input.is_action_pressed("ui_cancel"):
		get_tree().quit()

func update_bar(bar_index: int):
	"""Update a specific bar based on its current state"""
	var bar = progress_bars[bar_index]
	var state = bar_states[bar_index]
	
	if state == "decreasing":
		# Decrease the bar
		bar.decrease_bar_value(decrease_amount)
		
		# Check if it reached zero
		if bar.is_empty():
			bar_states[bar_index] = "increasing"
	
	elif state == "increasing":
		# Increase the bar
		bar.increase_bar_value(increase_amount)
		
		# Check if it reached full
		if bar.is_full():
			bar_states[bar_index] = "decreasing"

func update_all_bars():
	"""Update all progress bars based on their current state"""
	for i in range(progress_bars.size()):
		update_bar(i)

func reset_all_bars():
	"""Reset all bars to full and decreasing state"""
	for i in range(progress_bars.size()):
		progress_bars[i].set_bar_value(100.0, false)
		bar_states[i] = "decreasing"
		bar_timers[i] = 0.0                      # Reset timer too
