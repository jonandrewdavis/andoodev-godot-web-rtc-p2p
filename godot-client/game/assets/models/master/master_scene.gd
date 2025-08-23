extends Node3D

class_name Master

@export var animation_player: AnimationPlayer
@export var bones: PhysicalBoneSimulator3D
@onready var player: PlayerCharacter = get_parent()

var _player_input: PlayerInput


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if LobbySystem:
		LobbySystem.signal_lobby_own_info.connect(_on_get_own_lobby)

	if not is_multiplayer_authority():
		set_process(false)
		set_physics_process(false)
	
	if is_multiplayer_authority():
		cast_shadow_only()

	_player_input = player.player_input
	player.health_system.death.connect(func(): _on_master_death.rpc())
	player.health_system.respawn.connect(func(): _on_master_respawn.rpc())
	
	#weapon_manager.player = player
	#weapon_manager.player_input = player.player_input

	if not animation_player:
		animation_player = $AnimationPlayer
	$AnimationPlayer.speed_scale = 1
	$AnimationPlayer.playback_default_blend_time = 0.2
	
	if player.look_at_target.get_path():
		$Armature/GeneralSkeleton/RightLower.target_node = player.look_at_target.get_path()
		$Armature/GeneralSkeleton/LeftLower.target_node = player.look_at_target.get_path()
		$Armature/GeneralSkeleton/LeftUpper.target_node = player.look_at_target.get_path()
		$Armature/GeneralSkeleton/RightHand.target_node = player.look_at_target.get_path()
		$Armature/GeneralSkeleton/LeftHand.target_node = player.look_at_target.get_path()

func set_mesh_color(new_color: Color):
	var mesh_material: StandardMaterial3D = %vanguard_Mesh.get_active_material(0)
	var new_mat = mesh_material.duplicate() 
	new_mat.albedo_color = new_color
	%vanguard_Mesh.set_surface_override_material(0, new_mat)

func cast_shadow_only():
	%vanguard_Mesh.cast_shadow = 3
	%vanguard_visor.cast_shadow = 3

func _process(_delta):
	on_animation_check()

@rpc('call_local', 'reliable')
func _on_master_death():
	bones.physical_bones_start_simulation()
	animation_player.active = false
	if is_multiplayer_authority():
		%vanguard_Mesh.cast_shadow = 1
		%vanguard_visor.cast_shadow = 1

@rpc('call_local', 'reliable')
func _on_master_respawn():
	bones.physical_bones_stop_simulation()
	animation_player.active = true
	if is_multiplayer_authority():
		%vanguard_Mesh.cast_shadow = 3
		%vanguard_visor.cast_shadow = 3

func _on_get_own_lobby(lobby):
	for _this_player in lobby.players:
		if _this_player.id == player.name:
			var _color: Color = Color.from_string(_this_player.color, Color.BLUE)
			set_mesh_color(_color)

# Set up a map. This could be better, but it works for now
#  
# Use CSS rules for: Left, Up, Right, Down as if on a D-PAD
# Visualize the 0, 1 indexing in this order
#   U
# L + R
#   D
#
# Forward: 0 
# Backwards: 1
#
# Left: 0
# Right: 1

const ANIMATION_PREFIX = 'master_3/'
# TODO: These are all named pretty well... is this necessary?
# THEORY: could assign each of: run, left, to enums. then combine them. it would 
# almost be a numerical value, that would then look up the strings. like 0, 1, 01 10
# Then, a var like forward would equate to the -y or +y, returning bool... matching "run", or "walk" (0, 1)
# That would make the on_animation_check super small.

const MOVES = { 
	'STRAFE': {
		'FAST': ["run left", "run right", ],
		'SLOW': ["walk left", "walk right", ],
		'CROUCH': [ "walk crouching left", "walk crouching right",],
	},
	'WALK': {
		'FAST': ["run forward", "run backward",],
		'SLOW': ["walk forward", "walk backward",],
		'CROUCH': ["walk crouching forward", "walk crouching backward"],
	},
	'DIAGONAL': { 
		'FAST': ["run forward left", "run forward right", "run backward left", "run backward right"], # 0, 1, 2, 3
		'SLOW': ["walk forward left", "walk forward right", "walk backward left", "walk backward right"], # 0, 1, 2, 3
		'CROUCH': ["walk crouching forward", "walk crouching backward"],
	}
}

enum INPUT { 
	STRAFE,
	WALK,
	DIAGONAL,
}

enum SPEED { 
	FAST,
	SLOW,
	CROUCH,
}

enum DIR { 
	POS, # forward, or left - 0
 	NEG, # backwards, or right - 0
}


func _play(animation_name):
	%AnimationPlayer.play(ANIMATION_PREFIX + animation_name)

# normal
# crouching
# sprinting
func on_animation_check():
	var _dir = _player_input.input_dir
	var _slowed = _player_input.is_weapon_aim or _player_input.is_crouching
	
	#if player.is_on_floor() == false: 
		#_play('jump loop')
		#return
	animation_player.speed_scale = 1.0
	match player.stateMachine.currStateName:
		(&'Jump'):
			_play('jump loop')
		(&'Inair'):
			_play('jump loop')
		(&'Idle'):
			if _dir.y == 0.0 and _dir.x == 0.0:
				_play('idle aiming')
		(&'Walk'):
			if _dir.y == 0.0 and _dir.x == 0.0:
				_play('idle aiming')
			elif _dir.y == 0:
				# Strafe (no input forward or backwards)
				if _dir.x < -0.4: _play(MOVES.STRAFE.SLOW[0])
				elif _dir.x > 0.4: _play(MOVES.STRAFE.SLOW[1])
			elif _dir.y < 0.0: 
				# Forward
				if _dir.x < -0.4: _play(MOVES.DIAGONAL.SLOW[0])
				elif _dir.x > 0.4: _play(MOVES.DIAGONAL.SLOW[1])
				else: _play(MOVES.WALK.SLOW[0])
			elif _dir.y > 0.0:
				# Backwards
				if _dir.x < -0.4: _play(MOVES.DIAGONAL.SLOW[2])
				elif _dir.x > 0.4: _play(MOVES.DIAGONAL.SLOW[3])
				else: _play(MOVES.WALK.SLOW[1])
		(&'Run'):
			animation_player.speed_scale = 0.7
			if _dir.y == 0.0 and _dir.x == 0.0:
				_play('idle aiming')
			elif _dir.y == 0:
				# Strafe (no input forward or backwards)
				if _dir.x < -0.4: _play(MOVES.STRAFE.FAST[0])
				elif _dir.x > 0.4: _play(MOVES.STRAFE.FAST[1])
			elif _dir.y < 0.0: 
				# Forward
				if _dir.x < -0.4: _play(MOVES.DIAGONAL.FAST[0])
				elif _dir.x > 0.4: _play(MOVES.DIAGONAL.FAST[1])
				else: _play(MOVES.WALK.FAST[0])
			elif _dir.y > 0.0:
				# Backwards
				if _dir.x < -0.4: _play(MOVES.DIAGONAL.FAST[2])
				elif _dir.x > 0.4: _play(MOVES.DIAGONAL.FAST[3]) 
				else: _play(MOVES.WALK.FAST[1])
		(&'Crouch'):
			animation_player.speed_scale = 0.7
			if _dir.y == 0.0 and _dir.x == 0.0:
				_play('idle crouching aiming')
			elif _dir.y == 0:
				# Strafe (no input forward or backwards)
				if _dir.x < -0.4: _play(MOVES.STRAFE.CROUCH[0])
				elif _dir.x > 0.4: _play(MOVES.STRAFE.CROUCH[1])
			elif _dir.y < 0.0: 
				# Forward
				if _dir.x < -0.4: _play(MOVES.DIAGONAL.CROUCH[0])
				elif _dir.x > 0.4: _play(MOVES.DIAGONAL.CROUCH[1])
				else: _play(MOVES.WALK.CROUCH[0])
			elif _dir.y > 0.0:
				# Backwards
				_play(MOVES.WALK.CROUCH[1])


		#(&'crouching'):
			#print("param3 is not 3!")
		#(&'sprinting'):
#
		#if _dir.y == 0.0 and _dir.x == 0.0:
			#if _crouching:
				#%AnimationPlayer.play(ANIMATION_PREFIX + 'idle crouching aiming')
			#else: 
				#%AnimationPlayer.play(ANIMATION_PREFIX + 'idle aiming')
			#return 
		## TODO: Refactor due to adding crouching
		#if _dir.y == 0:
			#if _slowed:
				#if _crouching:
					#if _dir.x < -0.4: %AnimationPlayer.play(MOVES.STRAFE.CROUCH[1])
					#if _dir.x > 0.4: %AnimationPlayer.play(MOVES.STRAFE.CROUCH[0])
				#else:
					#if _dir.x < -0.4: 
						#%AnimationPlayer.play(MOVES.STRAFE.SLOW[1])
						#%AnimationPlayer.speed_scale = 1.2 # Slow strafe left is too fast.
					#if _dir.x > 0.4:%AnimationPlayer.play(MOVES.STRAFE.SLOW[0])
			#else:
				#if _dir.x < -0.4: %AnimationPlayer.play(MOVES.STRAFE.FAST[1])
				#if _dir.x > 0.4:%AnimationPlayer.play(MOVES.STRAFE.FAST[0])				
		#else:
			#if _slowed:
				#if _crouching:
					#if _dir.y < -0.4: %AnimationPlayer.play(MOVES.WALK.CROUCH[1])
					#if _dir.y > 0.4:%AnimationPlayer.play(MOVES.WALK.CROUCH[0])	
				#else:
					#if _dir.y < -0.4: %AnimationPlayer.play(MOVES.WALK.SLOW[1])
					#if _dir.y > 0.4:%AnimationPlayer.play(MOVES.WALK.SLOW[0])
			#else:
				#if _dir.y < 0.0: 
					##if player_input.run_input and _dir.x == 0.0:
						##%AnimationPlayer.play(ANIMATION_PREFIX + 'sprint forward')
					##else:
					#if _dir.x < -0.4:
						#%AnimationPlayer.play(ANIMATION_PREFIX + 'run forward left')
					#elif _dir.x > 0.4:
						#%AnimationPlayer.play(ANIMATION_PREFIX + 'run forward right')
					#else:
						#%AnimationPlayer.play(MOVES.WALK.FAST[1])
						#
				 ## No running backwards
				## TODO: Slow factor even more if backwards + aiming?
				#if _dir.y > 0: 
					#%AnimationPlayer.speed_scale = 1.2
					#await get_tree().process_frame
					#%AnimationPlayer.play(MOVES.WALK.SLOW[0])
