extends Control

var username_value: String

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
	
	%ButtonConnect.pressed.connect(func(): LobbySystem.user_connect(username_value)) 
	%ButtonDisconnect.pressed.connect(func(): LobbySystem.user_disconnect())
	%ButtonLobbyCreate.pressed.connect(func(): LobbySystem.lobby_create())
	%ButtonLobbyLeave.pressed.connect(func(): LobbySystem.lobby_leave())
	%ButtonLobbyStart.pressed.connect(func(): LobbySystem.lobby_start_game())
	%ButtonQuit.pressed.connect(func(): get_tree().quit())
	
	%InputUsername.max_length = 14
	%InputUsername.text_changed.connect(func(new_text_value): username_value = new_text_value)
	
	%LobbyChatInput.text_submitted.connect(LobbySystem.lobby_send_chat)
	%LobbyChatSend.pressed.connect(func (): LobbySystem.lobby_send_chat(%LobbyChatInput.text))
	
	%ColumnLobby.hide()
	
	# Renders
	LobbySystem.signal_client_disconnected.connect(func(): _render_connection_light(false))
	LobbySystem.signal_packet_parsed.connect(func(_packet): _render_connection_light(true))
	LobbySystem.signal_lobby_list_changed.connect(_render_lobby_list)
	LobbySystem.signal_lobby_own_info.connect(_render_current_lobby_view)
	LobbySystem.signal_user_list_changed.connect(_render_user_list)
	LobbySystem.signal_lobby_chat.connect(_render_lobby_chat)
	
	# REACTIVITY
	# Refetch user list and lobbies if anyone leaves or joins
	# (could do more precise element manipulation, but this is a shortcut)
	# TODO: Reactivity (better signals for "computed" values)
	# TODO: The server might want to automatically send these events upon the conditions. 
	LobbySystem.signal_user_joined.connect(func(_id): LobbySystem.users_get())
	LobbySystem.signal_user_left.connect(func(_id): LobbySystem.users_get();  LobbySystem.lobbies_get())
	LobbySystem.signal_lobby_list_changed.connect(func(_list): LobbySystem.lobby_get_own()) # Get own each time we get lobbies generally.
	
	# Debug
	LobbySystem.signal_packet_parsed.connect(_debug)

func _render_user_list(users):
	%UserList.get_children().map(func(element):  element.queue_free())

	for user in users:
		if user.has('username'):
			var new_user = _new_user_item(user.username)
			%UserList.add_child(new_user)


func _new_user_item(username: String):
	var user_label = Label.new()
	user_label.text = username
	return user_label

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
	%LobbyChat.clear()
	
	if lobby: 
		%LabelLobbyTitle.text = lobby.players[0].username + "'s Lobby"
		%ColumnLobby.visible = true
		lobby.players.map(func(player): %LobbyUserList.add_child(_new_user_item(player.username)))

func _render_lobby_chat(chat_user: String, chat_text: String):
	%LobbyChatInput.clear()
	%LobbyChat.append_text(chat_user + " : " + chat_text)
	%LobbyChat.newline()
	pass
	
func _render_connection_light(is_user_connected: bool = false):
	%ConnectionLight.modulate = Color.WHITE
	if is_user_connected:	
		await get_tree().create_timer(0.08).timeout
		%ConnectionLight.modulate = Color.GREEN

func _debug(_message):
	#print(_message)
	pass
