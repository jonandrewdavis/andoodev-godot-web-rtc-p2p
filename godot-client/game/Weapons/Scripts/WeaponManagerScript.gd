extends Node3D

class_name WeaponManager

var weaponStack : Array[int] = [] #weapons current wielded by play char
var weaponList : Dictionary = {} #all weapons available in the game (key = weapon name, value = wepakn resource)
@export var weaponResources : Array[WeaponResourceNew] #all weapon resources files
@export var startWeapons : Array[WeaponSlotNew] #the weapon the player character will start with

var cW = null #current weapon
var cWM = null #current weapon model

# NOTE: added export for multiplayer
@export var weaponIndex : int = 0

#weapon changes variables
var canChangeWeapons : bool = true
var canUseWeapon : bool = true

#reload variable
var hasToCancelReload : bool = false

var rng = RandomNumberGenerator.new()

@export_group("Keybind variables")
@export var shoot_action : String
@export var reload_action : String
@export var weapon_wheel_up_action : String
@export var weapon_wheel_down_action : String

@onready var playChar : PlayerCharacter = $"../../../.."
@onready var cameraHolder : Node3D = %CameraHolder
@onready var cameraRecoilHolder : Node3D = %CameraRecoilHolder
@onready var camera : Camera3D = %Camera
@onready var weaponContainer : Node3D = %WeaponContainer
@onready var shootManager : Node3D = %ShootManager
@onready var reloadManager : Node3D = %ReloadManager
@onready var ammoManager : Node3D = %AmmunitionManager
@onready var animPlayer : AnimationPlayer = %AnimationPlayer
@onready var animManager : Node3D = %AnimationManager
@onready var audioManager : PackedScene = preload("res://game/Weapons/Misc/Scenes/AudioManagerScene.tscn")
@onready var bulletDecal : PackedScene = preload("res://game/Weapons/Misc/Scenes/BulletDecalScene.tscn")
#@onready var hud : CanvasLayer = %HUD
#@onready var linkComponent : Node3D = %LinkComponent

func _ready():
	if is_multiplayer_authority():
		initialize()

func initialize():
	for weapon in weaponResources:
		#create dict to refer weapons
		weaponList[weapon.weaponId] = weapon
		
	for weapo in weaponList.keys():
		#weaponsEmplacements[weapo] = weaponIndex
		cW = weaponList[weapo] #set each weapon to current, to acess properties useful to set up animations slicing and select correct weapon slot
		
		for weaponSlot in weaponContainer.get_children():
			if weaponSlot.weaponId == cW.weaponId: #id correspondant
				
				#if weapon is in the predetermined start weapons list
				for startWeapon in startWeapons:
					if startWeapon.weaponId == cW.weaponId: 
						weaponStack.append(cW.weaponId)
						
				cW.weSl = weaponSlot #get weapon slot script ref from weapon list (allows to get access to model, attack point, ...)
				cWM = cW.weSl.model
				cWM.visible = false
				
				#if is_multiplayer_authority():
				forceAttackPointTransformValues(cW.weSl.attackPoint)
				cW.bobPos = cW.position
				
	if weaponStack.size() > 0:
		#enable (equip and set up) the first weapon on the weapon stack
		enterWeapon(weaponStack[0])
		
func exitWeapon(nextWeapon : int):
	#this function manage the first part of the weapon switching mechanic
	#in this part, the current weapon is disabled (unequiped and taked down)
	if nextWeapon != cW.weaponId:
		canChangeWeapons = false
		canUseWeapon = false
		if cW.canShoot: cW.canShoot = false
		if cW.canReload: cW.canReload = false
		
		if cW.unequipAnimName != "":
			animManager.playModelAnimation("UnequipAnim%s" % cW.weaponName, cW.unequipAnimSpeed, false)
		await get_tree().create_timer(cW.unequipTime).timeout
		
		cWM.visible = false
		
		enterWeapon(nextWeapon)
	
func enterWeapon(nextWeapon : int):
	#this function manage the second part of the weapon switching mechanic
	#in this part, the next weapon is enabled (equiped and set up)
	cW = weaponList[nextWeapon]
	nextWeapon = 0
	cWM = cW.weSl.model
	cWM.visible = true
	
	
	shootManager.getCurrentWeapon(cW)
	reloadManager.getCurrentWeapon(cW)
	animManager.getCurrentWeapon(cW, cWM)
	
	weaponSoundManagement(cW.equipSound, cW.equipSoundSpeed)
	
	animPlayer.playback_default_blend_time = cW.animBlendTime
	
	if cW.equipAnimName != "":
		animManager.playModelAnimation("EquipAnim%s" % cW.weaponName, cW.equipAnimSpeed, false)
	await get_tree().create_timer(cW.equipTime).timeout
	
	if !cW.canShoot: cW.canShoot = true
	if !cW.canReload: cW.canReload = true
	canUseWeapon = true
	canChangeWeapons = true
	
func _process(_delta : float):
	if cW != null and cWM != null and canUseWeapon:
		weaponInputs()
		reloadManager.autoReload()
		
	displayStats()
	
#func weaponInputs():
	#if Input.is_action_pressed(shoot_action): shootManager.shoot()
			#
	#if Input.is_action_just_pressed(reload_action): reloadManager.reload()
	#
	#if Input.is_action_just_pressed(weapon_wheel_up_action):
		#if canChangeWeapons and cW.canShoot and cW.canReload:
			#weaponIndex = min(weaponIndex + 1, weaponStack.size() - 1) #from first element of weapon stack to last element 
			#changeWeapon(weaponStack[weaponIndex])
			#
	#if Input.is_action_just_pressed(weapon_wheel_down_action):
		#if canChangeWeapons and cW.canShoot and cW.canReload:
			#weaponIndex = max(weaponIndex - 1, 0) #from last element of weapon stack to first element 
			#changeWeapon(weaponStack[weaponIndex])
		
func weaponInputs():
	if playChar.player_input.is_weapon_shoot: shootManager.shoot()
	if playChar.player_input.is_weapon_reload: reloadManager.reload()
	
	if playChar.player_input.is_weapon_down:
		if canChangeWeapons and cW.canShoot and cW.canReload:
			weaponIndex = min(weaponIndex + 1, weaponStack.size() - 1) #from first element of weapon stack to last element 
			changeWeapon(weaponStack[weaponIndex])
			
	if playChar.player_input.is_weapon_up:
		if canChangeWeapons and cW.canShoot and cW.canReload:
			weaponIndex = max(weaponIndex - 1, 0) #from last element of weapon stack to first element 
			changeWeapon(weaponStack[weaponIndex])

func displayStats():
	#hud.displayWeaponStack(weaponStack.size())
	playChar.player_ui.displayWeaponName(cW.weaponName)
	playChar.player_ui.displayTotalAmmoInMag(cW.totalAmmoInMag, cW.nbProjShotsAtSameTime)
	playChar.player_ui.displayTotalAmmo(ammoManager.ammoDict[cW.ammoType], cW.nbProjShotsAtSameTime)

func changeWeapon(nextWeapon : int):
	if canChangeWeapons and cW.canShoot and cW.canReload:
		exitWeapon(nextWeapon)
	else:
		push_error("Can't change weapon now")
		return 
	
func displayMuzzleFlash():
	%MuzzleFlash.global_position = cW.weSl.muzzleFlashSpawner.global_position
	%MuzzleFlash.flash()
	# NOTE: edited.
	pass

	# TODO: Disabled. Renable?	
	#create a muzzle flash instance, and display it at the indicated point
	#if cW.muzzleFlashRef != null:
		#var muzzleFlashInstance = cW.muzzleFlashRef.instantiate()
		#add_child(muzzleFlashInstance)
		#muzzleFlashInstance.global_position = cW.weSl.muzzleFlashSpawner.global_position
		#muzzleFlashInstance.emitting = true
	#else:
		#push_error("%s doesn't have a muzzle flash reference" % cW.weaponName)
		#return
		
func displayBulletHole(colliderPoint : Vector3, colliderNormal : Vector3):
	#pass
	add_new_decal.rpc(colliderPoint, colliderNormal)
	#Hub.projectile_system.add_new_decal.rpc(colliderPoint, colliderNormal)


@rpc('any_peer', 'call_local')
func add_new_decal(colliderPoint : Vector3, colliderNormal : Vector3):
	if colliderNormal == Vector3.ZERO:
		return
		
	var bulletDecalInstance = bulletDecal.instantiate()
	bulletDecalInstance.position = colliderPoint + (Vector3(colliderNormal) * 0.001)
	get_tree().get_root().add_child(bulletDecalInstance)
	
	if !colliderNormal.is_equal_approx(Vector3.UP):
		bulletDecalInstance.look_at(colliderPoint - colliderNormal  * 0.01, Vector3.UP)
		bulletDecalInstance.get_node('Sprite3D').axis = 2
	else:
		bulletDecalInstance.get_node('Sprite3D').axis = 1

	# NOTE: Moved to projectiles system to spawn.  
	
	#var bulletDecalInstance = bulletDecal.instantiate()
	#get_tree().get_root().add_child(bulletDecalInstance)
	#bulletDecalInstance.global_position = colliderPoint + (Vector3(colliderNormal) * 0.001)
	#if !colliderNormal.is_equal_approx(Vector3.UP):
		#bulletDecalInstance.look_at(colliderPoint - colliderNormal  * 0.01, Vector3.UP)
		#bulletDecalInstance.get_node('Sprite3D').axis = 2
	#else:
		#bulletDecalInstance.get_node('Sprite3D').axis = 1

	
func weaponSoundManagement(soundName : AudioStream, soundSpeed : float):
	if soundName: 
		var audioIns : AudioStreamPlayer3D = audioManager.instantiate()
		add_child.call_deferred(audioIns)
		call_remote_sound.rpc(soundName.resource_path, soundSpeed)
		await get_tree().process_frame
		if audioIns.is_inside_tree():
			audioIns.global_transform = cW.weSl.attackPoint.global_transform
			audioIns.pitch_scale = soundSpeed
			audioIns.stream = soundName
			audioIns.play()
		else:
			print("The sound can't be played, AudioStreamPlayer3D instance is not in the scene tree")

@rpc('call_remote', 'reliable')
func call_remote_sound(soundName : String, soundSpeed : float):
	var audioIns : AudioStreamPlayer3D = audioManager.instantiate()
	var newStream = AudioStreamMP3.load_from_file(soundName)
	add_child.call_deferred(audioIns)
	#makes sure the node is in the scene tree
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if audioIns.is_inside_tree():
		#audioIns.global_transform = cW.weSl.attackPoint.global_transform
		audioIns.pitch_scale = soundSpeed
		audioIns.stream = newStream
		audioIns.play()
	else:
		print("The sound can't be played, AudioStreamPlayer3D instance is not in the scene tree")


func forceAttackPointTransformValues(attackPoint : Marker3D):
	#reset the attack points rotation values, to ensure that the projectiles will be shot in the correct direction
	if attackPoint.rotation != Vector3.ZERO: attackPoint.rotation = Vector3.ZERO
