extends PhysicalBoneSimulator3D

# Note: Followed this guide: https://docs.godotengine.org/en/stable/tutorials/physics/ragdoll_system.html
# Delete Root, Hips, Neck

func _ready() -> void:
	#var level_15 = 00000000_00000000_00000000_00000010

	# Set bones to an un-used layer
	for bone: PhysicalBone3D in get_children():
		#bone.set_collision_mask(level_15)
		#bone.set_collision_layer(level_15)

		bone.joint_type = PhysicalBone3D.JOINT_TYPE_6DOF
		bone.angular_damp = 0.9
		bone.linear_damp = 0.3
		bone.mass = 8.0
