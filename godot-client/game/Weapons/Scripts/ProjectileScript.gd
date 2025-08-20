extends RigidBody3D

class_name Projectile

#properties variables
var isExplosive : bool = false
var direction : Vector3 
@export var damage : float
var timeBeforeVanish : float 
var source: int
#var bodiesList : Array = []

#references variables
@export var mesh: MeshInstance3D
@export var hitbox: CollisionShape3D

@export_group("Sound variables")
@onready var audioManager : PackedScene = preload("../Misc/Scenes/AudioManagerScene.tscn")
@export var explosionSound : AudioStream

@export_group("Particles variables")
var particlesManager : PackedScene = preload("../Misc/Scenes/ParticlesManagerScene.tscn")

var normal: Vector3

func _ready():
	body_entered.connect(_on_body_entered)
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 1
	if isExplosive == false:
		set_process(false)

func _process(delta):
	if timeBeforeVanish > 0.0: timeBeforeVanish -= delta
	else: hit()
		
func _on_body_entered(body):
	if body.get_multiplayer_authority() != source:
		applyDamage(body)
		hit()

func hit():
	mesh.visible = false
	hitbox.set_deferred("disabled", true)
	
	if isExplosive: 
		explode()


func applyDamage(body):
	if body.is_in_group("Enemies") and body.has_method("projectileHit"):
		body.projectileHit(damage, direction, source)
	elif body.is_in_group("EnemiesHead") and body.has_method("projectileHit"):
		body.projectileHit(damage * 2.0, direction, source)
	elif body.is_in_group("HitableObjects") and body.has_method("projectileHit"):
		body.projectileHit(damage, direction, source)
	elif body.has_method("projectileHit") == false:
		pass
		#Hub.projectile_system.add_new_decal.rpc(position, normal)

func explode():
	#this function is visual and audio only, it doesn't affect the gameplay
	weaponSoundManagement(explosionSound)
	
	var particlesIns = particlesManager.instantiate()
	particlesIns.particleToEmit = "Explosion"
	particlesIns.global_transform = global_transform
	get_tree().get_root().add_child.call_deferred(particlesIns)

	queue_free()
	
func weaponSoundManagement(soundName):
	if soundName != null:
		var audioIns = audioManager.instantiate()
		audioIns.global_transform = global_transform
		get_tree().get_root().add_child(audioIns)
		audioIns.volume_db = 5.0
		audioIns.stream = soundName
		audioIns.play()
