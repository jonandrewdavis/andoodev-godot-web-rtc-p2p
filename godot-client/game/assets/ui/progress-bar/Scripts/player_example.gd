extends Node
## Example player script to test the increase/decrease of the players' Health, Mana. XP bars.

"""
	Player example script for taking damage, using mana, gaining XP and leveling-up.
	
	NOTE: If you use a bar with segments and set the control mode to Discrete you will have to account for proper increase decrease values.
	EX: A bar with 10 segments and a max value of 100, that gets a decrease of 10 will results in 1 empty segment. 
		A bar with 11 segments and a max value of 150, that gets a decrease of 10 will results in 2/3 of the segment being
		technically emptied yet visually the entire segment is emptied.
		In the above case either set up the values properly or use the Continuous control mode (although that mode doesnt empty entire segments as you may want)
"""

# Reference to the progress bars
@export var health_bar: ColorRect
@export var mana_bar: ColorRect
@export var xp_bar: ColorRect

# Player stats
var max_health: float = 100.0
var max_mana: float = 120.0
var max_xp: float = 100.0

# Leveling system
var player_level: int = 1
var health_increase_per_level: float = 50.0
var segments_increase_per_level: int = 1

# These would normally be on a UI controller or something similar but we keep them in here for this example scene.
@onready var health_value: RichTextLabel = $"../Info/HelthBarControls/HealthDisplay/HealthValue"
@onready var mana_value: RichTextLabel = $"../Info/HelthBarControls/ManaDisplay/ManaValue"
@onready var xp_value: RichTextLabel = $"../Info/HelthBarControls/XPDisplay/XPValue"


func _ready():
	setup_progress_bars()

func setup_progress_bars():
	"""Initialize all progress bars with starting values"""
	if health_bar:
		health_bar.max_value = max_health
		health_bar.set_bar_value(max_health + 50.0, false)
		print("Health Bar initialized: ", health_bar.current_value, "/", health_bar.max_value)
	
	if mana_bar:
		mana_bar.max_value = max_mana
		mana_bar.set_bar_value(max_mana, false)
		print("Mana Bar initialized: ", mana_bar.current_value, "/", mana_bar.max_value)
	
	if xp_bar:
		xp_bar.max_value = max_xp
		xp_bar.set_bar_value(0.0, false)  # Start with no XP
		print("XP Bar initialized: ", xp_bar.current_value, "/", xp_bar.max_value)

func _input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			# Health controls
			KEY_1:
				health_bar.decrease_bar_value(10.0)
				print("Player took ", 10.0, " damage")
			KEY_2:
				health_bar.increase_bar_value(10.0)
				print("Player healed for ", 10.0, " HP")
			KEY_3:
				var target_value = (20.0 / 100.0) * max_health
				health_bar.set_bar_value(target_value, true)
				print("Set health to ", 20.0, "% (", target_value, " HP)")
			# Mana controls
			KEY_4:
				mana_bar.decrease_bar_value(10.0)
				print("Player used ", 10.0, " mana")
			KEY_5:
				mana_bar.increase_bar_value(10.0)
				print("Player restored ", 10.0, " mana")
			KEY_6:
				var target_value = (50.0 / 100.0) * max_mana
				mana_bar.set_bar_value(target_value, true)
				print("Set mana to ", 50.0, "% (", target_value, " mana)")
			# XP controls
			KEY_7:
				xp_bar.increase_bar_value(10.0)
				print("Player gained ", 10.0, " XP")
			# Level up control
			KEY_ENTER:
				if xp_bar.is_full():
					level_up()
		
	if Input.is_action_pressed("exit"):
		get_tree().quit()

func level_up():
# // NOTE: This is a very simple Level-up "system" where we just increase health and increase the segment count in the health bar.
# // Not really the most interesting type of level-up but I thought someone may want to know how to increase the segments of a bar through code. 
# // Was kinda in a rush and haven't tested this function very well but I think it should be fine. 
	"""Handle player leveling up when XP bar is full"""
	if not xp_bar.is_full():
		print("Cannot level up - XP bar not full!")
		return
	
	# Increase player level
	player_level += 1
	
	# Reset XP bar
	xp_bar.set_bar_value(0.0, false)  # Reset without effects
	
	# Increase max health
	var old_max_health = max_health
	max_health += health_increase_per_level
	
	# Maintain current health ratio and set new max. You could do whatever here like set it to max.
	health_bar.set_max_value(max_health, true)
	
	# Increase health bar segments if it has more than 1 segment. 
	var current_segments = health_bar.material.get_shader_parameter("segment_count")
	if current_segments > 1:
		var new_segments = current_segments + segments_increase_per_level
		health_bar.update_segment_count(new_segments)
		print("Health bar segments increased from ", current_segments, " to ", new_segments)
	
	print("LEVEL UP! Level: ", player_level)
	print("Max Health increased from ", old_max_health, " to ", max_health)
	print("Current Health: ", health_bar.get_current_value(), "/", health_bar.get_max_value())

func _process(_delta: float) -> void:
	# Display the bar values. Again these should be normally in another UI controller but we use the here for simplicity. 
	health_value.text = str(health_bar.get_current_value())
	mana_value.text = str(mana_bar.get_current_value())
	xp_value.text = str(xp_bar.get_current_value())
	
	if health_bar.get_current_value() <= 0.0:
		print("PLAYER IS DEAD!")
	if mana_bar.get_current_value() <= 0.0:
		print("NO MORE MANA! :(")
	if xp_bar.get_remaining() == 0.0:
		print("FULL XP! PRESS ENTER TO LEVEL UP! (Current Level: ", player_level, ")")
