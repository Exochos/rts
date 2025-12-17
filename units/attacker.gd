extends CharacterBody3D
## Generic attacker unit for RTS gameplay
##
## This script handles movement towards a target point and automatically
## attacks any enemies within aggro range. Perfect for spawned enemies.

# ============================================================================
# ATTACKER STATES
# ============================================================================
enum State {
	IDLE,           # Standing still
	MOVING,         # Moving to target point
	CHASING,        # Chasing a detected enemy
	ATTACKING,      # Engaging an enemy in range
}

# ============================================================================
# EXPORTED VARIABLES (Editable in Inspector)
# ============================================================================
@export_group("Movement")
@export var move_speed: float = 3.0
@export var rotation_speed: float = 10.0

@export_group("Combat")
@export var attack_damage: int = 10
@export var attack_range: float = 2.0
@export var attack_cooldown: float = 1.5
@export var aggro_range: float = 8.0  # How far to detect enemies

@export_group("AI")
@export var target_point: Vector3 = Vector3.ZERO  # Default rally point

@export_group("Selection")
@export var selected: bool = false:
	set(value):
		selected = value
		_update_selection_visual()

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var model_node: Node3D = $Model
@onready var aggro_area: Area3D = $AggroArea

# ============================================================================
# STATE VARIABLES
# ============================================================================
var current_state: State = State.IDLE
var current_target: Node = null  # Current enemy target

# Timers
var attack_timer: float = 0.0
var aggro_check_timer: float = 0.0
var aggro_check_interval: float = 0.3  # Check for enemies every 0.3s

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	# Add to enemies group so workers/players can target us
	add_to_group("enemies")

	# Setup aggro area
	if aggro_area:
		var collision_shape = CollisionShape3D.new()
		var sphere = SphereShape3D.new()
		sphere.radius = aggro_range
		collision_shape.shape = sphere
		aggro_area.add_child(collision_shape)
		aggro_area.body_entered.connect(_on_body_entered_aggro)
		aggro_area.body_exited.connect(_on_body_exited_aggro)

	# Configure NavigationAgent3D
	if nav_agent:
		await get_tree().physics_frame
		nav_agent.set_navigation_map(get_world_3d().navigation_map)
		nav_agent.path_desired_distance = 1.0
		nav_agent.target_desired_distance = 1.5
		nav_agent.max_speed = move_speed
		await get_tree().physics_frame

	# Start moving to target point if set
	if target_point != Vector3.ZERO:
		move_to_point(target_point)

	_update_selection_visual()

# ============================================================================
# PHYSICS PROCESS - Main update loop
# ============================================================================
func _physics_process(delta: float) -> void:
	# Periodically check for enemies in range
	aggro_check_timer += delta
	if aggro_check_timer >= aggro_check_interval:
		aggro_check_timer = 0.0
		_check_for_enemies()

	# Update state machine
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.MOVING:
			_process_moving(delta)
		State.CHASING:
			_process_chasing(delta)
		State.ATTACKING:
			_process_attacking(delta)

	# Update animations
	_update_animation()

# ============================================================================
# STATE PROCESSORS
# ============================================================================

func _process_idle(_delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()

func _process_moving(delta: float) -> void:
	if not nav_agent:
		_simple_move_to_target(delta)
		return

	# Check if we've reached the destination
	if nav_agent.is_navigation_finished():
		_change_state(State.IDLE)
		return

	# Get next position from navigation
	var next_position = nav_agent.get_next_path_position()
	var direction = (next_position - global_position).normalized()

	# Move toward next position
	velocity = direction * move_speed
	move_and_slide()

	# Rotate to face movement direction
	_rotate_toward(direction, delta)

func _process_chasing(delta: float) -> void:
	# Check if target is still valid
	if not is_instance_valid(current_target):
		# Lost target, go back to moving to point
		if target_point != Vector3.ZERO:
			move_to_point(target_point)
		else:
			_change_state(State.IDLE)
		return

	var distance_to_target = global_position.distance_to(current_target.global_position)

	# If in attack range, start attacking
	if distance_to_target <= attack_range:
		_change_state(State.ATTACKING)
		return

	# Move towards target
	if nav_agent:
		nav_agent.target_position = current_target.global_position

	var direction = (current_target.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	_rotate_toward(direction, delta)

func _process_attacking(delta: float) -> void:
	# Check if target is still valid
	if not is_instance_valid(current_target):
		_change_state(State.IDLE)
		return

	var distance_to_target = global_position.distance_to(current_target.global_position)

	# If target moved out of range, chase again
	if distance_to_target > attack_range * 1.2:  # Small buffer
		_change_state(State.CHASING)
		return

	# Stop moving and face target
	velocity = Vector3.ZERO
	move_and_slide()

	var direction = (current_target.global_position - global_position).normalized()
	_rotate_toward(direction, delta)

	# Attack on cooldown
	attack_timer += delta
	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		_perform_attack()

# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

## Set the point this attacker should move towards
func move_to_point(point: Vector3) -> void:
	target_point = point
	current_target = null

	if nav_agent:
		var map := nav_agent.get_navigation_map()
		if map.is_valid():
			var closest_point = NavigationServer3D.map_get_closest_point(map, point)
			nav_agent.set_target_position(closest_point)
		else:
			print("[ERROR] Navigation map invalid")

	_change_state(State.MOVING)

## Manually set a target to attack
func attack_target(target: Node) -> void:
	if not is_instance_valid(target):
		return

	current_target = target
	_change_state(State.CHASING)

# ============================================================================
# COMBAT SYSTEM
# ============================================================================

func _check_for_enemies() -> void:
	# Don't interrupt attacking
	if current_state == State.ATTACKING:
		return

	# Look for enemies in aggro range
	var potential_targets = []

	# Check for units in "units" group (player units)
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if is_instance_valid(unit) and unit != self:
			var distance = global_position.distance_to(unit.global_position)
			if distance <= aggro_range:
				potential_targets.append({"node": unit, "distance": distance})

	# Check for buildings in "buildings" group
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if is_instance_valid(building):
			var distance = global_position.distance_to(building.global_position)
			if distance <= aggro_range:
				potential_targets.append({"node": building, "distance": distance})

	# Attack closest target
	if potential_targets.size() > 0:
		potential_targets.sort_custom(func(a, b): return a["distance"] < b["distance"])
		attack_target(potential_targets[0]["node"])

func _perform_attack() -> void:
	if not is_instance_valid(current_target):
		return

	print("%s attacking %s for %d damage" % [name, current_target.name, attack_damage])

	# Deal damage if target has take_damage method
	if current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)

func _on_body_entered_aggro(body: Node3D) -> void:
	# Detect when potential enemies enter aggro range
	if body.is_in_group("units") or body.is_in_group("buildings"):
		if current_state == State.IDLE or current_state == State.MOVING:
			attack_target(body)

func _on_body_exited_aggro(_body: Node3D) -> void:
	# Could track when enemies leave range if needed
	pass

func take_damage(damage: int) -> void:
	print("%s took %d damage" % [name, damage])
	# TODO: Implement health system
	# For now, just delete after taking damage
	queue_free()

# ============================================================================
# MOVEMENT HELPERS
# ============================================================================

func _simple_move_to_target(delta: float) -> void:
	var target_pos = target_point if current_target == null else current_target.global_position
	var direction = (target_pos - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	_rotate_toward(direction, delta)

	# Check if arrived
	if global_position.distance_to(target_pos) < 1.0:
		if current_target == null:
			_change_state(State.IDLE)

func _rotate_toward(direction: Vector3, delta: float) -> void:
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

# ============================================================================
# STATE MANAGEMENT
# ============================================================================

func _change_state(new_state: State) -> void:
	if current_state == new_state:
		return

	# Exit current state
	match current_state:
		State.ATTACKING:
			attack_timer = 0.0

	# Enter new state
	current_state = new_state

# ============================================================================
# ANIMATION SYSTEM
# ============================================================================

func _update_animation() -> void:
	if not anim:
		return

	var desired_animation = ""

	match current_state:
		State.IDLE:
			desired_animation = "Jump_Idle"
		State.MOVING, State.CHASING:
			desired_animation = "Running_A"
		State.ATTACKING:
			desired_animation = "Jump_Idle"  # Placeholder for attack animation

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