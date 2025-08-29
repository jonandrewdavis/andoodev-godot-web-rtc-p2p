extends Control

var username_value: String
var code_value: String

func _ready() -> void:
	%ColumnQuickConnect.custom_minimum_size.x = 300.0
	%ColumnLobby.hide()

	%InputUsername.text_changed.connect(func(text): username_value = text; \
		%ButtonQuickHost.disabled = true if text.length() == 0 else false)
	
	%InputCode.text_changed.connect(func(text): code_value = text; \
		%ButtonQuickJoin.disabled = true if text.length() == 0 else false)
	
	%ButtonQuickJoin.disabled = true
	%ButtonQuickJoin.custom_minimum_size.x = 100
	%ButtonQuickHost.disabled = true;
	%ButtonQuickHost.custom_minimum_size.x = 100

	%ButtonQuickJoin.pressed.connect(_quick_join)
	%ButtonQuickHost.pressed.connect(_quick_host)
	%ButtonLobbyLeave.pressed.connect(func(): LobbySystem.user_disconnect())
	%ButtonLobbyStart.pressed.connect(func(): LobbySystem.lobby_start_game())

	LobbySystem.signal_lobby_own_info.connect(_render_current_lobby_view)
	# TODO: "Reactivity": This does "lobby_get_own()"  time _ANY_ lobby changes to re-render our lobby
	# TODO: This should be moved backend and fire `signal_lobby_own_info` more directly to clients when something about their loby changes (player leave, join, etc)..
	LobbySystem.signal_lobby_list_changed.connect(func(_list): LobbySystem.lobby_get_own()) # Get own each time we get lobbies generally.

	LobbySystem.signal_packet_parsed.connect(print)


# TODO: Paste-able help
func _quick_join():
	LobbySystem.user_connect(username_value)

# TODO: Copy-able button
func _quick_host():
	# TODO: create a "connect-and-create" method? 
	LobbySystem.user_connect(username_value)
	# TODO: actual async/await
	await get_tree().create_timer(1.0).timeout 
	LobbySystem.lobby_create()

func _new_user_item(username: String):
	var user_label = Label.new()
	user_label.text = username
	return user_label

func _render_current_lobby_view(lobby):
	%ColumnLobby.visible = false
	%LobbyUserList.get_children().map(func(element):  element.queue_free())

	if lobby:
		%LabelLobbyCode.text = lobby.id.substr(0, 8)
		%LabelLobbyTitle.text = lobby.players[0].username + "'s Lobby"
		%ColumnLobby.visible = true
		lobby.players.map(func(player): %LobbyUserList.add_child(_new_user_item(player.username)))
