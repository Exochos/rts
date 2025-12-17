extends Node3D
## Enemy Spawner Building
##
## Spawns enemy units at regular intervals. Can either keep them near the spawner
## or send them to a rally point based on the use_rally_point setting.

# ============================================================================
# EXPORTED VARIABLES
# ============================================================================
@export_group("Spawning")
@export var enemy_scene: PackedScene = preload("res://units/enemy.tscn")
@export var spawn_interval: float = 5.0  # Seconds between spawns
@export var max_active_enemies: int = 10  # Maximum enemies this spawner can have active
@export var spawn_on_start: bool = true  # Spawn immediately when ready

@export_group("Enemy Behavior")
@export var use_rally_point: bool = false  # Enable/disable rally waypoint
@export var rally_point: Vector3 = Vector3.ZERO  # Where spawned enemies should go
@export var auto_find_rally_point: bool = true  # Automatically find nearest player building (only if use_rally_point is enabled)

@export_group("Selection")
@export var selected: bool = false:
	set(value):
		selected = value
		_update_selection_visual()

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var spawn_point: Marker3D = $SpawnPoint
@onready var model: Node3D = $Model

# ============================================================================
# STATE VARIABLES
# ============================================================================
var spawn_timer: float = 0.0
var active_enemies: Array = []  # Track spawned enemies
var is_spawning: bool = true

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	add_to_group("buildings")
	add_to_group("enemy_spawners")

	# Auto-find rally point if use_rally_point and auto_find are both enabled
	if use_rally_point and auto_find_rally_point and rally_point == Vector3.ZERO:
		_find_rally_point()

	# Spawn immediately if enabled
	if spawn_on_start:
		_spawn_enemy()

	_update_selection_visual()

# ============================================================================
# PROCESS
# ============================================================================
func _process(delta: float) -> void:
	if not is_spawning:
		return

	# Clean up dead enemies from tracking
	_cleanup_dead_enemies()

	# Check if we can spawn more enemies
	if active_enemies.size() >= max_active_enemies:
		return

	# Increment spawn timer
	spawn_timer += delta

	# Spawn when timer reaches interval
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		_spawn_enemy()

# ============================================================================
# SPAWNING SYSTEM
# ============================================================================

func _spawn_enemy() -> void:
	if not enemy_scene:
		push_error("Enemy spawner: No enemy scene assigned!")
		return

	# Instantiate enemy
	var enemy = enemy_scene.instantiate()

	# Position enemy at spawn point
	if spawn_point:
		enemy.global_position = spawn_point.global_position
	else:
		enemy.global_position = global_position + Vector3(0, 0, 2)

	# Add random offset to avoid stacking
	var offset = Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	enemy.global_position += offset

	# Set enemy rally point only if use_rally_point is enabled
	if use_rally_point and rally_point != Vector3.ZERO:
		# Send enemy to rally point
		enemy.target_point = rally_point
		print("Enemy spawner '%s' spawned enemy at %s, sending to rally point: %s (Total: %d/%d)"
			% [name, enemy.global_position, rally_point, active_enemies.size() + 1, max_active_enemies])
	else:
		# Keep enemy near spawner (idle)
		print("Enemy spawner '%s' spawned enemy at %s, staying near spawner (Total: %d/%d)"
			% [name, enemy.global_position, active_enemies.size() + 1, max_active_enemies])

	# Add to world
	get_tree().root.add_child(enemy)

	# Track enemy
	active_enemies.append(enemy)

func _cleanup_dead_enemies() -> void:
	# Remove invalid/dead enemies from tracking
	active_enemies = active_enemies.filter(func(enemy): return is_instance_valid(enemy))

func _find_rally_point() -> void:
	# Find nearest player building (like townhall) as rally point
	var buildings = get_tree().get_nodes_in_group("buildings")
	var nearest_dist = INF
	var nearest_building = null

	for building in buildings:
		# Skip enemy spawners
		if building.is_in_group("enemy_spawners"):
			continue

		var dist = global_position.distance_to(building.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_building = building

	if nearest_building:
		rally_point = nearest_building.global_position
		print("Enemy spawner '%s' found rally point: %s" % [name, rally_point])
	else:
		# Default to origin if no buildings found
		rally_point = Vector3.ZERO
		print("Enemy spawner '%s' no rally point found, using origin" % name)

# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

## Set the rally point where enemies should go
func set_rally_point(point: Vector3) -> void:
	rally_point = point
	print("Enemy spawner '%s' rally point set to: %s" % [name, rally_point])

	# Update existing enemies if rally point is enabled
	if use_rally_point:
		_update_existing_enemies_rally_point()

## Enable/disable rally point for spawned enemies
func set_use_rally_point(enabled: bool) -> void:
	use_rally_point = enabled
	print("Enemy spawner '%s' rally point %s" % [name, "enabled" if enabled else "disabled"])

	# Update existing enemies
	if enabled and rally_point != Vector3.ZERO:
		_update_existing_enemies_rally_point()

## Update existing enemies with new rally point setting
func _update_existing_enemies_rally_point() -> void:
	_cleanup_dead_enemies()
	for enemy in active_enemies:
		if is_instance_valid(enemy) and enemy.has_method("move_to_point"):
			enemy.move_to_point(rally_point)

## Start/stop spawning
func set_spawning(enabled: bool) -> void:
	is_spawning = enabled
	print("Enemy spawner '%s' spawning %s" % [name, "enabled" if enabled else "disabled"])

## Manually trigger a spawn
func spawn_now() -> void:
	_spawn_enemy()

## Get count of active enemies
func get_active_enemy_count() -> int:
	_cleanup_dead_enemies()
	return active_enemies.size()

# ============================================================================
# SELECTION VISUAL
# ============================================================================

func _update_selection_visual() -> void:
	if not model:
		return

	var overlay_material = null
	if selected:
		overlay_material = preload("res://materials/selected_outline.tres")

	_apply_overlay_recursive(model, overlay_material)

func _apply_overlay_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_overlay = mat

	for child in node.get_children():
		_apply_overlay_recursive(child, mat)