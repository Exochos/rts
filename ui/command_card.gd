extends Control

@onready var grid := $PanelContainer/GridContainer

func update_selection(selected_nodes: Array):
	# Clear previous UI
	for child in grid.get_children():
		child.queue_free()

	# Only show if EXACTLY one unit is selected
	if selected_nodes.size() != 1:
		visible = false
		return

	var unit = selected_nodes[0]

	# Ensure the selected unit actually has commands
	if not unit.has_method("get_command_options"):
		visible = false
		return

	visible = true
	var options = unit.get_command_options()

	for opt in options:
		var btn := Button.new()

		# Set label
		btn.text = opt.get("name", "???")

		# If this command has an icon, apply it
		if opt.has("icon"):
			btn.icon = opt["icon"]
			btn.expand_icon = true
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER

			# Optional: force a slightly larger button
			btn.custom_minimum_size = Vector2(80, 80)

		# Connect callback
		btn.pressed.connect(opt["callable"])

		# Add to grid
		grid.add_child(btn)
