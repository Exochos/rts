class_name GatherableResource extends StaticBody3D

# Export variables let you change these settings in the Inspector for each different object
@export var resource_name: String = "Gold"
@export var amount: int = 1000
@export var max_amount: int = 1000

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
	
	if amount <= 0:
		deplete_resource()

func deplete_resource():
	print(resource_name + " depleted!")
	$MeshInstance3D.visible = false