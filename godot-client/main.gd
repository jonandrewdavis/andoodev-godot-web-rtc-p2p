extends Node

var game_world = preload("res://game/world/world.tscn")

func _ready() -> void:
	# Game start signa
	LobbySystem.signal_network_create_new_peer_connection.connect(new_game_connection)

func new_game_connection(_id):
	# TODO: Improve. This is fragile.
	if get_node_or_null("World") == null:
		get_node("LobbyMenu").hide()
		var new_world = game_world.instantiate()
		add_child(new_world)
