extends Node
## Procedural Tree Spawner
##
## Spawns trees procedurally across the map with configurable density and spacing.
## Can use Poisson disc sampling for even distribution or simple random placement.

# ============================================================================
# EXPORTED VARIABLES
# ============================================================================
@export_group("Spawn Area")
@export var spawn_area_size: Vector2 = Vector2(100, 100)  # Width x Depth of spawn area
@export var spawn_center: Vector3 = Vector3.ZERO  # Center point of spawn area
@export var spawn_on_ready: bool = true  # Auto-spawn trees when scene loads

@export_group("Tree Settings")
@export var tree_scene: PackedScene = preload("res://environment/resources/tree.tscn")
@export var tree_count: int = 50  # Number of trees to spawn
@export var min_tree_spacing: float = 5.0  # Minimum distance between trees

@export_group("Distribution")
@export var use_poisson_disc: bool = true  # Use Poisson disc for even distribution
@export var random_seed: int = 0  # Use 0 for random seed, or set specific seed for reproducibility
@export var poisson_attempts: int = 30  # Number of attempts to place each point (higher = more even)

@export_group("Randomization")
@export var random_rotation: bool = true  # Randomize tree rotation
@export var random_scale: bool = false  # Randomize tree scale
@export var scale_min: float = 0.8  # Minimum scale multiplier
@export var scale_max: float = 1.2  # Maximum scale multiplier

@export_group("Exclusion Zones")
@export var check_for_buildings: bool = true  # Don't spawn trees near buildings
@export var building_exclusion_radius: float = 8.0  # Min distance from buildings

# ============================================================================
# STATE VARIABLES
# ============================================================================
var spawned_trees: Array = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	# Initialize RNG
	if random_seed != 0:
		rng.seed = random_seed
	else:
		rng.randomize()

	# Auto-spawn if enabled
	if spawn_on_ready:
		call_deferred("spawn_trees")

# ============================================================================
# TREE SPAWNING
# ============================================================================

## Main function to spawn all trees
func spawn_trees() -> void:
	clear_trees()

	if not tree_scene:
		push_error("Tree spawner: No tree scene assigned!")
		return

	print("Spawning %d trees across area %s centered at %s" % [tree_count, spawn_area_size, spawn_center])

	var positions: Array = []

	if use_poisson_disc:
		positions = _generate_poisson_disc_positions()
	else:
		positions = _generate_random_positions()

	# Spawn trees at each position
	for pos in positions:
		_spawn_tree_at_position(pos)

	print("Successfully spawned %d trees" % spawned_trees.size())

## Clear all spawned trees
func clear_trees() -> void:
	for tree in spawned_trees:
		if is_instance_valid(tree):
			tree.queue_free()
	spawned_trees.clear()

# ============================================================================
# POSITION GENERATION - Poisson Disc Sampling
# ============================================================================

func _generate_poisson_disc_positions() -> Array:
	var positions: Array = []
	var active_list: Array = []

	# Calculate grid size
	var cell_size = min_tree_spacing / sqrt(2.0)
	var grid_width = int(ceil(spawn_area_size.x / cell_size))
	var grid_height = int(ceil(spawn_area_size.y / cell_size))

	# Initialize grid (-1 means empty)
	var grid = []
	for _i in range(grid_width * grid_height):
		grid.append(-1)

	# Helper to convert world pos to grid index
	var world_to_grid = func(world_pos: Vector3) -> Vector2i:
		var local_x = world_pos.x - (spawn_center.x - spawn_area_size.x / 2.0)
		var local_z = world_pos.z - (spawn_center.z - spawn_area_size.y / 2.0)
		return Vector2i(
			int(local_x / cell_size),
			int(local_z / cell_size)
		)

	# Helper to check if position is valid
	var is_valid_position = func(pos: Vector3) -> bool:
		# Check bounds
		if pos.x < spawn_center.x - spawn_area_size.x / 2.0 or pos.x > spawn_center.x + spawn_area_size.x / 2.0:
			return false
		if pos.z < spawn_center.z - spawn_area_size.y / 2.0 or pos.z > spawn_center.z + spawn_area_size.y / 2.0:
			return false

		# Check exclusion zones
		if check_for_buildings and _is_too_close_to_buildings(pos):
			return false

		# Check distance to nearby points
		var grid_pos = world_to_grid.call(pos)
		var search_radius = 2

		for i in range(-search_radius, search_radius + 1):
			for j in range(-search_radius, search_radius + 1):
				var check_x = grid_pos.x + i
				var check_y = grid_pos.y + j

				if check_x < 0 or check_x >= grid_width or check_y < 0 or check_y >= grid_height:
					continue

				var grid_index = check_y * grid_width + check_x
				var point_index = grid[grid_index]

				if point_index != -1:
					var other_pos = positions[point_index]
					if pos.distance_to(other_pos) < min_tree_spacing:
						return false

		return true

	# Start with random point
	var first_pos = Vector3(
		spawn_center.x + rng.randf_range(-spawn_area_size.x / 2.0, spawn_area_size.x / 2.0),
		0,
		spawn_center.z + rng.randf_range(-spawn_area_size.y / 2.0, spawn_area_size.y / 2.0)
	)

	if not check_for_buildings or not _is_too_close_to_buildings(first_pos):
		positions.append(first_pos)
		active_list.append(0)
		var grid_pos = world_to_grid.call(first_pos)
		grid[grid_pos.y * grid_width + grid_pos.x] = 0

	# Generate points
	while active_list.size() > 0 and positions.size() < tree_count:
		var random_index = rng.randi() % active_list.size()
		var point_index = active_list[random_index]
		var point = positions[point_index]

		var found = false

		for _attempt in range(poisson_attempts):
			# Generate random point around current point
			var angle = rng.randf() * TAU
			var radius = min_tree_spacing + rng.randf() * min_tree_spacing
			var new_pos = Vector3(
				point.x + cos(angle) * radius,
				0,
				point.z + sin(angle) * radius
			)

			if is_valid_position.call(new_pos):
				positions.append(new_pos)
				active_list.append(positions.size() - 1)
				var grid_pos = world_to_grid.call(new_pos)
				grid[grid_pos.y * grid_width + grid_pos.x] = positions.size() - 1
				found = true
				break

		if not found:
			active_list.remove_at(random_index)

	return positions

# ============================================================================
# POSITION GENERATION - Simple Random
# ============================================================================

func _generate_random_positions() -> Array:
	var positions: Array = []

	var attempts = 0
	var max_attempts = tree_count * 100

	while positions.size() < tree_count and attempts < max_attempts:
		attempts += 1

		# Generate random position
		var pos = Vector3(
			spawn_center.x + rng.randf_range(-spawn_area_size.x / 2.0, spawn_area_size.x / 2.0),
			0,
			spawn_center.z + rng.randf_range(-spawn_area_size.y / 2.0, spawn_area_size.y / 2.0)
		)

		# Check minimum spacing
		var too_close = false
		for existing_pos in positions:
			if pos.distance_to(existing_pos) < min_tree_spacing:
				too_close = true
				break

		# Check exclusion zones
		if check_for_buildings and _is_too_close_to_buildings(pos):
			too_close = true

		if not too_close:
			positions.append(pos)

	return positions

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _is_too_close_to_buildings(pos: Vector3) -> bool:
	var buildings = get_tree().get_nodes_in_group("buildings")

	for building in buildings:
		if is_instance_valid(building):
			var distance = pos.distance_to(building.global_position)
			if distance < building_exclusion_radius:
				return true

	return false

func _spawn_tree_at_position(pos: Vector3) -> void:
	var tree = tree_scene.instantiate()

	# Set position
	tree.global_position = pos

	# Random rotation
	if random_rotation:
		tree.rotation.y = rng.randf() * TAU

	# Random scale
	if random_scale:
		var scale = rng.randf_range(scale_min, scale_max)
		tree.scale = Vector3(scale, scale, scale)

	# Add to world
	get_tree().root.add_child(tree)

	# Track spawned tree
	spawned_trees.append(tree)

# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

## Respawn all trees with current settings
func respawn_trees() -> void:
	spawn_trees()

## Get count of spawned trees
func get_tree_count() -> int:
	# Clean up invalid trees
	spawned_trees = spawned_trees.filter(func(tree): return is_instance_valid(tree))
	return spawned_trees.size()