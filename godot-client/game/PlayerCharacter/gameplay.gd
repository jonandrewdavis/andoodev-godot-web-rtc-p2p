extends Node

var player: PlayerCharacter
var health_system: HealthSystem
var world: World

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
	health_system = player.get_node('HealthSystem')
	health_system.death.connect(_on_death)
	
	world = get_tree().get_first_node_in_group('World')
	
	
func _on_death():
	player.set_collision_layer_value(2, false)
	player.set_collision_layer_value(16, true)
	player.immobile = true
	player.toggle_weapon_visible(false)	
	
	world.broadcast_player_death.rpc(player.name)
	world.broadcast_player_kill.rpc(str(health_system.last_damage_source))
	player.nameplate.visible = false

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
	player.nameplate.visible = true
	
	#var linkToAmmoRefill = player.get_node("LinkComponent")
	#if linkToAmmoRefill != null:
		#linkToAmmoRefill.ammoRefillLink(ammoToRefill)

# TODO: We could do updates of score on the websockets server
# But for traffic reduction, let's not do that right now
#func _on_get_own_lobby(lobby):
	#pass
	#print(lobby)
