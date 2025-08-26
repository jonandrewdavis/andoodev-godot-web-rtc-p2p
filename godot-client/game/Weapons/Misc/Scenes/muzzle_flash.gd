extends Node3D

# Called when the node enters the scene tree for the first time.
func flash() -> void:
	$MuzzleFlash.emitting = true
	$CPUParticles3D.emitting = true
