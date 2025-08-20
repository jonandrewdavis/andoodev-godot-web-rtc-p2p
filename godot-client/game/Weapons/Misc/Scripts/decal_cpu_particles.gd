extends CPUParticles3D


func _ready() -> void:
	emitting = true
	await get_tree().create_timer(8.0).timeout
	get_parent().call_deferred('queue_free')
