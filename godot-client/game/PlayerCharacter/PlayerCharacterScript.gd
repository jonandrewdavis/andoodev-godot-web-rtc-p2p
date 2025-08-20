extends CharacterBody3D

class_name PlayerCharacter 

@export_group("Multiplayer Added")
@export var player_input : PlayerInput
@export var player_model: Node3D
@export var health_system: HealthSystem
@export var immobile: bool = false
@export var look_at_target: Marker3D
@export var player_ui: PlayerUI

signal signal_hit_success(headshot)

@export_group("Movement variables")
var moveSpeed : float
var moveAccel : float
var moveDeccel : float
var desiredMoveSpeed : float 
@export var desiredMoveSpeedCurve : Curve
@export var maxSpeed : float
@export var inAirMoveSpeedCurve : Curve
var inputDirection : Vector2 
var moveDirection : Vector3 
@export var hitGroundCooldown : float #amount of time the character keep his accumulated speed before losing it (while being on ground)
var hitGroundCooldownRef : float 
@export var bunnyHopDmsIncre : float #bunny hopping desired move speed incrementer
@export var autoBunnyHop : bool = false
var lastFramePosition : Vector3 
var lastFrameVelocity : Vector3
var wasOnFloor : bool
var walkOrRun : String = "WalkState" #keep in memory if play char was walking or running before being in the air
#for crouch visible changes
@export var baseHitboxHeight : float
@export var baseModelHeight : float
@export var heightChangeSpeed : float

@export_group("Crouch variables")
@export var crouchSpeed : float
@export var crouchAccel : float
@export var crouchDeccel : float
@export var continiousCrouch : bool = false #if true, doesn't need to keep crouch button on to crouch
@export var crouchHitboxHeight : float
@export var crouchModelHeight : float

@export_group("Walk variables")
@export var walkSpeed : float
@export var walkAccel : float
@export var walkDeccel : float

@export_group("Run variables")
@export var runSpeed : float
@export var runAccel : float 
@export var runDeccel : float 
@export var continiousRun : bool = false #if true, doesn't need to keep run button on to run

@export_group("Jump variables")
@export var jumpHeight : float
@export var jumpTimeToPeak : float
@export var jumpTimeToFall : float
@onready var jumpVelocity : float = (2.0 * jumpHeight) / jumpTimeToPeak
@export var jumpCooldown : float
var jumpCooldownRef : float 
@export var nbJumpsInAirAllowed : int 
var nbJumpsInAirAllowedRef : int 
var jumpBuffOn : bool = false
var bufferedJump : bool = false
@export var coyoteJumpCooldown : float
var coyoteJumpCooldownRef : float
var coyoteJumpOn : bool = false
@export_range(0.1, 1.0, 0.05) var inAirInputMultiplier: float = 1.0

@export_group("Gravity variables")
@onready var jumpGravity : float = (-2.0 * jumpHeight) / (jumpTimeToPeak * jumpTimeToPeak)
@onready var fallGravity : float = (-2.0 * jumpHeight) / (jumpTimeToFall * jumpTimeToFall)

@export_group("Keybind variables")
@export var moveForwardAction : String = ""
@export var moveBackwardAction : String = ""
@export var moveLeftAction : String = ""
@export var moveRightAction : String = ""
@export var runAction : String = ""
@export var crouchAction : String = ""
@export var jumpAction : String = ""

#references variables
@onready var camHolder : CameraObject = %CameraHolder
@onready var hitbox : CollisionShape3D = $Hitbox
@onready var stateMachine : StateMachinePlayer = %StateMachine
@onready var ceilingCheck : RayCast3D = $Raycasts/CeilingCheck
@onready var floorCheck : RayCast3D = $Raycasts/FloorCheck

func _enter_tree():
	# With mesh type, be client authority.
	set_multiplayer_authority(str(name).to_int())
	#player_input.set_multiplayer_authority(str(name).to_int())

func _ready():
	add_to_group("Players")

	if is_multiplayer_authority():
		%HitboxHead.queue_free()
		%Camera.current = true
	else:
		set_process(false)
		set_physics_process(false)
		%WeaponManager.set_process(false)
		%ShootManager.set_process(false)
		%AnimationManager.set_process(false)		
		add_to_group("Enemies")
		$HitboxHead.add_to_group("EnemiesHead")
		$HitboxHead.set_collision_layer_value(6, true) 
		%WeaponContainer.set_scale(Vector3(1.7, 1.7, 1.7))
		%WeaponContainer.position = Vector3(-0.15, 0.63, 0.0)		

	#set move variables, and value references
	moveSpeed = walkSpeed
	moveAccel = walkAccel
	moveDeccel = walkDeccel
	
	hitGroundCooldownRef = hitGroundCooldown
	jumpCooldownRef = jumpCooldown
	nbJumpsInAirAllowedRef = nbJumpsInAirAllowed
	coyoteJumpCooldownRef = coyoteJumpCooldown
	
func _physics_process(_delta : float):
	modifyPhysicsProperties()
	move_and_slide()
	
func modifyPhysicsProperties():
	lastFramePosition = position #get play char position every frame
	lastFrameVelocity = velocity #get play char velocity every frame
	wasOnFloor = !is_on_floor() #check if play char was on floor every frame
	
func gravityApply(delta : float):
	#if play char goes up, apply jump gravity
	#otherwise, apply fall gravity
	if velocity.y >= 0.0: velocity.y += jumpGravity * delta
	elif velocity.y < 0.0: velocity.y += fallGravity * delta

func hitscanHit(damageVal : float, _hitscanDir : Vector3, _hitscanPos : Vector3, source = 1):
	var damage_successful = health_system.damage(damageVal, source)
	#if damage_successful:
		##Hub.emit_signal('hit')

func projectileHit(damageVal : float, _hitscanDir : Vector3, source = 1):
	# TODO: Projectile source & physics
	var damage_successful = health_system.damage(damageVal, source)
	#if damage_successful:
		#Hub.emit_signal('hit')

func toggle_weapon_visible(value: bool):
	%WeaponContainer.visible = value
