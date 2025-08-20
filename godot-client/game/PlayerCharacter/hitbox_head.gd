extends StaticBody3D

@onready var parent : CharacterBody3D = $".."

# TODO: this pass through sucks. Fix - JAD
func hitscanHit(damageVal : float, hitscanDir : Vector3, hitscanPos : Vector3, source: int = 1):
	if parent != null: parent.hitscanHit(damageVal, hitscanDir, hitscanPos, source)

func projectileHit(damageVal : float, _hitscanDir : Vector3, source: int = 1):
	if parent != null: parent.projectileHit(damageVal, _hitscanDir, source)
