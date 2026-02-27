extends RigidBody3D


func _enter_tree() -> void:
	assume_owner(get_parent().get_multiplayer_authority())

@rpc("any_peer", 'call_local', 'reliable')
func assume_owner(id):
	set_multiplayer_authority(id)

func hitscanHit(propulForce : float, propulDir: Vector3, propulPos : Vector3, _source: int = 1):
	var hitPos : Vector3 = propulPos - global_transform.origin #set the position to launch the object at
	if propulDir != Vector3.ZERO: apply_impulse(propulDir * propulForce, hitPos)
	#Hub.hit.emit()
	assume_owner.rpc(multiplayer.get_unique_id())

func projectileHit(propulForce : float, propulDir: Vector3, _source: int = 1):
	if propulDir != Vector3.ZERO: apply_central_force((global_transform.origin - propulDir) * propulForce)
	#Hub.hit.emit()
	assume_owner.rpc(multiplayer.get_unique_id())
