extends Node3D

class_name World


signal signal_player_death(id)
signal signal_player_kill(id)

@onready var player_container = $PlayerContainer
@onready var object_container: Node3D = %ObjectContainer
@onready var object_spawner: MultiplayerSpawner = %ObjectSpawner

var player_scene = preload("res://game/PlayerCharacter/PlayerCharacterScene.tscn")
var box_scene = preload('res://game/Weapons/Misc/Scenes/HitableBoxScene.tscn')

## TODO: 
# - Reload weapons while dead
# - Log messages in-game (killed by X messages)? (upper right corner)
# - Add Melee 
# - Nerf or change how jump works?
# - Disconnect button hide/show game world. unmount world, show

func _ready() -> void:
	add_to_group('World')
	LobbySystem.add_player_to_game(multiplayer.get_unique_id())
	
	if LobbySystem.host == str(multiplayer.get_unique_id()): 
		await get_tree().create_timer(2.0).timeout
		set_auth.rpc()

@rpc("any_peer", 'call_local', 'reliable')
func broadcast_player_death(id: String):
	signal_player_death.emit(id)
	
@rpc("any_peer", 'call_local', 'reliable')
func broadcast_player_kill(id: String):
	signal_player_kill.emit(id)


func add_player_to_world(peer_id: int):
	var new_player: PlayerCharacter = player_scene.instantiate()
	new_player.name = str(peer_id)
	new_player.position = Vector3(randi_range(-2, 2), 0.8, randi_range(-2, 2)) * 10
	player_container.add_child(new_player, true)

@rpc("any_peer", 'call_local', 'reliable')
func set_auth():
	object_spawner.set_multiplayer_authority(multiplayer.get_remote_sender_id())
	object_container.set_multiplayer_authority(multiplayer.get_remote_sender_id())
	spawn_boxes()

func spawn_boxes():
	if str(object_spawner.get_multiplayer_authority()) == LobbySystem.host:
		for i in 8:
			var new_box = box_scene.instantiate()
			new_box.position = Vector3(randf_range(30.0, 18.0), 3.0, randf_range(-18.0, -30.0))
			object_container.add_child(new_box, true)
