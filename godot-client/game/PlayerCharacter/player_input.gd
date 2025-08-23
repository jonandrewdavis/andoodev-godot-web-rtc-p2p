class_name PlayerInput
extends Node

@onready var player: PlayerCharacter = get_parent()

@export var input_dir : Vector2
@export var is_jumping: bool = false
@export var is_sprinting: bool = false
@export var is_interacting: bool = false
@export var is_crouching: bool = false
@export var is_weapon_up: bool = false
@export var is_weapon_down: bool = false
@export var is_weapon_shoot: bool = false
@export var is_weapon_melee: bool = false
@export var is_weapon_reload: bool = false
@export var is_weapon_aim: bool = false
@export var is_debug_b: bool = false

@export var mouseInput : Vector2 = Vector2(0,0)

# NOTE: If using in server authoratitive, this needs a multiplayer syncronizer inside. or an RPC.

func _ready():
	if not is_multiplayer_authority():
		set_process(false)
		set_physics_process(false)
		
func _physics_process(_delta: float) -> void:
	#	cR.inputDirection = Input.get_vector(cR.moveLeftAction, cR.moveRightAction, cR.moveForwardAction, cR.moveBackwardAction)
	if player.immobile or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		input_dir = Vector2.ZERO
		is_jumping = false
		is_sprinting = false
		is_interacting = false
		is_crouching = false
		is_weapon_up = false
		is_weapon_down = false
		is_weapon_shoot = false
		is_weapon_melee = false
		is_weapon_reload = false
		is_weapon_aim = false
		return
		
	input_dir = Input.get_vector("left", "right", "up", "down")
	is_jumping = Input.is_action_pressed("jump")
	is_sprinting = Input.is_action_pressed("sprint")
	is_interacting = Input.is_action_pressed("interact")
	is_crouching = Input.is_action_pressed("crouch")
	is_weapon_up = Input.is_action_pressed("weapon_up")
	is_weapon_down = Input.is_action_pressed("weapon_down")
	is_weapon_shoot = Input.is_action_pressed("weapon_shoot") # (Note: Special case for browsers, uses "P")
	is_weapon_melee = Input.is_action_pressed("weapon_melee")
	is_weapon_reload = Input.is_action_pressed("weapon_reload")
	is_weapon_aim = Input.is_action_pressed("weapon_aim")
	is_debug_b = Input.is_action_pressed("debug_b")

func _process(_delta):
	if Input.is_action_just_pressed('menu') and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif Input.is_action_just_pressed('menu') and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		mouseInput.x += event.relative.x
		mouseInput.y += event.relative.y

	if event is InputEventMouseButton:		
		if event.button_index == 4 and event.pressed == true:
			is_weapon_up = true
		elif event.button_index == 5 and event.pressed == true:
			is_weapon_down = true
