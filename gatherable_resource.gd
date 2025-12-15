class_name GatherableResource extends StaticBody3D

# Export variables let you change these settings in the Inspector for each different object
@export var resource_name: String = "Gold"
@export var amount: int = 1000
@export var max_amount: int = 1000

# Reference to label for displaying amount
var label_node: Label3D = null

func _ready() -> void:
	# Find the Label3D child node if it exists
	label_node = get_node_or_null("Label3D")
	_update_label()

# Helper to identify if this is gatherable
func is_gatherable() -> bool:
	return amount > 0

# This function will be called by your Player when they interact
func gather(gather_power: int):
	if amount <= 0:
		print(resource_name + " is already depleted.")
		return

	amount -= gather_power
	print("Gathered " + str(gather_power) + " " + resource_name + ". Remaining: " + str(amount))

	# Update the label with new amount
	_update_label()

	if amount <= 0:
		deplete_resource()

func deplete_resource():
	print(resource_name + " depleted!")
	$MeshInstance3D.visible = false

	# Update label to show depleted
	_update_label()

func _update_label() -> void:
	if not label_node:
		return

	if amount <= 0:
		label_node.text = resource_name + "\n(Depleted)"
	else:
		label_node.text = resource_name + "\n%d Left" % amount