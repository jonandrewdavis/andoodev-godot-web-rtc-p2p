extends Node

signal signal_client_connection_started
signal signal_client_connection_confirmed
signal signal_client_disconnected

signal signal_user_joined(id)
signal signal_user_left(id)
signal signal_user_list_changed(users)

signal signal_lobby_list_changed(lobbies)
signal signal_lobby_chat(chat_user, chat_text)
signal signal_lobby_own_info(lobby)
signal signal_lobby_game_started

signal signal_packet_parsed(message)

#region Actions
# ACTIONS
const Action_Connect = "Connect"
const Action_GetUsers = "GetUsers"
const Action_PlayerJoin = "PlayerJoin"
const Action_PlayerLeft = "PlayerLeft"
const Action_GetLobbies = "GetLobbies"
const Action_GetOwnLobby = "GetOwnLobby"
const Action_CreateLobby = "CreateLobby"
const Action_JoinLobby = "JoinLobby"
const Action_LeaveLobby = "LeaveLobby"
const Action_LobbyChanged = "LobbyChanged"
const Action_GetUsersInLobby = "GetUsersInLobby"
const Action_MapSelected = "MapSelected"
const Action_GameStarted = "GameStarted"
const Action_MessageToLobby = "MessageToLobby"
const Action_Heartbeat = "Heartbeat"

# WebRTC Actions: 
const Action_NewPeerConnection = "NewPeerConnection"
const Action_Offer = "Offer"
const Action_Answer = "Answer"
const Action_Candidate = "Candidate"
#endregion

#const WEB_SOCKET_SERVER_URL = 'ws://localhost:8787'
const WEB_SOCKET_SERVER_URL = 'wss://typescript-websockets-lobby.jonandrewdavis.workers.dev'
const WEB_SOCKET_SECRET_KEY = "9317e4d6-83b3-4188-94c4-353a2798d3c1"

const STUN_TURN_SERVER_URL = 'stun:stun.l.google.com:19302'

var web_rtc_peer: WebRTCMultiplayerPeer

var ws_peer: WebSocketPeer 
var ws_peer_id: String
var ws_connection_validated = false

var current_username = ''

func _ready():
	set_process(false)
	tree_exited.connect(_ws_close_connection)

func _process(_delta):
	ws_peer.poll()	
	var state: WebSocketPeer.State = ws_peer.get_ready_state()
	match state:
		WebSocketPeer.STATE_CONNECTING:
			return
		WebSocketPeer.STATE_OPEN:
			# TODO: Improve initial user connect process and validation 
			if ws_connection_validated == false:
				user_confirm_connection()
				return
			while ws_peer.get_available_packet_count():
				_ws_parse_packet()
		WebSocketPeer.STATE_CLOSING:
			# Keep polling to achieve proper close.
			pass
		WebSocketPeer.STATE_CLOSED:
			var code = ws_peer.get_close_code()
			var reason = ws_peer.get_close_reason()
			print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
			signal_client_disconnected.emit()
			set_process(false)
			
func _ws_close_connection(code: int = 1000, reason: String = 'Reason: N/A'):
	if _is_web_socket_connected():
		ws_peer.close(code, reason)
		signal_client_disconnected.emit()

func _ws_parse_packet():
	var packet = ws_peer.get_packet().get_string_from_utf8()
	var packet_to_json = JSON.parse_string(packet)
	if packet_to_json and packet_to_json.has('action') and packet_to_json.has('payload'):
		_ws_process_packet(packet_to_json)
		signal_packet_parsed.emit(packet_to_json)
	else:
		push_warning("Invalid message from server received")		

func _ws_process_packet(message):
	match(message.action):
		Action_Connect:
			# TODO: Rename "Action_Connect" to be "confirmed". It's sending us our peer id.
			if  message.payload.has("webId"):
				signal_client_connection_confirmed.emit(message.payload.webId)
				ws_peer_id = message.payload.webId
			else:
				_ws_close_connection(1000, "Couldn't authenticate")
		Action_GetUsers:
			if message.payload.has("users"):
				signal_user_list_changed.emit(message.payload.users)
			else:
				signal_user_list_changed.emit([])
		Action_GetLobbies:
			if message.payload.has("lobbies"):
				signal_lobby_list_changed.emit(message.payload.lobbies)
			else:
				signal_lobby_list_changed.emit([])
		Action_GetOwnLobby:
			if message.payload.has("lobby"):
				signal_lobby_own_info.emit(message.payload.lobby)
			else:
				signal_lobby_own_info.emit([])
		Action_PlayerJoin:
			if message.payload.has("id"):
				signal_user_joined.emit(message.payload.id)
		Action_PlayerLeft:
			if message.payload.has("webId"):
				signal_user_left.emit(message.payload.webId)
		Action_MessageToLobby:
			if message.payload.has("message"): # TODO: "chat_text" ?
				signal_lobby_chat.emit(message.payload.username, message.payload.message)
		Action_GameStarted:
			signal_lobby_game_started.emit()
		Action_Offer:
			web_rtc_peer.get_peer(message.payload.orgPeer).connection.set_remote_description("offer", message.payload.data)
		Action_Answer:
			web_rtc_peer.get_peer(message.payload.orgPeer).connection.set_remote_description("answer", message.payload.data)
		Action_Candidate:
			web_rtc_peer.get_peer(message.payload.orgPeer).connection.add_ice_candidate(message.payload.mid, message.payload.index, message.payload.sdp)


func _ws_send_action(action: String, payload: Dictionary = {}):
	if _is_web_socket_connected():
		var message = {
			"action": action,
			"payload": payload
		}
		var encoded_message: String = JSON.stringify(message)
		ws_peer.put_packet(encoded_message.to_utf8_buffer())

func _is_web_socket_connected() -> bool:
	if ws_peer:
		return ws_peer.get_ready_state() == WebSocketPeer.STATE_OPEN
	return false

func user_connect(username: String):
	if _is_web_socket_connected():
		return

	ws_peer = WebSocketPeer.new()	
	ws_peer.connect_to_url(WEB_SOCKET_SERVER_URL)
	if not username:
		current_username = generate_random_name()
	else:
		current_username = username
	set_process(true)

# TODO: This should wait for a response from the server to confirm validate
# Currently it still works because the server will boot connections that don't validate.
func user_confirm_connection():
	# TODO: Name this "CreateConnection" or something... change on backend...
	# TODO: Remove Username, Color, do a follow up to add those values (set user data)	
	_ws_send_action('Connect', {
		"secretKey" : WEB_SOCKET_SECRET_KEY, 
		"username" : current_username, 
		"color": ''
	})
	ws_connection_validated = true
	_ws_send_action(Action_GetUsers)
	_ws_send_action(Action_GetLobbies)
	
func user_disconnect():
	current_username = ''
	ws_connection_validated = false
	_ws_close_connection(1000, "User clicked disconnect")
	
	signal_user_list_changed.emit([])
	signal_lobby_list_changed.emit([])
	signal_lobby_own_info.emit(null)	
	signal_client_disconnected.emit()

func lobby_create():
	_ws_send_action(Action_CreateLobby)
	pass

func lobby_join(id: String):
	_ws_send_action(Action_JoinLobby, { "id" : id })

func lobby_leave():
	_ws_send_action(Action_LeaveLobby)

func lobby_get_own():
	_ws_send_action(Action_GetOwnLobby)

func lobby_start_game():
	_ws_send_action(Action_GameStarted)

func users_get():
	_ws_send_action(Action_GetUsers)

func lobbies_get():
	_ws_send_action(Action_GetLobbies)
	
func lobby_send_chat(message: String):
	if message.length():
		_ws_send_action(Action_MessageToLobby, { "message": message })

func generate_random_name():
	#@Emi's fantastic names 
	var Emi1: Array[String] = ['Re','Dar','Me','Su', 'Ven']
	var Emi2: Array[String] = ['ir','ton','me', 'so']
	var Emi3: Array[String] = ['tz','s','er', 'ky']
	var r1 = randi_range(0, Emi1.size() - 1)
	var r2 = randi_range(0, Emi2.size() - 1)
	var r3 = randi_range(0, Emi3.size() - 1)

	return Emi1[r1] + Emi2[r2] + Emi3[r3]
