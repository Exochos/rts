extends CharacterBody3D
## Worker unit for RTS gameplay
##
## This script handles all worker behaviors including movement, resource gathering,
## building construction, and combat. Workers are the backbone of your economy.

# ============================================================================
# WORKER STATES
# ============================================================================
enum State {
	IDLE,           # Standing still, waiting for orders
	MOVING,         # Moving to a destination
	GATHERING,      # Harvesting resources from a resource node
	RETURNING,      # Carrying resources back to dropoff point
	BUILDING,       # Constructing a building
	ATTACKING,      # Engaging an enemy target
}

# ============================================================================
# EXPORTED VARIABLES (Editable in Inspector)
# ============================================================================
@export_group("Movement")
@export var move_speed: float = 3.5
@export var rotation_speed: float = 10.0

@export_group("Combat")
@export var attack_damage: int = 5
@export var attack_range: float = 1.5
@export var attack_cooldown: float = 1.0

@export_group("Resource Gathering")
@export var gather_rate: int = 10  # Resources gathered per cycle
@export var gather_interval: float = 1.5  # Time between gather actions
@export var carry_capacity: int = 10  # Max resources carried at once

@export_group("Selection")
@export var selected: bool = false:
	set(value):
		selected = value
		_update_selection_visual()

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim: AnimationPlayer = $Model/Ranger/AnimationPlayer
@onready var model_node: Node3D = $Model/Ranger



# ============================================================================
# STATE VARIABLES
# ============================================================================
var current_state: State = State.IDLE
var target_position: Vector3 = Vector3.ZERO
var target_node: Node = null  # Resource node, enemy, or building

# Resource Management
var carried_resources: int = 0
var resource_type: String = ""  # Type of resource being carried (e.g., "Gold", "Wood")
var dropoff_point: Node3D = null  # Where to return resources (e.g., townhall)

# Timers
var gather_timer: float = 0.0
var attack_timer: float = 0.0

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	# Add to units group for RTS controller selection
	add_to_group("units")

	# Initialize selection visual
	_update_selection_visual()

	# Configure NavigationAgent3D
	if nav_agent:
		await get_tree().physics_frame

		# Set navigation map from world
		nav_agent.set_navigation_map(get_world_3d().navigation_map)
		nav_agent.path_desired_distance = 1.0
		nav_agent.target_desired_distance = 1.0
		nav_agent.max_speed = move_speed

		# Wait for navigation mesh to be ready
		await get_tree().physics_frame

	# Find default dropoff point (townhall)
	_find_nearest_dropoff()

# ============================================================================
# PHYSICS PROCESS - Main update loop
# ============================================================================
func _physics_process(delta: float) -> void:
	# Update state machine
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.MOVING:
			_process_moving(delta)
		State.GATHERING:
			_process_gathering(delta)
		State.RETURNING:
			_process_returning(delta)
		State.BUILDING:
			_process_building(delta)
		State.ATTACKING:
			_process_attacking(delta)

	# Update animations based on state
	_update_animation()

# ============================================================================
# STATE PROCESSORS
# ============================================================================

func _process_idle(_delta: float) -> void:
	# Worker is idle, no movement
	velocity = Vector3.ZERO
	move_and_slide()

func _process_moving(delta: float) -> void:
	if not nav_agent:
		# Fallback to simple movement if no NavigationAgent
		_simple_move_to_target(delta)
		return

	# Check if we've reached the destination
	if nav_agent.is_navigation_finished():
		_arrive_at_destination()
		return

	# Get next position from navigation
	var next_position = nav_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()

	# Move toward next position
	velocity = direction * move_speed
	move_and_slide()

	# Rotate to face movement direction
	_rotate_toward(direction, delta)

func _process_gathering(delta: float) -> void:
	# Check if resource node is still valid
	if not is_instance_valid(target_node) or not target_node.has_method("is_gatherable"):
		_change_state(State.IDLE)
		return

	# Check if resource is depleted
	if not target_node.is_gatherable():
		_change_state(State.IDLE)
		return

	# Face the resource node
	var direction = (target_node.global_position - global_position).normalized()
	_rotate_toward(direction, delta)

	# Gather on interval
	gather_timer += delta
	if gather_timer >= gather_interval:
		gather_timer = 0.0
		_gather_resource()

func _process_returning(delta: float) -> void:
	# Move back to dropoff point
	if not is_instance_valid(dropoff_point):
		_find_nearest_dropoff()
		if not dropoff_point:
			# No dropoff point found, go idle
			_change_state(State.IDLE)
			return

	# Check if we've arrived at dropoff
	var distance_to_dropoff = global_position.distance_to(dropoff_point.global_position)
	if distance_to_dropoff < 3.1:
		_dropoff_resources()
		return

	# Move toward dropoff (similar to MOVING state)
	if nav_agent and nav_agent.is_navigation_finished():
		_dropoff_resources()
		return

	if nav_agent:
		var next_position = nav_agent.get_next_path_position()
		var direction = (next_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		_rotate_toward(direction, delta)
	else:
		_simple_move_to_target(delta)

func _process_building(delta: float) -> void:
	# TODO: Implement building construction
	# For now, just face the building and play animation
	if not is_instance_valid(target_node):
		_change_state(State.IDLE)
		return

	var direction = (target_node.global_position - global_position).normalized()
	_rotate_toward(direction, delta)

	# Placeholder: Building progress would go here
	velocity = Vector3.ZERO
	move_and_slide()

func _process_attacking(delta: float) -> void:
	# Check if target is still valid
	if not is_instance_valid(target_node):
		_change_state(State.IDLE)
		return

	var distance_to_target = global_position.distance_to(target_node.global_position)

	# If target is out of range, move closer
	if distance_to_target > attack_range:
		var direction = (target_node.global_position - global_position).normalized()
		velocity = direction * move_speed
		move_and_slide()
		_rotate_toward(direction, delta)
	else:
		# In range, stop and attack
		velocity = Vector3.ZERO
		move_and_slide()

		# Face target
		var direction = (target_node.global_position - global_position).normalized()
		_rotate_toward(direction, delta)

		# Attack on cooldown
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			attack_timer = 0.0
			_perform_attack()

# ============================================================================
# RTS CONTROLLER INTERFACE
# These methods are called by the rts_controller.gd
# ============================================================================

## Called by RTS controller when right-clicking on terrain
func move_to_position(pos: Vector3) -> void:
	target_node = null

	if nav_agent:
		var map := nav_agent.get_navigation_map()
		if map.is_valid():
			target_position = NavigationServer3D.map_get_closest_point(map, pos)
			nav_agent.set_target_position(target_position)
		else:
			print("[ERROR] Navigation map invalid")
	else:
		target_position = pos

	_change_state(State.MOVING)

## Called by RTS controller when right-clicking on an enemy
func attack_target(target: Node) -> void:
	target_node = target
	_change_state(State.ATTACKING)

## Called when player orders worker to gather from a resource
func gather_from_resource(resource_node: Node) -> void:
	if not is_instance_valid(resource_node):
		print("[ERROR] Invalid resource node")
		return

	if not resource_node.has_method("is_gatherable"):
		print("[ERROR] Target is not a gatherable resource")
		return

	target_node = resource_node
	target_position = resource_node.global_position

	# Move to resource first if too far
	var distance = global_position.distance_to(target_position)
	if distance > 4.0:
		if nav_agent:
			nav_agent.target_position = target_position
		_change_state(State.MOVING)
	else:
		_change_state(State.GATHERING)

## Called when player orders worker to construct a building
func construct_building(building_node: Node) -> void:
	target_node = building_node
	_change_state(State.BUILDING)

# ============================================================================
# RESOURCE GATHERING SYSTEM
# ============================================================================

func _gather_resource() -> void:
	if not is_instance_valid(target_node):
		return

	# Determine how much to gather
	var space_available = carry_capacity - carried_resources
	var amount_to_gather = min(gather_rate, space_available)

	# Gather from resource node
	if target_node.has_method("gather"):
		target_node.gather(amount_to_gather)
		carried_resources += amount_to_gather
		resource_type = target_node.resource_name

		print("Gathered %d %s (carrying %d/%d)" % [amount_to_gather, resource_type, carried_resources, carry_capacity])

	# If inventory is full, return to dropoff
	if carried_resources >= carry_capacity:
		_return_resources()

func _return_resources() -> void:
	if not dropoff_point:
		_find_nearest_dropoff()

	if dropoff_point and nav_agent:
		nav_agent.target_position = dropoff_point.global_position

	_change_state(State.RETURNING)

func _dropoff_resources() -> void:
	print("Deposited %d %s" % [carried_resources, resource_type])

	# TODO: Actually add resources to player's stockpile
	# PlayerResources.add_resource(resource_type, carried_resources)

	# Clear inventory
	carried_resources = 0
	resource_type = ""

	# Return to gathering if resource still exists
	if is_instance_valid(target_node) and target_node.has_method("is_gatherable") and target_node.is_gatherable():
		if nav_agent:
			nav_agent.target_position = target_node.global_position
		_change_state(State.MOVING)
	else:
		_change_state(State.IDLE)

func _find_nearest_dropoff() -> void:
	# Find townhall or similar dropoff point
	var buildings = get_tree().get_nodes_in_group("buildings")
	var nearest_dist = INF

	for building in buildings:
		# Assume townhall is the dropoff point
		if "townhall" in building.name.to_lower():
			var dist = global_position.distance_to(building.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				dropoff_point = building

# ============================================================================
# COMBAT SYSTEM
# ============================================================================

func _perform_attack() -> void:
	if not is_instance_valid(target_node):
		return

	print("Attacking %s for %d damage" % [target_node.name, attack_damage])

	# TODO: Apply damage to target
	if target_node.has_method("take_damage"):
		target_node.take_damage(attack_damage)

# ============================================================================
# MOVEMENT HELPERS
# ============================================================================

func _simple_move_to_target(delta: float) -> void:
	# Fallback movement without NavigationAgent
	var direction = (target_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	_rotate_toward(direction, delta)

	# Check if arrived
	if global_position.distance_to(target_position) < 0.5:
		_arrive_at_destination()

func _rotate_toward(direction: Vector3, delta: float) -> void:
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func _arrive_at_destination() -> void:
	# We've arrived at target position
	velocity = Vector3.ZERO

	# Determine what to do based on target_node
	if is_instance_valid(target_node):
		if target_node.has_method("is_gatherable") and target_node.is_gatherable():
			_change_state(State.GATHERING)
		elif target_node.is_in_group("enemies"):
			_change_state(State.ATTACKING)
		elif target_node.is_in_group("buildings"):
			_change_state(State.BUILDING)
		else:
			_change_state(State.IDLE)
	else:
		_change_state(State.IDLE)

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	# Exit current state
	match current_state:
		State.GATHERING:
			gather_timer = 0.0
		State.ATTACKING:
			attack_timer = 0.0

	# Enter new state
	current_state = new_state
	print("State: ", State.keys()[current_state])

# ============================================================================
# ANIMATION SYSTEM
# ============================================================================

func _update_animation() -> void:
	if not anim:
		return

	var desired_animation = ""

	match current_state:
		State.IDLE:
			desired_animation = "worker/Idle_A"
		State.MOVING, State.RETURNING:
			desired_animation = "worker/Running_A"
		State.GATHERING:
			desired_animation = "worker/Chop"  # or PickUp animation
		State.BUILDING:
			desired_animation = "worker/Use_Item"
		State.ATTACKING:
			desired_animation = "worker/Hit_A"

	# Only change animation if different
	if anim.current_animation != desired_animation:
		if anim.has_animation(desired_animation):
			anim.play(desired_animation)

# ============================================================================
# SELECTION VISUAL
# ============================================================================

func _update_selection_visual() -> void:
	if not model_node:
		return

	var overlay_material = null
	if selected:
		overlay_material = preload("res://materials/selected_outline.tres")

	_apply_overlay_recursive(model_node, overlay_material)

func _apply_overlay_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_overlay = mat

	for child in node.get_children():
		_apply_overlay_recursive(child, mat)

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

## Returns true if worker is carrying resources
func is_carrying_resources() -> bool:
	return carried_resources > 0

## Returns current state as a string (useful for debugging)
func get_state_name() -> String:
	return State.keys()[current_state]

## Forces worker to stop current action and go idle
func stop() -> void:
	target_node = null
	_change_state(State.IDLE)