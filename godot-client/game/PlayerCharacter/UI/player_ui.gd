extends CanvasLayer

class_name PlayerUI

@onready var player: PlayerCharacter = get_parent()
@onready var progress_bar = %Health

var world: World 
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

	# Hit
	player.signal_hit_success.connect(_on_hit_signal)
	
	%HitMarker.hide()
	%HitMarker.set_mouse_filter(Control.MOUSE_FILTER_IGNORE)
	%HitTimer.timeout.connect(func(): %HitMarker.hide())
	
	LobbySystem.signal_lobby_chat.connect(_render_lobby_chat_visible)
	%LobbyChatFadeTimer.timeout.connect(_render_lobby_chat_fade)

	LobbySystem.signal_lobby_own_info.connect(_render_own_lobby_info)
	LobbySystem.lobby_get_own()

	world = get_tree().get_first_node_in_group("World")
	world.signal_player_death.connect(add_death_to_player)
	world.signal_player_kill.connect(add_kill_to_player)

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

func _render_lobby_chat_visible(chat_user: String, chat_text: String):
	%LobbyChatVisible.modulate.a = 1.0
	%LobbyChatVisible.append_text(chat_user + " : " + chat_text)
	%LobbyChatVisible.newline()
	%LobbyChatFadeTimer.start()

func _render_lobby_chat_fade():
	var tween = get_tree().create_tween()
	tween.tween_property(%LobbyChatVisible, "modulate:a", 0.0, 0.8)
	tween.play()
	await tween.finished
	tween.kill()

# TODO: Would be nice to have some type saftey on this
func _render_own_lobby_info(lobby):
	# TODO: We clear the scoreboard if new players join.
	# We could make a list of not present Ids and just add those instead.
	if lobby.players.size() != %LobbyScoreboard.get_child_count():
		%LobbyScoreboard.get_children().map(func(el): el.queue_free())
		
	for _player in lobby.players:
		if _player.id == player.name:
			player.update_nameplate(_player.username)
		
		var new_player_item = Instantiate.scene(PlayerInfoItem)
		new_player_item.name = _player.id 
		new_player_item.set_user_data(_player.username, Color.WEB_PURPLE.to_html())
		%LobbyScoreboard.add_child(new_player_item, true)

func add_death_to_player(playerId: String):
	var info_target: PlayerInfoItem = %LobbyScoreboard.get_node(playerId)
	info_target.add_death()

func add_kill_to_player(playerId: String):
	var info_target: PlayerInfoItem = %LobbyScoreboard.get_node(playerId)
	info_target.add_kill()
