extends Control

func _ready() -> void:
	%LobbyChatInput.text_submitted.connect(func(_text): _send_chat_to_lobby())
	%LobbyChatSend.pressed.connect(func(): _send_chat_to_lobby())

	LobbySystem.signal_lobby_list_changed.connect(func(_list): LobbySystem.lobby_get_own()) # Get own each time we get lobbies generally.
	LobbySystem.signal_lobby_own_info.connect(_render_lobby_clear)
	LobbySystem.signal_lobby_chat.connect(_render_lobby_chat)

func _send_chat_to_lobby():
	LobbySystem.lobby_send_chat(%LobbyChatInput.text)
	%LobbyChatInput.clear()

func _render_lobby_clear(lobby):
	if not lobby:
		%LobbyChat.clear()

func _render_lobby_chat(chat_user: String, chat_text: String):
	%LobbyChat.append_text(chat_user + " : " + chat_text)
	%LobbyChat.newline()
