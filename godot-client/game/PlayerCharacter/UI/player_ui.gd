extends CanvasLayer

class_name PlayerUI

@onready var player: PlayerCharacter = get_parent()
@onready var progress_bar = %Health

var RETICLE: Control

func _ready() -> void:
	if not is_multiplayer_authority():
		queue_free()
		return
	$TopLevelControl.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	%Menu.hide()
	AudioServer.set_bus_volume_linear(0, 0.5)

	player.health_system.max_health_updated.connect(_on_max_health_updated)
	player.health_system.health_updated.connect(_on_health_updated)
	player.health_system.hurt.connect(_on_hurt)
	
	%HurtTexture.hide()
	%HurtTexture.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	%HurtTimer.timeout.connect(_on_hurt_timer_timeout)

	%AimSlider.value_changed.connect(_on_aim_changed)
	%SenSlider.value_changed.connect(_on_sens_changed)
	%SoundSlider.value_changed.connect(_on_sound_changed)

	await get_tree().create_timer(0.1).timeout
	%SenSlider.value = player.camHolder.XAxisSens
	%AimSlider.value = player.camHolder.aimFactor
	%SoundSlider.value = AudioServer.get_bus_volume_linear(0)

	%Respawn.pressed.connect(func(): player.health_system.death.emit())
	%Disconnect.pressed.connect(_on_disconnect)
	%Quit.pressed.connect(func(): get_tree().quit())

	
	%ScoreTimer.timeout.connect(update_score)
	%ScoreTimer.start()

	# Hit
	player.signal_hit_success.connect(_on_hit_signal)
	%HitMarker.hide()
	%HitMarker.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	%HitTimer.timeout.connect(func(): %HitMarker.hide())

func _process(_delta: float) -> void:
	if %Menu.visible and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		%Menu.hide()
	elif %Menu.visible == false and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		%Menu.show()

	%LabelFPSCounter.text = 'FPS: ' + str(Engine.get_frames_per_second())

func _on_hurt():
	%HurtTexture.visible = true
	%HurtTimer.start()

func _on_hurt_timer_timeout():
	%HurtTexture.visible = false

func _on_health_updated(next_health):
	var current = progress_bar.get_current_value()
	if next_health < current:
		progress_bar.decrease_bar_value(current - next_health)
	else:
		var diff = next_health - current
		progress_bar.increase_bar_value(diff)

	%HealthBar.value = next_health

func _on_max_health_updated(new_max):
	progress_bar.set_max_value(new_max)
	progress_bar.set_bar_value(new_max)
	%HealthBar.max_value = new_max
	%HealthBar.value = new_max

func _on_update_ammo(ammo, ammo_reserve, _is_shooting):
	%AmmoLabel.text = str(ammo) + ' / ' + str(ammo_reserve)

func _on_sens_changed(new_value: float):
	player.camHolder.XAxisSens = new_value
	player.camHolder.YAxisSens = new_value
	%SenVal.text = str("%0.2f" % new_value)

func _on_aim_changed(new_value: float):
	player.camHolder.aimFactor = new_value
	%AimVal.text = str("%0.2f" % new_value)

func _on_sound_changed(new_value:float):
	AudioServer.set_bus_volume_linear(0, new_value)

# TODO: Do not use Hub this way.
func _on_disconnect():
	if multiplayer != null && multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer = null

func update_score():
	for _score in %Scoreboard.get_children():
		_score.queue_free()
		
	#for _player_id in Hub.players:
		#var new_label = Label.new()
		#new_label.text = Hub.players[_player_id].username + ": " + str(Hub.players[_player_id].score) 
		#%Scoreboard.add_child(new_label)
	
func _on_hit_signal(headshot = false):
	%HitMarker.show()
	%HitTimer.start()
	await get_tree().create_timer(0.1).timeout
	if headshot: 
		%HitHeadSound.play()
	else:
		%HitSound.play()

#func displayWeaponStack(weaponStack : int):
	#weaponStackLabelText.set_text(str(weaponStack))
	
func displayWeaponName(weaponName : String):
	%LabelWeaponName.set_text(str(weaponName))
	
func displayTotalAmmoInMag(totalAmmoInMag : int, nbProjShotsAtSameTime : int):
	@warning_ignore("integer_division")
	%LabelAmmo.set_text(str(totalAmmoInMag/nbProjShotsAtSameTime))
	
func displayTotalAmmo(totalAmmo : int, nbProjShotsAtSameTime : int):
	@warning_ignore("integer_division")
	%LabelAmmoRemaining.set_text(str(totalAmmo/nbProjShotsAtSameTime))
