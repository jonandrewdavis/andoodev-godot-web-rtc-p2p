extends ColorRect
"""
	Progress Bar System v1.0
	Compatible with Godot 4.4+
	
	QUICK START:
	1. Add ColorRect node to scene
	2. Apply progress_bar.gdshader to ColorRect material
	3. Attach this script to the ColorRect
	4. Configure in inspector or via code
	
	NOTE 1:  The flash/drain effects do not work well with the fade flow mode. 
			 I tried to make them look visually appealing, but I wasn't satisfied with any of the results—they just don’t seem to fit. 
			 I've left them in (though currently broken) for future development, as I plan to expand the shader later.
			 Feel free to modify or experiment with them if you really want to use them.
			
	NOTE 2:  For a custom frame, adjust the scan step number until the bar fits properly, then fine-tune the rest of the parameters until you get 
			 the look you want. In general, the higher the scan step value, the better the visual results.
"""

#region EXPORTED SETTINGS
@export_enum("Continuous", "Discrete") var flow_mode: String = "Continuous"
@export_enum("Pour&Step", "Fade") var fill_type: String = "Pour&Step"
@export var fill_speed: float = 2.0

@export_group("Drain Effects")
@export_enum("None","Flash", "Drain", "Drain Solid") var effect_type: String = "None"
@export var effect_duration: float = 0.5
@export var effect_speed: float = 2.0
@export var effect_delay: float = 0.3
#endregion

# Core variables
var segment_count: int = 1
var max_value: float = 100.0
var current_value: float = 100.0
var current_fill: float = 1.0
var target_fill: float = 1.0
var current_segment_fill: int = 0
var max_segments: int = 0

# State tracking
var effect_start_fill: float = 1.0
var continuous_effect_start_fill: float = 1.0
var is_effect_active: bool = false
var is_transitioning: bool = false
var continuous_effect_active: bool = false

# Tweens
var effect_tween: Tween
var transition_tween: Tween
var single_segment_fade_tween: Tween

# Signals
signal value_changed(old_value: float, new_value: float)
signal value_depleted()
signal value_maxed()
signal segment_lost(segment_index: int)
signal segment_gained(segment_index: int)

func _ready():
	segment_count = material.get_shader_parameter("segment_count")
	max_segments = segment_count
	_update_display_from_value()

func _update_display_from_value():
	var fill_ratio = clamp(current_value / max_value, 0.0, 1.0)
	target_fill = fill_ratio
	current_fill = fill_ratio
	_set_shader_fill_mode()

func _set_shader_fill_mode():
	var is_pour = fill_type == "Pour&Step" and (flow_mode == "Continuous" or segment_count == 1)
	var mode = 1 if fill_type == "Fade" else (2 if is_pour else 0)
	
	material.set_shader_parameter("fill_mode", mode)
	
	match mode:
		0: # Discrete
			current_segment_fill = int(target_fill * max_segments)
			material.set_shader_parameter("discrete_fill_amount", current_segment_fill)
		1: # Fade
			material.set_shader_parameter("fade_fill_amount", current_fill)
			if segment_count == 1:
				material.set_shader_parameter("pour_fill_amount", current_fill)
		2: # Pour
			material.set_shader_parameter("pour_fill_amount", current_fill)

# =============================================================================
# SMOOTH TRANSITIONS
# =============================================================================

func _start_smooth_transition(old_fill: float, new_fill: float):
	var use_smooth = (flow_mode == "Continuous" or fill_type == "Fade")
	
	if not use_smooth:
		current_fill = new_fill
		_set_shader_fill_mode()
		return
	
	_kill_transitions()
	is_transitioning = true
	
	var duration = max(abs(new_fill - old_fill) / fill_speed, 0.1)
	transition_tween = create_tween()
	
	if fill_type == "Fade" and segment_count == 1:
		_start_single_segment_fade(old_fill, new_fill, duration)
	else:
		var update_func = _update_fade_fill if fill_type == "Fade" else _update_smooth_fill
		transition_tween.tween_method(update_func, current_fill, new_fill, duration)
		transition_tween.tween_callback(_on_transition_complete)

func _start_single_segment_fade(from_fill: float, to_fill: float, duration: float):
	material.set_shader_parameter("single_segment_fade_from", from_fill)
	material.set_shader_parameter("single_segment_fade_to", to_fill)
	material.set_shader_parameter("single_segment_fade_progress", 0.0)
	
	single_segment_fade_tween = create_tween()
	single_segment_fade_tween.tween_method(_update_single_segment_fade_progress, 0.0, 1.0, duration)
	single_segment_fade_tween.tween_callback(_on_single_segment_fade_complete)
	
	transition_tween.tween_method(_update_current_fill_only, current_fill, to_fill, duration)

func _update_single_segment_fade_progress(progress: float):
	material.set_shader_parameter("single_segment_fade_progress", progress)

func _update_current_fill_only(fill_value: float):
	current_fill = fill_value

func _on_single_segment_fade_complete():
	var final_fill = material.get_shader_parameter("single_segment_fade_to")
	material.set_shader_parameter("fade_fill_amount", final_fill)
	material.set_shader_parameter("pour_fill_amount", final_fill)
	material.set_shader_parameter("single_segment_fade_progress", 0.0)
	material.set_shader_parameter("single_segment_fade_from", final_fill)
	material.set_shader_parameter("single_segment_fade_to", final_fill)

func _update_fade_fill(fill_value: float):
	current_fill = fill_value
	if segment_count == 1:
		material.set_shader_parameter("single_segment_fade_to", current_fill)
	else:
		material.set_shader_parameter("fade_fill_amount", current_fill)
	_update_continuous_effects(fill_value)

func _update_smooth_fill(fill_value: float):
	current_fill = fill_value
	material.set_shader_parameter("pour_fill_amount", current_fill)
	_update_continuous_effects(fill_value)

func _update_continuous_effects(fill_value: float):
	if is_effect_active and continuous_effect_active:
		if effect_type != "Flash":
			material.set_shader_parameter("drain_current_fill", fill_value)
		elif segment_count == 1:
			material.set_shader_parameter("single_segment_current_fill", fill_value)

func _on_transition_complete():
	is_transitioning = false
	if continuous_effect_active and current_fill == target_fill:
		var cleanup_timer = create_tween()
		cleanup_timer.tween_interval(0.1)
		cleanup_timer.tween_callback(func(): 
			if not is_transitioning:
				continuous_effect_active = false)

func _kill_transitions():
	for tween in [transition_tween, single_segment_fade_tween]:
		if tween: tween.kill()

# =============================================================================
# GAME INTEGRATION
# =============================================================================

func decrease_bar_value(amount: float) -> void:
	_change_value(-amount)

func increase_bar_value(amount: float) -> void:
	_change_value(amount)

func set_bar_value(new_value: float, trigger_effects: bool = true) -> void:
	if new_value < 0:
		push_warning("Progress bar: Negative values not supported, clamping to 0")
	if new_value > max_value:
		push_warning("Progress bar: Value exceeds max_value, clamping to " + str(max_value))
		
	var old_value = current_value
	current_value = clamp(new_value, 0.0, max_value)
	
	if trigger_effects:
		_handle_value_change(old_value, current_value, new_value < old_value)
	else:
		var old_fill = old_value / max_value
		var new_fill = current_value / max_value
		target_fill = new_fill
		
		if fill_type == "Fade":
			current_fill = new_fill
			material.set_shader_parameter("fade_fill_amount", current_fill)
		else:
			_start_smooth_transition(old_fill, new_fill)
		value_changed.emit(old_value, current_value)

func _change_value(delta: float):
	var old_value = current_value
	current_value = clamp(current_value + delta, 0.0, max_value)
	_handle_value_change(old_value, current_value, delta < 0)

func set_max_value(new_max: float, maintain_ratio: bool = false) -> void:
	if maintain_ratio and max_value > 0:
		current_value = (current_value / max_value) * new_max
	else:
		current_value = min(current_value, new_max)
	max_value = new_max
	_update_display_from_value()

# Getters
func get_current_value() -> float: return current_value
func get_current_value_int() -> int: return int(current_value)
func get_max_value() -> float: return max_value
func get_percentage() -> float: return current_value / max_value if max_value > 0 else 0.0
func get_remaining() -> float: return max_value - current_value
func is_full() -> bool: return current_value >= max_value
func is_empty() -> bool: return current_value <= 0.0
func is_smooth_transitioning() -> bool: return is_transitioning

# =============================================================================
# VALUE CHANGE HANDLER
# =============================================================================

func _handle_value_change(old_value: float, new_value: float, is_decreasing: bool) -> void:
	if old_value == new_value: return
	
	var old_fill = old_value / max_value
	var new_fill = new_value / max_value
	target_fill = new_fill
	
	_update_display_based_on_mode(old_fill, new_fill, is_decreasing)
	_emit_change_signals(old_value, new_value)

func _update_display_based_on_mode(old_fill: float, new_fill: float, is_decreasing: bool):
	if fill_type == "Pour&Step":
		_handle_pour_step_mode(old_fill, new_fill, is_decreasing)
	else:
		_handle_fade_mode(old_fill, new_fill, is_decreasing)

func _handle_pour_step_mode(old_fill: float, new_fill: float, is_decreasing: bool):
	if flow_mode == "Continuous":
		material.set_shader_parameter("fill_mode", 2)
		_start_smooth_transition(old_fill, new_fill)
		if effect_type != "None" and is_decreasing:
			_handle_continuous_effect(old_fill, new_fill)
	else:
		_handle_discrete_mode(old_fill, new_fill, is_decreasing)

func _handle_fade_mode(old_fill: float, new_fill: float, is_decreasing: bool):
	material.set_shader_parameter("fill_mode", 1)
	_start_smooth_transition(old_fill, new_fill)
	if effect_type != "None" and is_decreasing:
		_handle_fade_effects(old_fill, new_fill)
	elif not is_decreasing or effect_type == "None":
		continuous_effect_active = false

func _handle_discrete_mode(old_fill: float, new_fill: float, is_decreasing: bool):
	if segment_count == 1:
		material.set_shader_parameter("fill_mode", 2)
		current_fill = new_fill
		material.set_shader_parameter("pour_fill_amount", current_fill)
		if effect_type != "None" and is_decreasing:
			_start_single_segment_effect(old_fill, new_fill)
	else:
		material.set_shader_parameter("fill_mode", 0)
		var old_segments = int(old_fill * max_segments)
		var new_segments = int(new_fill * max_segments)
		
		current_segment_fill = new_segments
		current_fill = new_fill
		material.set_shader_parameter("discrete_fill_amount", current_segment_fill)
		
		if effect_type != "None" and old_segments != new_segments:
			_emit_segment_signals(old_segments, new_segments, is_decreasing)
			if is_decreasing:
				_start_multi_segment_effect(old_segments, new_segments, old_fill, new_fill)

func _handle_continuous_effect(old_fill: float, new_fill: float):
	if not continuous_effect_active or not is_effect_active:
		continuous_effect_start_fill = old_fill
		continuous_effect_active = true
		effect_start_fill = old_fill
		_start_effect_by_type(old_fill, new_fill, true)
	else:
		_update_ongoing_effect(new_fill)

func _handle_fade_effects(old_fill: float, new_fill: float):
	if not continuous_effect_active or not is_effect_active:
		continuous_effect_start_fill = old_fill
		continuous_effect_active = true
		effect_start_fill = old_fill
		_start_fade_effect(old_fill, new_fill)
	else:
		_update_fade_ongoing_effect(old_fill, new_fill)

func _emit_segment_signals(old_segments: int, new_segments: int, is_decreasing: bool):
	if is_decreasing:
		for i in range(new_segments, old_segments):
			segment_lost.emit(i)
	else:
		for i in range(old_segments, new_segments):
			segment_gained.emit(i)

func _emit_change_signals(old_value: float, new_value: float):
	value_changed.emit(old_value, new_value)
	if new_value <= 0.0 and old_value > 0.0:
		value_depleted.emit()
	elif new_value >= max_value and old_value < max_value:
		value_maxed.emit()

# =============================================================================
# EFFECT FUNCTIONS
# =============================================================================

func _start_effect_by_type(old_fill: float, new_fill: float, is_continuous: bool = false):
	if effect_type == "Flash":
		if segment_count == 1:
			_start_single_flash(old_fill, new_fill)
		else:
			_start_multi_flash(old_fill, new_fill, is_continuous)
	else:
		_start_drain_effect(old_fill, new_fill)

func _start_fade_effect(old_fill: float, new_fill: float):
	if effect_type == "Flash":
		_start_fade_flash(old_fill, new_fill)
	else:
		_start_fade_drain(old_fill, new_fill)

func _start_single_flash(old_fill: float, new_fill: float):
	is_effect_active = true
	material.set_shader_parameter("flash_type", 2)
	material.set_shader_parameter("single_segment_previous_fill", old_fill)
	material.set_shader_parameter("single_segment_current_fill", new_fill)
	_create_flash_tween("single_segment_flash_intensity")

func _start_multi_flash(old_fill: float, new_fill: float, is_continuous: bool):
	var current_segments = int(new_fill * float(segment_count))
	var start_segments = int((continuous_effect_start_fill if is_continuous else old_fill) * float(segment_count))
	
	if start_segments > current_segments:
		_start_multi_segment_flash(current_segments, start_segments)
	elif current_segments >= 0 and current_segments < segment_count:
		_start_segment_flash(current_segments)

func _start_fade_flash(old_fill: float, new_fill: float):
	is_effect_active = true
	if segment_count == 1:
		material.set_shader_parameter("flash_type", 2)
		material.set_shader_parameter("single_segment_previous_fill", old_fill)
		material.set_shader_parameter("single_segment_current_fill", new_fill)
		_create_flash_tween("single_segment_flash_intensity")
	else:
		_start_multi_flash(old_fill, new_fill, true)

func _start_drain_effect(old_fill: float, new_fill: float):
	is_effect_active = true
	material.set_shader_parameter("flash_type", 4 if effect_type == "Drain Solid" else 3)
	material.set_shader_parameter("drain_previous_fill", old_fill)
	material.set_shader_parameter("drain_current_fill", new_fill)
	material.set_shader_parameter("drain_time_progress", 0.0)
	_create_drain_tween()

func _start_fade_drain(old_fill: float, new_fill: float):
	is_effect_active = true
	if segment_count > 1:
		material.set_shader_parameter("fill_mode", 2)
		material.set_shader_parameter("pour_fill_amount", new_fill)
	
	material.set_shader_parameter("flash_type", 4 if effect_type == "Drain Solid" else 3)
	material.set_shader_parameter("drain_previous_fill", old_fill)
	material.set_shader_parameter("drain_current_fill", new_fill)
	material.set_shader_parameter("drain_time_progress", 0.0)
	
	_kill_effect_tween()
	effect_tween = create_tween()
	effect_tween.tween_method(_update_drain_progress, 0.0, 1.0, effect_duration)
	effect_tween.tween_callback(_end_fade_drain_effect)

func _start_segment_flash(segment_index: int):
	is_effect_active = true
	material.set_shader_parameter("flash_type", 1)
	material.set_shader_parameter("flash_segment", segment_index)
	material.set_shader_parameter("flash_intensity", 1.0)
	_create_flash_tween("flash_intensity")

func _start_multi_segment_flash(from_segment: int, to_segment: int):
	is_effect_active = true
	material.set_shader_parameter("flash_type", 5)
	material.set_shader_parameter("flash_from_segment", from_segment)
	material.set_shader_parameter("flash_to_segment", to_segment - 1)
	material.set_shader_parameter("flash_intensity", 1.0)
	_create_flash_tween("flash_intensity")

func _start_single_segment_effect(old_fill: float, new_fill: float):
	effect_start_fill = old_fill
	if effect_type == "Flash":
		_start_single_flash(old_fill, new_fill)
	else:
		_start_drain_effect(old_fill, new_fill)

func _start_multi_segment_effect(old_segments: int, new_segments: int, old_fill: float, new_fill: float):
	if effect_type == "Flash":
		_start_multi_segment_flash(new_segments, old_segments)
	else:
		_start_discrete_drain_effect(old_fill, new_fill)

func _start_discrete_drain_effect(from_fill: float, to_fill: float):
	is_effect_active = true
	material.set_shader_parameter("fill_mode", 2)
	material.set_shader_parameter("pour_fill_amount", to_fill)
	material.set_shader_parameter("flash_type", 4 if effect_type == "Drain Solid" else 3)
	material.set_shader_parameter("drain_previous_fill", from_fill)
	material.set_shader_parameter("drain_current_fill", to_fill)
	material.set_shader_parameter("drain_time_progress", 0.0)
	
	_kill_effect_tween()
	effect_tween = create_tween()
	effect_tween.tween_method(_update_drain_progress, 0.0, 1.0, effect_duration)
	effect_tween.tween_callback(_end_discrete_effect)

func _update_ongoing_effect(new_fill: float):
	if effect_type != "Flash":
		material.set_shader_parameter("drain_current_fill", new_fill)
	else:
		if segment_count > 1:
			var current_segments = int(new_fill * float(segment_count))
			var previous_segments = int(current_fill * float(segment_count))
			if current_segments != previous_segments:
				_start_segment_flash(current_segments)

func _update_fade_ongoing_effect(old_fill: float, new_fill: float):
	if effect_type != "Flash":
		material.set_shader_parameter("drain_current_fill", new_fill)
	else:
		if segment_count > 1:
			var current_segments = int(new_fill * float(segment_count))
			var previous_segments = int(old_fill * float(segment_count))
			if current_segments != previous_segments:
				_start_segment_flash(current_segments)

# Tween helpers
func _create_flash_tween(intensity_param: String):
	_kill_effect_tween()
	effect_tween = create_tween()
	effect_tween.tween_method(func(val): material.set_shader_parameter(intensity_param, val), 1.0, 1.0, effect_delay)
	effect_tween.tween_method(func(val): material.set_shader_parameter(intensity_param, val), 1.0, 0.0, effect_duration)
	effect_tween.tween_callback(_end_effect)

func _create_drain_tween():
	_kill_effect_tween()
	effect_tween = create_tween()
	effect_tween.tween_method(_update_drain_progress, 0.0, 1.0, effect_duration)
	effect_tween.tween_callback(_end_effect)

func _update_drain_progress(progress: float):
	material.set_shader_parameter("drain_time_progress", progress)
	material.set_shader_parameter("drain_current_fill", current_fill)

func _kill_effect_tween():
	if effect_tween: effect_tween.kill()

func _end_effect():
	is_effect_active = false
	material.set_shader_parameter("flash_type", 0)

func _end_fade_drain_effect():
	is_effect_active = false
	continuous_effect_active = false
	material.set_shader_parameter("flash_type", 0)
	if segment_count > 1:
		material.set_shader_parameter("fill_mode", 1)
	material.set_shader_parameter("fade_fill_amount", current_fill)
	if segment_count == 1:
		material.set_shader_parameter("pour_fill_amount", current_fill)

func _end_discrete_effect():
	_end_effect()
	material.set_shader_parameter("fill_mode", 0)
	material.set_shader_parameter("discrete_fill_amount", current_segment_fill)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

func set_segments_filled(segments: int):
	if flow_mode == "Discrete" and segment_count > 1:
		current_segment_fill = clamp(segments, 0, max_segments)
		material.set_shader_parameter("discrete_fill_amount", current_segment_fill)
		current_fill = float(current_segment_fill) / float(max_segments)
		target_fill = current_fill
		current_value = current_fill * max_value

func set_fill_amount(fill: float):
	if fill_type == "Fade":
		current_fill = clamp(fill, 0.0, 1.0)
		material.set_shader_parameter("fade_fill_amount", current_fill)
		current_value = current_fill * max_value
	else:
		if segment_count == 1 or flow_mode == "Continuous":
			var old_fill = current_fill
			target_fill = clamp(fill, 0.0, 1.0)
			current_value = target_fill * max_value
			_start_smooth_transition(old_fill, target_fill)

func get_current_segments() -> int:
	return current_segment_fill if (flow_mode == "Discrete" and segment_count > 1) else int(current_fill * float(max_segments))

func get_fill_percentage() -> float:
	return current_fill

func update_segment_count(new_segment_count: int):
	segment_count = new_segment_count
	max_segments = segment_count
	material.set_shader_parameter("segment_count", segment_count)
	_update_display_from_value()
	print("Progress bar segments updated to: ", segment_count)
