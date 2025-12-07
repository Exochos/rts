extends Node3D

@onready var selector = $Selector
@onready var model = $Model
@onready var worker_spawn_point = $WorkerSpawnPoint
@onready var worker_scene = preload("res://units/worker.tscn")
@export var selected: bool = false:
	set(value):
		selected = value
		_update_selection_visual()


# This function returns a list of dictionaries.
# Each dictionary describes one button.
func get_command_options():
	return [
		{
			"name": "Train Worker",
			"cost": 50,
			"icon": preload("res://assets/icons/train_worker.png"),
			"callable": Callable(self, "_train_worker") # Reference to the function below
		},
		{
			"name": "Upgrade Tech",
			"cost": 100,
			"callable": Callable(self, "_upgrade_tech")
		}
	]

func _train_worker():
	print("Townhall: Training a worker now...")
	var worker_instance = worker_scene.instantiate()
	var pos = worker_spawn_point.global_transform.origin
	var offset = Vector3(randf() * 2 - 1, 0, randf() * 1.2 - 1).normalized() * 1.2
	worker_instance.global_transform.origin = pos + offset
	get_parent().add_child(worker_instance)
	

func move_to_position(new_position: Vector3):
	print("Townhall: Moving spawn point to: ", new_position)
	worker_spawn_point.global_transform.origin = new_position
	
func update_worker_spawn_point(new_position: Vector3):
	print("Updating worker spawn point to: ", new_position)
	worker_spawn_point.global_transform.origin = new_position

func _upgrade_tech():
	print("Townhall: Upgrading tech...")

func _update_selection_visual():
	var model_node = $Model
	if not model_node: return
	
	var overlay_material = null
	if selected:
		overlay_material = preload("res://materials/selected_outline.tres")
	
	# Start the recursive search
	_apply_overlay_recursive(model_node, overlay_material)

# This function looks at a node, applies the mat if it's a mesh, 
# and then checks all that node's children too.
func _apply_overlay_recursive(node: Node, mat: Material):
	# If this specific node is a MeshInstance3D, apply the overlay
	if node is MeshInstance3D:
		node.material_overlay = mat
	
	# Check all children of this node (and their children, etc.)
	for child in node.get_children():
		_apply_overlay_recursive(child, mat)