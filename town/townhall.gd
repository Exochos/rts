extends Node3D

@onready var selector = $Selector
@onready var model = $Model
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
	# Spawn logic goes here

func _upgrade_tech():
	print("Townhall: Upgrading tech...")

func _update_selection_visual():
	# Loop through meshes to apply/remove the outline
	var model_node = $Model # Adjust path if needed
	if not model_node: return
	
	for child in model_node.get_children():
		if child is MeshInstance3D:
			if selected:
				child.material_overlay = preload("res://materials/selected_outline.tres")
			else:
				child.material_overlay = null

func _ready():
	# Ensure the selection ring is hidden by default
	if selector:
		selector.visible = false
