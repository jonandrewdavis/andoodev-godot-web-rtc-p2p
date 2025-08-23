extends Node
class_name HealthSystem

signal hurt
signal health_updated
signal max_health_updated
signal death
@warning_ignore("unused_signal")
signal respawn

# TODO: HealthBars, do we want them to show on enemies? 

@export var max_health : int = 100
@export var health : int = 100

# TODO: Shield system? Halo / Apex, etc? Seperate from Health?
# NOTE: Halo 1's shield regen is about 5 seconds
@export var regen_enabled: bool = true
@export var regen_delay: float = 5.5 # Halo 1
@export var regen_speed: float = 0.15
@export var regen_increment: int = 2

@onready var regen_timer: Timer = Timer.new()
@onready var regen_tick_timer: Timer = Timer.new()

var last_damage_source := 0

# NOTE: If used, could be overriden to be the parent's sync, reducing # of syncronizers
#@onready var sync = $MultiplayerSynchronizer

func _ready() -> void:
	# NOTE: Changed from `is_server()` to `is_multiplayer_authority`.
	# NOTE: Added health to syncronizer to display to other clients (for health bars to be visible) 

	if is_multiplayer_authority():
		# Allow the UI to connect before we heal up.
		prepare_regen_timer()
		max_health_updated.emit(max_health)
		heal(max_health)

func damage(value: int, source: int = 0) -> bool:
	# Do not allow damage when dead.
	if health == 0:
		return false

	_damage_sync.rpc_id(int(get_parent().name), value, source)
	return true

@rpc('any_peer', 'reliable')
func _damage_sync(value, source):
	# Don't allow negative values when damaging
	var next_health = health - abs(value)
	if allow_damage_from_source(source) == false:
		return false

	# Do not allow damage when dead.
	if health == 0:
		return false
	
	# Do not allow overkill. Just die.
	# TODO: Clamp is easier right? Might work here
	if next_health <= 0:
		regen_tick_timer.stop()
		regen_timer.stop()
		health = 0
		last_damage_source = source
		health_updated.emit(0)
		hurt.emit()
		death.emit()
		return true

	# Damage
	if next_health < health and regen_enabled:
		hurt.emit()
		regen_timer.start()

	# Death
	if next_health == 0:
		death.emit()
	
	# Valid damage, not dead
	last_damage_source = source
	health = next_health
	health_updated.emit(next_health)
	hurt.emit()

	return true

func allow_damage_from_source(_source: int):
	# TODO: More rules. Teams?
	
	# NOTE: Prevent self damage
	if int(get_parent().name) == _source:
		return false

	return true

func heal(value):
	var next_health = health + abs(value)
	
	# Do not allow overheal
	if next_health > max_health:
		next_health = max_health
	
	health = next_health
	health_updated.emit(next_health)

func prepare_regen_timer():
	add_child(regen_timer)
	regen_timer.wait_time = regen_delay
	regen_timer.one_shot = true
	regen_timer.timeout.connect(start_regen_health)

	add_child(regen_tick_timer)
	regen_tick_timer.wait_time = regen_speed # regen_speed?
	regen_tick_timer.timeout.connect(regen_health_tick)

func start_regen_health():
	if regen_timer.is_stopped() && health < max_health:
		# "Clears" damage from players
		last_damage_source = 0
		regen_tick_timer.start()

func regen_health_tick():
	if regen_timer.is_stopped() && health < max_health:
		heal(regen_increment)
		regen_tick_timer.start()
	else:
		regen_tick_timer.stop()
