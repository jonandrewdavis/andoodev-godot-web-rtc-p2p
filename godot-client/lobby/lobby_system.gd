extends Node

signal signal_user_connection_started
signal signal_user_connection_confirmed
signal signal_user_disconnected

signal signal_user_joined(peerId)
signal signal_user_left(peerId)
signal signal_user_list_updated(users)

signal signal_lobby_updated(lobbies)
signal signal_lobby_created
signal signal_lobby_joined
signal signal_lobby_left
signal signal_lobby_message
signal signal_lobby_game_started

#const WEB_SOCKET_SERVER_URL = 'ws://localhost:8787'
const WEB_SOCKET_SERVER_URL = 'wss://typescript-websockets-lobby.jonandrewdavis.workers.dev'
const WEB_SOCKET_SECRET_KEY = "9317e4d6-83b3-4188-94c4-353a2798d3c1"

const STUN_TURN_SERVER_URL = 'stun:stun.l.google.com:19302'

var wsPeer: WebSocketPeer 
var connection_validated = false
var current_username = ''

func _ready():
	set_process(false)
	tree_exited.connect(_ws_close_connections)

func _process(_delta):
	wsPeer.poll()	
	var state: WebSocketPeer.State = wsPeer.get_ready_state()
	match state:
		WebSocketPeer.STATE_CONNECTING:
			return
		WebSocketPeer.STATE_OPEN:
			# TODO: Improve initial user connect process and validation 
			if connection_validated == false:
				user_confirm_connection()
				return
			while wsPeer.get_available_packet_count():
				_ws_parse_packet()
		WebSocketPeer.STATE_CLOSING:
			# Keep polling to achieve proper close.
			pass
		WebSocketPeer.STATE_CLOSED:
			var code = wsPeer.get_close_code()
			var reason = wsPeer.get_close_reason()
			print("WebSocket closed with code: %d, reason %s. Clean: %s" % [code, reason, code != -1])
			signal_user_disconnected.emit()
			
func _ws_close_connections():
	if _is_web_socket_connected():
		wsPeer.close(1000, 'User closed the app')

func _ws_parse_packet():
	var packet = wsPeer.get_packet().get_string_from_utf8()
	var packet_to_json = JSON.parse_string(packet)
	if packet_to_json and packet_to_json.has('action') and packet_to_json.has('payload'):
		pass
	else:
		push_warning("Invalid message from server received")
		
func _ws_send_action(action : String, payload : Dictionary):
	if _is_web_socket_connected():
		var message = {
			"action": action,
			"payload": payload
		}
		var parsed_message = JSON.stringify(message)
		wsPeer.put_packet(parsed_message.to_utf8_buffer())	
		
func _is_web_socket_connected() -> bool:
	if wsPeer:
		return wsPeer.get_ready_state() == WebSocketPeer.STATE_OPEN
	return false

func user_connect(username: String):
	if _is_web_socket_connected():
		return

	wsPeer = WebSocketPeer.new()	
	wsPeer.connect_to_url(WEB_SOCKET_SERVER_URL)
	current_username = username
	set_process(true)

# TODO: This should 
func user_confirm_connection():
	_send_message(Action_Connect, {"secretKey" : WEB_SOCKET_SECRET_KEY, "username" : current_username, "color": current_chosen_color})
	connection_validated = true
	pass

func user_disconnect():
	pass

func lobby_create():
	pass

func lobby_join():
	pass
	
func lobby_leave():
	pass
	
