extends Control


var username_value: String
var lobby_player_row = preload("res://lobby/lobby_player_row/lobby_player_row.tscn")

func _ready() -> void:
	var buttons = [
		%ButtonConnect,
		%ButtonDisconnect,
		%ButtonLobbyCreate,
		%ButtonLobbyLeave,
		%ButtonLobbyStart,
		%ButtonQuit
	]
	buttons.map(func(button): button.set_default_cursor_shape(Control.CURSOR_POINTING_HAND))
	
	%ButtonConnect.pressed.connect(func(): _new_user_connect())
	%ButtonDisconnect.pressed.connect(func(): LobbySystem.user_disconnect())
	%ButtonLobbyCreate.pressed.connect(lobby_create)
	%ButtonLobbyStart.pressed.connect(lobby_start)
	%ButtonLobbyStart.disabled = true

	%ButtonLobbyLeave.pressed.connect(func(): LobbySystem.lobby_leave())
	%ButtonQuit.pressed.connect(func(): get_tree().quit())

	%InputUsername.max_length = 14
	%InputUsername.text_changed.connect(func(new_text_value): username_value = new_text_value)
	
	%ColumnLobby.hide()
	
	%ButtonBotRemove.pressed.connect(func(): _change_bot_count(true))
	%ButtonBotAdd.pressed.connect(func(): _change_bot_count())
	
	# Renders
	LobbySystem.signal_client_disconnected.connect(func(): _render_connection_light(false))
	LobbySystem.signal_packet_parsed.connect(func(_packet): _render_connection_light(true))
	LobbySystem.signal_lobby_list_changed.connect(_render_lobby_list)
	LobbySystem.signal_lobby_changed.connect(_render_current_lobby_view)
	LobbySystem.signal_user_list_changed.connect(_render_user_list)
	LobbySystem.signal_lobby_joined.connect(func(maybeLobby): if maybeLobby == null: print('ERROR: Failed to join lobby.'))

	# REACTIVITY
	# Refetch user list and lobbies if anyone leaves or joins
	# (could do more precise element manipulation, but this is a shortcut)
	# TODO: Reactivity (better signals for "computed" values)
	# TODO: The server might want to automatically send these events upon the conditions. 
	LobbySystem.signal_user_joined.connect(func(_id): LobbySystem.users_get())
	LobbySystem.signal_user_left.connect(func(_id): LobbySystem.users_get();  LobbySystem.lobbies_get())
	
	# Debug
	LobbySystem.signal_packet_parsed.connect(_debug)

func lobby_create():
	LobbySystem.lobby_create() 
	%ButtonLobbyStart.disabled = false

func lobby_start():
	LobbySystem.lobby_start_game()
	%ButtonLobbyStart.disabled = true

func _new_user_connect():
	if not username_value:
		username_value = LobbySystem.generate_random_name()
		%InputUsername.text = username_value

	LobbySystem.user_connect(username_value)

func _render_user_list(users):
	%UserList.get_children().map(func(element):  element.queue_free())

	for user in users:
		if user.has('username'):
			var user_label = Label.new()
			user_label.text = user.username
			%UserList.add_child(user_label)

func _new_lobby_item(lobby): # Typed Dict for param here?
	var lobby_container = VBoxContainer.new()
	var lobby_label = Label.new()
	var lobby_players_label = Label.new()
	var divider = HSeparator.new()
	lobby_label.text = lobby.players[0].username + "'s Lobby"
	lobby_players_label.text = "Players: " + str(lobby.players.size())

	var	lobby_button = Button.new()
	lobby_button.set_default_cursor_shape(Control.CURSOR_POINTING_HAND)
	lobby_button.text = "Join"
	lobby_button.pressed.connect(func(): LobbySystem.lobby_join(lobby.id))

	[lobby_label, lobby_players_label, lobby_button, divider].map(lobby_container.add_child)
	
	return lobby_container

func _render_lobby_list(lobbies):
	%LobbyList.get_children().map(func(element):  element.queue_free())

	for lobby in lobbies:
		var new_lobby = _new_lobby_item(lobby)
		%LobbyList.add_child(new_lobby)
	
func _render_current_lobby_view(lobby):
	%ColumnLobby.visible = false
	%LobbyUserList.get_children().map(func(element):  element.queue_free())

	if lobby: 
		%LabelLobbyTitle.text = lobby.players[0].username + "'s Lobby"
		%ColumnLobby.visible = true
		for player in lobby.players:
			var new_color = player.metadata.get('color') if player.metadata.get('color') else '#ffffff'
			var new_lobby_player_row = lobby_player_row.instantiate()
			new_lobby_player_row.name = player.id
			new_lobby_player_row.peer_id = player.id 
			new_lobby_player_row.username = player.username
			new_lobby_player_row.color = new_color
			%LobbyUserList.add_child(new_lobby_player_row, true) 

		var new_bot_count = lobby.lobbyData.get('bot_count') if lobby.lobbyData.get('bot_count') else '0'
		%DisplayBotCount.text = new_bot_count

func _render_connection_light(is_user_connected: bool = false):
	%ConnectionLight.modulate = Color.WHITE
	if is_user_connected:	
		await get_tree().create_timer(0.08).timeout
		%ConnectionLight.modulate = Color.GREEN

func _change_bot_count(decrease: bool = false):
	var new_bot_count
	if decrease: 
		new_bot_count = int(%DisplayBotCount.text) - 1
	else:
		new_bot_count = int(%DisplayBotCount.text) + 1
	LobbySystem.lobby_update_data({"bot_count": str(clampi(new_bot_count, 0, 12))})
	
func _debug(_message):
	#print('[DEBUG LOBBY PACKET]: ', _message)
	pass
