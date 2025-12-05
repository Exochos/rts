extends Control

@onready var grid = $PanelContainer/GridContainer

func update_selection(selected_nodes: Array):
	# 1. Clear existing buttons
	for child in grid.get_children():
		child.queue_free()
	
	# 2. Safety Check: Only show options if EXACTLY ONE thing is selected
	if selected_nodes.size() != 1:
		visible = false
		return
		
	var unit = selected_nodes[0]
	
	# 3. Check if the unit actually HAS command options
	if unit.has_method("get_command_options"):
		visible = true
		var options = unit.get_command_options()
		
		# 4. Create a button for each option
		for opt in options:
			var btn = Button.new()
			btn.text = opt["name"]
			# Connect the button click to the unit's function
			btn.pressed.connect(opt["callable"])
			grid.add_child(btn)
	else:
		visible = false