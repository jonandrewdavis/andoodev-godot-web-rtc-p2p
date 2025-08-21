extends Node3D

var player_scene_new = preload("res://game/PlayerCharacter/PlayerCharacterScene.tscn")

@export var player_container: Node3D

## TODO: 
# - Leaderboard
# - Name tags (killed by X messages)
# - Name above player
# - Color picker
# - Reload weapons while dead
# - In game chat (lobby messages)
# - Add Melee 
# - Add Sniper 
# - Nerf or change how jump works?
# - Document
# - Re-brand to AndooDev (on youtube?)


func _ready() -> void:
	multiplayer.connected_to_server.connect(RTCServerConnected)
	multiplayer.peer_connected.connect(RTCPeerConnected)
	multiplayer.peer_disconnected.connect(RTCPeerDisconnected)

	add_player_to_game(multiplayer.get_unique_id())

func RTCServerConnected():
	print("WORLD: rtc server connected")
	
func RTCPeerConnected(id: int):
	print("WORLD: rtc peer connected " + str(id))
	add_player_to_game(id)
	
func RTCPeerDisconnected(id):
	print("WORLD: rtc peer disconnected " + str(id))

func add_player_to_game(id: int):
	var has_id = id in player_container.get_children().map(func(node): int(node.name))
	if has_id == true:
		return

	var player_to_add = player_scene_new.instantiate()
	
	player_to_add.name = str(id)
	player_to_add.position = Vector3(randi_range(-2, 2), 0.8, randi_range(-2, 2)) * 10
	player_container.add_child(player_to_add, true)
