extends Node

var player: PlayerCharacter
var health_system: HealthSystem

#var ammoToRefill = {
	#'GrenadeAmmo': 2,
	#'HeavyAmmo': 9,
	#'LightAmmo': 20,
	#'MediumAmmo': 30,
	#'RocketAmmo': 1,
	#'ShellAmmo': 20,
#}

# TODO: Remove.

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player = get_parent()
	#player.add_to_group("targets")
	health_system = player.get_node('HealthSystem')
	health_system.death.connect(_on_death)
	#if Hub.lobby_menu:
		#Hub.lobby_menu.signal_lobby_get_own.connect(_on_get_own_lobby)
	
func _on_death():
	#if Hub:
		#Hub.score_updated.emit(health_system.last_damage_source)
	player.set_collision_layer_value(2, false)
	player.set_collision_layer_value(16, true)
	player.immobile = true
	player.toggle_weapon_visible(false)	
	await get_tree().create_timer(5.0).timeout
	_respawn()
	
func _respawn():
	player.set_collision_layer_value(2, true)
	player.set_collision_layer_value(16, false)
	health_system.heal(health_system.max_health)
	health_system.respawn.emit()
	player.immobile = false
	player.position = Vector3(randi_range(-2, 2), 0.8, randi_range(-2, 2)) * 8
	player.toggle_weapon_visible(true)	
	
	#var linkToAmmoRefill = player.get_node("LinkComponent")
	#if linkToAmmoRefill != null:
		#linkToAmmoRefill.ammoRefillLink(ammoToRefill)

func _on_get_own_lobby(lobby):
	#print(lobby)
	for _player in lobby.players:
		# TODO: tiring to cast this so often...
		var _id = int(_player.id)
		#Hub.players[_id] = { 
			#'id': _id, 
				#'username': _player.username, 
			#'color': _player.color,
			#'score': 0
		#}
