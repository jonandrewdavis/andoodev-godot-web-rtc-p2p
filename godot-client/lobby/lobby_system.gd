extends Node

signal signal_client_connection_started
signal signal_client_connection_confirmed(id)
signal signal_client_disconnected

signal signal_user_joined(id)
signal signal_user_left(id)
signal signal_user_list_changed(users)

signal signal_lobby_created(lobby)
signal signal_lobby_joined(lobby)
signal signal_lobby_list_changed(lobbies)
signal signal_lobby_chat(chat_user, chat_text)
signal signal_lobby_changed(lobby)
signal signal_lobby_own_info(lobby)
signal signal_lobby_game_started(lobby)
signal signal_lobby_get_kicked
signal signal_lobby_event(message)

signal signal_network_create_new_peer_connection(id)
signal signal_packet_parsed(message)
signal signal_set_ice_servers(ice_servers)

# TODO: more "game" prefixed signals? Maybe game started is in here. Maybe 'match' too? "session"?
signal signal_game_connections_started # Not emitted yet
signal signal_game_connections_finished
signal signal_game_ended # Not used

enum ACTION {
	Confirm,
	GetUsers,
	PlayerJoin,
	PlayerLeft,
	GetLobbies,
	GetOwnLobby,
	CreateLobby,
	JoinLobby,
	LeaveLobby,
	LobbyChanged,
	GameStarted,
	MessageToLobby,
	PlayerInfoUpdate,
	# WebRTC Actions: 
	NewPeerConnection,
	Offer,
	Answer,
	Candidate,
	KickPlayer,
	LobbyEvent,
	SetIceServers,
}

#const WEB_SOCKET_SERVER_URL = 'ws://localhost:8787'
const WEB_SOCKET_SERVER_URL = 'wss://typescript-websockets-lobby.jonandrewdavis.workers.dev'
const WEB_SOCKET_SECRET_KEY = "9317e4d6-83b3-4188-94c4-353a2798d3c1"
#NOTE: Not an actual secret. Just to prevent random connections, but change if you self host

# Patterned [stun:URI, turn:URI], for default to free unlimited STUN
var STUN_TURN_SERVER_URLS = ['stun:stun.cloudflare.com']
# This will be overwritten by a SetIceServer event from server if turn is set up in Cloudflare
var ICE_SERVERS = null

var web_rtc_peer: WebRTCMultiplayerPeer

var ws_peer: WebSocketPeer
var ws_peer_id: String
var ws_connection_validated = false

var current_username = ''
var turn_server_enabled = false
var current_lobby = null
var use_mesh = false


func _ready():
	set_process(false)
	signal_client_connection_confirmed.connect(_network_create_multiplayer_peer)
	signal_network_create_new_peer_connection.connect(_network_create_new_peer_connection)
	if turn_server_enabled:
		signal_set_ice_servers.connect(_network_update_ice_servers)
	tree_exited.connect(_ws_close_connection)

	signal_lobby_game_started.connect(_listen_for_connections_finished)
	signal_lobby_game_started.connect(_listen_for_connections_finished_cancel)
	
	if use_mesh == false:
		signal_lobby_created.connect(_network_create_new_server)
		signal_lobby_joined.connect(_network_create_new_client)
	
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

# TODO: I think this match statement could be made more straightforward.
# TODO: Error handling (involves server refactor)
func _ws_process_packet(message):
	var string_enum = ACTION.keys().find(message.action)
	match (string_enum):
		ACTION.Confirm:
			if message.payload.has("webId"):
				signal_client_connection_confirmed.emit(message.payload.webId)
			else:
				_ws_close_connection(1000, "Couldn't authenticate")
		ACTION.GetUsers:
			if message.payload.has("users"):
				signal_user_list_changed.emit(message.payload.users)
			else:
				signal_user_list_changed.emit([])
		ACTION.GetLobbies:
			if message.payload.has("lobbies"):
				signal_lobby_list_changed.emit(message.payload.lobbies)
			else:
				signal_lobby_list_changed.emit([])
		# TODO: Remove / change GetOwnLobby signals and use join/leave/changed
		ACTION.CreateLobby:
			if message.payload.has("lobby"):
				signal_lobby_created.emit(message.payload.lobby)
		ACTION.JoinLobby:
			if message.payload.has("lobby"):
				signal_lobby_joined.emit(message.payload.lobby)
			else:
				# NOTE: message.payload: { "success": false }
				signal_lobby_joined.emit(null)
		ACTION.LobbyChanged:
			if message.payload.has("lobby"):
				signal_lobby_changed.emit(message.payload.lobby)
			else:
				signal_lobby_changed.emit(null)
		ACTION.GetOwnLobby:
			if message.payload.has("lobby"):
				signal_lobby_own_info.emit(message.payload.lobby)
			else:
				signal_lobby_own_info.emit(null)
		ACTION.PlayerJoin:
			if message.payload.has("id"):
				signal_user_joined.emit(message.payload.id)
		ACTION.PlayerLeft:
			if message.payload.has("webId"):
				signal_user_left.emit(message.payload.webId)
		ACTION.MessageToLobby:
			if message.payload.has("message"): # TODO: "chat_text" ?
				signal_lobby_chat.emit(message.payload.username, message.payload.message)
		ACTION.GameStarted:
			signal_lobby_game_started.emit(message.payload.lobby)
		ACTION.NewPeerConnection:
			if message.payload.has("id"):
				signal_network_create_new_peer_connection.emit(int(message.payload.id))
		ACTION.Offer:
			web_rtc_peer.get_peer(int(message.payload.orgPeer)).connection.set_remote_description("offer", message.payload.data)
		ACTION.Answer:
			web_rtc_peer.get_peer(int(message.payload.orgPeer)).connection.set_remote_description("answer", message.payload.data)
		ACTION.Candidate:
			web_rtc_peer.get_peer(int(message.payload.orgPeer)).connection.add_ice_candidate(message.payload.mid, message.payload.index, message.payload.sdp)
		ACTION.KickPlayer:
			signal_lobby_get_kicked.emit()
		ACTION.LobbyEvent:
			signal_lobby_event.emit(message.payload.message)
		ACTION.SetIceServers:
			signal_set_ice_servers.emit(message.payload)

func _ws_send_action(action: ACTION, payload: Dictionary = {}):
	if _is_web_socket_connected():
		var message = {
			"action": ACTION.keys()[action],
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
	_ws_send_action(ACTION.Confirm, {
		"secretKey": WEB_SOCKET_SECRET_KEY,
		"username": current_username,
	})
	ws_connection_validated = true
	_ws_send_action(ACTION.GetUsers)
	_ws_send_action(ACTION.GetLobbies)
	
func user_disconnect():
	current_username = ''
	ws_connection_validated = false
	_ws_close_connection(1000, "User clicked disconnect")
	
	signal_user_list_changed.emit([])
	signal_lobby_list_changed.emit([])
	signal_lobby_changed.emit([])
	signal_client_disconnected.emit()
	

func lobby_create():
	_ws_send_action(ACTION.CreateLobby)



func lobby_join(id: String):
	_ws_send_action(ACTION.JoinLobby, {"id": id})

func lobby_leave():
	_ws_send_action(ACTION.LeaveLobby)

func lobby_get_own():
	_ws_send_action(ACTION.GetOwnLobby)

func lobby_start_game():
	_ws_send_action(ACTION.GameStarted)

func users_get():
	_ws_send_action(ACTION.GetUsers)

func lobbies_get():
	_ws_send_action(ACTION.GetLobbies)
	
func lobby_send_chat(message: String):
	if message.length():
		_ws_send_action(ACTION.MessageToLobby, {"message": message})

func user_update_info(metadata: Variant):
	_ws_send_action(ACTION.PlayerInfoUpdate, {"metadata": metadata})

func lobby_update_data(lobbyData: Variant):
	_ws_send_action(ACTION.LobbyChanged, {"lobbyData": lobbyData})

func lobby_kick(id: String):
	_ws_send_action(ACTION.KickPlayer, {"id": id})

func lobby_create_private():
	_ws_send_action(ACTION.CreateLobby, { 'isPublic': false })

#region WebRTCMultiplayerPeer

func _network_create_multiplayer_peer(id: String):
	ws_peer_id = id
	if use_mesh:
		web_rtc_peer = WebRTCMultiplayerPeer.new()
		web_rtc_peer.create_mesh(int(ws_peer_id))	
		multiplayer.multiplayer_peer = web_rtc_peer
		
		# NOTE: We now have a multiplayer peer, connect signals
		multiplayer.peer_connected.connect(add_player_to_game)
		multiplayer.peer_disconnected.connect(remove_player_from_game)


# TODO: Server must see the host & send 1 for them in the data
func _network_create_new_peer_connection(id: int):
	if id == int(current_lobby.players[0].id):
		var new_peer_connection: WebRTCPeerConnection = WebRTCPeerConnection.new()
		
		# If the SetIceServers event didn't occur, we might need to use the default
		if ICE_SERVERS == null: 
			ICE_SERVERS = {"iceServers": [ {"urls": STUN_TURN_SERVER_URLS}]}
		
		new_peer_connection.initialize(ICE_SERVERS)
		print("binding id " + str(1) + " my id is " + str(ws_peer_id))

		new_peer_connection.session_description_created.connect(self._offerCreated.bind(1))
		new_peer_connection.ice_candidate_created.connect(self._iceCandidateCreated.bind(1))
		web_rtc_peer.add_peer(new_peer_connection, 1)
		if id < web_rtc_peer.get_unique_id():
			new_peer_connection.create_offer()
		return

	if id != int(ws_peer_id):
		var new_peer_connection: WebRTCPeerConnection = WebRTCPeerConnection.new()
		
		# If the SetIceServers event didn't occur, we might need to use the default
		if ICE_SERVERS == null: 
			ICE_SERVERS = {"iceServers": [ {"urls": STUN_TURN_SERVER_URLS}]}
		
		new_peer_connection.initialize(ICE_SERVERS)
		print("binding id " + str(id) + " my id is " + str(ws_peer_id))

		new_peer_connection.session_description_created.connect(self._offerCreated.bind(id))
		new_peer_connection.ice_candidate_created.connect(self._iceCandidateCreated.bind(id))
		web_rtc_peer.add_peer(new_peer_connection, id)
		if id < web_rtc_peer.get_unique_id():
			new_peer_connection.create_offer()

func _offerCreated(type, data, id: int):
	var tid = id if id == current_lobby.players[0].id else 1

	if !web_rtc_peer.has_peer(id):
		return
		
	web_rtc_peer.get_peer(tid).connection.set_local_description(type, data)
	
	if type == "offer":
		_sendOffer(id, data)
	else:
		_sendAnswer(id, data)

func _is_host() -> bool:
	return ws_peer_id == current_lobby.players[0].id

func _sendOffer(id: int, data):
	var org = ws_peer_id if ws_peer_id == current_lobby.players[0].id else str(1) 
	var tid = id if id == current_lobby.players[0].id else 1
	var message = {
		"peer": tid, 
		"orgPeer": org,
		"data": data,
	}
	_ws_send_action(ACTION.Offer, message)

func _sendAnswer(id: int, data):
	var org = ws_peer_id if ws_peer_id == current_lobby.players[0].id else str(1) 
	var tid = id if id == current_lobby.players[0].id else 1
	var message = {
		"peer": tid,
		"orgPeer": org,
		"data": data,
	}
	_ws_send_action(ACTION.Answer, message)

func _iceCandidateCreated(midName, indexName, sdpName, id: int):
	var org = ws_peer_id if ws_peer_id == current_lobby.players[0].id else str(1) 
	var tid = id if id == current_lobby.players[0].id else 1
	var message = {
		"peer": tid,
		"orgPeer": org,
		"mid": midName,
		"index": indexName,
		"sdp": sdpName,
	}
	_ws_send_action(ACTION.Candidate, message)

func _network_update_ice_servers(ice_servers):
	ICE_SERVERS = ice_servers

#endregion

var should_cancel_connections = false

func _listen_for_connections_finished(lobby):

	signal_client_connection_started.emit()
	if should_cancel_connections == true:
		return
	
	if multiplayer == null or _is_web_socket_connected() == false:
		return

	await get_tree().create_timer(1.0).timeout
	if lobby.players.size() == multiplayer.get_peers().size() + 1: # add 1 to count ourselves as a peer
		signal_game_connections_finished.emit()
	else: 
		# keep trying
		print('trying')
		_listen_for_connections_finished(lobby)

# give up after 15 seconds
func _listen_for_connections_finished_cancel(_lobby):
	await get_tree().create_timer(15.0).timeout
	should_cancel_connections = true
	# TODO: optionally disconnect & send back to lobby.
	

func generate_random_name():
	#@Emi's fantastic names 
	var Emi1: Array[String] = ['Re', 'Dar', 'Me', 'Su', 'Ven']
	var Emi2: Array[String] = ['ir', 'ton', 'me', 'so']
	var Emi3: Array[String] = ['tz', 's', 'er', 'ky']
	var r1 = randi_range(0, Emi1.size() - 1)
	var r2 = randi_range(0, Emi2.size() - 1)
	var r3 = randi_range(0, Emi3.size() - 1)

	return Emi1[r1] + Emi2[r2] + Emi3[r3]


func add_player_to_game(id: int):
	var has_id = id in get_tree().get_nodes_in_group('Players').map(func(node): int(node.name))
	if has_id == true:
		return

	var world: World = get_tree().get_first_node_in_group('World')
	world.add_player_to_world(id)
	
func remove_player_from_game(id: int):
	var players: Array[Node] = get_tree().get_nodes_in_group('Players')
	var player_to_remove = players.find_custom(func(item): return item.name == str(id))
	if player_to_remove != -1:
		players[player_to_remove].queue_free()

func _network_create_new_server(lobby):
	current_lobby = lobby

	web_rtc_peer = WebRTCMultiplayerPeer.new()
	web_rtc_peer.create_server()
	multiplayer.multiplayer_peer = web_rtc_peer
	
	# NOTE: We now have a multiplayer peer, connect signals
	multiplayer.peer_connected.connect(add_player_to_game)
	multiplayer.peer_disconnected.connect(remove_player_from_game)

func _network_create_new_client(lobby):
	current_lobby = lobby

	web_rtc_peer = WebRTCMultiplayerPeer.new()
	web_rtc_peer.create_client(int(ws_peer_id))
	multiplayer.multiplayer_peer = web_rtc_peer
	
	# NOTE: We now have a multiplayer peer, connect signals
	multiplayer.peer_connected.connect(add_player_to_game)
	multiplayer.peer_disconnected.connect(remove_player_from_game)
