extends Node

# --- SCRIPT-WIDE VARIABLES ---
var selected_units: Array = [] 
@onready var box = $"../ui/selection_box"
@onready var command_card = $"../CommandCard"
var drag_start := Vector2.ZERO
var dragging := false

func _ready():
	# DEBUG: Check if units exist in the group
	var units = get_tree().get_nodes_in_group("units")
	print("DEBUG: Game started. Found ", units.size(), " units in group 'units'.")
	for u in units:
		print(" - Unit: ", u.name)

func _unhandled_input(event):
	# 1. LEFT CLICK (Selection)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start dragging
			drag_start = event.position
			dragging = true
			box.visible = true
			box.position = drag_start
			box.size = Vector2.ZERO
		else:
			# Stop dragging / Release
			dragging = false
			box.visible = false
			_select_units_in_box()

	# 2. MOUSE MOTION (Update Box)
	if dragging and event is InputEventMouseMotion:
		var current = event.position
		box.position = Vector2(min(drag_start.x, current.x), min(drag_start.y, current.y))
		box.size = abs(current - drag_start)
		
	# 3. RIGHT CLICK (Movement / Attack)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		print("Right click detected at position: ", event.position)
		_handle_right_click()

func _select_units_in_box():
	var rect = Rect2(box.position, box.size)
	
	# If box is tiny, treat it as a single click
	if rect.size.length() < 10:
		_single_click_select()
		return

	var cam = get_viewport().get_camera_3d()
	
	# Try finding UNITS first
	var found_units := []
	for unit in get_tree().get_nodes_in_group("units"):
		if unit is Node3D:
			var screen_pos = cam.unproject_position(unit.global_transform.origin)
			if rect.has_point(screen_pos):
				found_units.append(unit)

	if found_units.size() > 0:
		_apply_selection(found_units)
		return

	# If no units, look for BUILDINGS
	var found_buildings := []
	for b in get_tree().get_nodes_in_group("buildings"):
		if b is Node3D:
			var screen_pos = cam.unproject_position(b.global_transform.origin)
			if rect.has_point(screen_pos):
				found_buildings.append(b)
				
	_apply_selection(found_buildings)

func _single_click_select():
	var cam = get_viewport().get_camera_3d()
	if not cam: return

	var mouse_pos = get_viewport().get_mouse_position()
	var from = cam.project_ray_origin(mouse_pos)
	var to = from + cam.project_ray_normal(mouse_pos) * 2000
	var space_state = cam.get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true 
	query.collide_with_bodies = true
	query.collision_mask = 4294967295 # Hit everything

	var result = space_state.intersect_ray(query)
	
	
	if result:
		var candidate = result.collider
		# Traverse up to find the unit root
		for i in range(4):
			if not candidate: break
			
			if candidate.is_in_group("units") or candidate.is_in_group("buildings"):
				_apply_selection([candidate])
				return
			
			candidate = candidate.get_parent()

	# If we hit nothing important, deselect all
	_apply_selection([])

func _apply_selection(new_selection: Array):
	# 1. Deselect old selection
	for item in selected_units:
		if is_instance_valid(item):
			item.selected = false
			
	# 2. Update the variable
	selected_units = new_selection

	# 3. Select new units
	for item in selected_units:
		item.selected = true
	# 4. Update Command Card UI
	command_card.update_selection(selected_units)
	print("Selection updated. Count: ", selected_units.size())

func _handle_right_click():
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	
	var mouse_pos = get_viewport().get_mouse_position()
	var from = cam.project_ray_origin(mouse_pos)
	var to = from + cam.project_ray_normal(mouse_pos) * 2000
	var space_state = cam.get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_bodies = true
	query.collide_with_areas = true
	# OPTIONAL: logic to exclude selected units so you can click "through" them to the ground
	query.exclude = [self] + selected_units

	var result = space_state.intersect_ray(query)

	if result:
			var hit_node = result.collider
			print("--- Right Click Hit: ", hit_node.name, " | Class: ", hit_node.get_class())
			
			# Check groups
			print("    Groups: ", hit_node.get_groups())

			# 1. Attack
			if hit_node.is_in_group("enemies"):
					print("    -> Identified as ENEMY")
					# ... attack logic ...

			# 2. Move
			# Relaxed condition: Check if it's NOT an enemy and NOT a unit
			elif not hit_node.is_in_group("units"): 
					print("    -> Identified as GROUND/TERRAIN")
					print("    -> Selected Unit Count: ", selected_units.size())
					
					for unit in selected_units:
							# Check validity before calling
							if not is_instance_valid(unit):
									print("    -> Found Deleted Unit in array, skipping.")
									continue
									
							if unit.has_method("move_to_position"):
									unit.move_to_position(result.position)
							else:
									print("    -> CRITICAL: ", unit.name, " has no move script!")
			
			else:
					print("    -> Clicked a friendly unit or undefined object. Ignoring.")
