class_name Instantiate
extends Object


## Instantiates a scene based on [param clss_name]. Scene must be located next
## to the associated class.
# https://gist.github.com/gruebite/114a7d5c9d5878e5a996294d83649857
static func scene(clss_name: GDScript) -> Node:
	var scn_path := scene_path(clss_name)
	var scn: PackedScene = ResourceLoader.load(scn_path)
	var node := scn.instantiate()
	return node


static func scene_path(clss_name: GDScript) -> String:
	var clss_path := clss_name.resource_path
	assert(clss_path.ends_with(".gd"), "missing script for class")
	var scn_path := clss_path.get_basename() + ".tscn"
	assert(ResourceLoader.exists(scn_path), "missing scene for class")
	return scn_path
