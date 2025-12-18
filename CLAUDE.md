# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a real-time strategy (RTS) game built with Godot 4.6. The game features unit selection, movement, building interactions, and a command card UI system similar to classic RTS games like StarCraft or Warcraft.

## Running the Project

The project runs in Godot Engine 4.6. The main scene is `world.tscn`.

To run the game:
- Open the project in Godot Editor 4.6+
- Press F5 or click the "Run Project" button
- The game will launch with `res://world.tscn` as defined in `project.godot`

## Architecture Overview

### Core Systems

**RTS Controller** (`core/rts_controller.gd`)
- Central input handler attached to the World scene
- Manages unit/building selection via box selection and single-click
- Handles right-click commands for movement
- Maintains `selected_units` array and delegates commands to selected entities
- Uses Godot groups: `"units"` and `"buildings"` to identify selectable objects
- Updates the CommandCard UI when selection changes

**Camera System** (`camera/RTS_Camera_.gd`)
- WASD movement controls
- Mouse wheel zoom (adjusts FOV, not position)
- Middle-mouse drag for orbital rotation
- Camera is parented to a pivot node for rotation

**Selection Visual System**
- Both units and buildings use `material_overlay` on MeshInstance3D nodes
- Selected state applies `res://materials/selected_outline.tres`
- Uses recursive `_apply_overlay_recursive()` to find all child meshes

### Entity Architecture

**Base Unit Class** (`unit.gd`)
- Extends `CharacterBody3D`
- Must be added to group `"units"` in the scene
- Required property: `selected: bool` (setter updates visual state)
- Required methods:
  - `move_to_position(pos: Vector3)` - called by RTS controller on right-click
  - `_update_selection_visual()` - applies outline material when selected
- Animation system integrated via AnimationPlayer

**Worker Unit** (`units/worker.gd`, `units/worker.tscn`)
- Implements basic movement with velocity-based physics
- Plays "worker/Running_B" when moving, "worker/Jump_Idle" when idle
- Uses simple target-based movement (not NavigationAgent3D yet)

**Building Class** (`town/townhall.gd`)
- Extends `Node3D`
- Must be added to group `"buildings"` in the scene
- Required property: `selected: bool`
- Optional method: `get_command_options()` - returns array of command dictionaries for CommandCard
- Command dictionary format:
  ```gdscript
  {
    "name": "Button Label",
    "cost": 50,                                    # Optional
    "icon": preload("res://path/to/icon.png"),    # Optional
    "callable": Callable(self, "_method_name")
  }
  ```

**Resource Gathering** (`gatherable_resource.gd`)
- Class name: `GatherableResource`, extends `StaticBody3D`
- Exported properties: `resource_name`, `amount`, `max_amount`
- Method: `gather(gather_power: int)` - depletes resource and hides mesh when empty

### UI Systems

**Command Card** (`ui/command_card.gd`)
- Bottom-right UI panel that displays commands for selected units/buildings
- Only visible when exactly one unit/building is selected
- Dynamically creates buttons from `get_command_options()` return value
- Buttons connect directly to callable references from selected entity

**Selection Box** (`ui/selection_box`)
- ColorRect overlay for drag selection
- Controlled by rts_controller during drag operations

### Input Actions

Defined in `project.godot`:
- `camera_forward` - W key
- `camera_backward` - S key
- `camera_left` - A key
- `camera_right` - D key

Mouse inputs handled directly via `InputEventMouseButton`:
- Left-click drag: box selection
- Left-click release: finalize selection
- Right-click: move command for selected units
- Middle-mouse drag: orbit camera
- Scroll wheel: zoom camera

### Important Patterns

**Selection Flow:**
1. User clicks/drags with left mouse button
2. `rts_controller._select_units_in_box()` or `_single_click_select()` runs
3. Results passed to `_apply_selection(new_selection: Array)`
4. Previous selection cleared (`selected = false`), new selection applied (`selected = true`)
5. CommandCard updated with `command_card.update_selection(selected_units)`

**Movement Flow:**
1. User right-clicks with units selected
2. `rts_controller._handle_right_click()` casts ray into 3D world
3. If hit object is not in `"units"` or `"enemies"` groups, treat as movement
4. Call `move_to_position(result.position)` on all selected units
5. Units update their internal `target_pos` and `moving` flags

**Resource Gathering Flow:**
1. User right-clicks on a gatherable resource (tree, gold, etc.) with workers selected
2. `rts_controller._handle_right_click()` detects object in `"gatherable"` group
3. Calls `gather_from_resource(resource_node)` on all selected workers
4. Worker moves to resource if distance > 4.0, otherwise starts gathering immediately
5. Worker gathers resources every `gather_interval` seconds until inventory is full
6. Worker automatically returns to nearest townhall when carrying capacity is reached
7. Worker deposits resources and returns to gathering if resource still exists
8. If resource is depleted, worker automatically searches for nearby resources of the same type within 20 units
9. If no nearby resources found, worker goes idle

**Command Execution:**
1. Building/unit selected, CommandCard becomes visible
2. CommandCard calls `get_command_options()` on selected entity
3. Buttons created with callable references
4. User clicks button, callable executes directly on the entity (e.g., `townhall._train_worker()`)

### Scene Structure

Main scene: `world.tscn`
- Contains: floor, lighting, camera_base, ui layer, rts_controller, entities
- NavigationRegion3D attached to floor (currently unused by units)

### Asset Organization

- `core/` - Core game systems (RTS controller, game state management)
- `camera/` - Camera controller scripts
- `ui/` - UI components (command card, resource counter, menus, FPS display)
- `assets/characters/` - Character models and animations
- `assets/characters/animations/extracted_animations/` - Extracted animation resources (.res files)
- `assets/buildings/` - Building models and decorations
- `assets/gltf/` - Imported GLTF models (trees, rocks, etc.)
- `materials/` - Material resources including selection outline
- `units/` - Unit scenes and scripts
- `town/` - Building scenes and scripts
- `environment/` - Environment objects like trees, rocks, and resource nodes

## Development Notes

### Adding New Units

1. Extend `CharacterBody3D` or inherit from `unit.gd`
2. Add to group `"units"` in the scene tree
3. Implement `selected` property with setter
4. Implement `move_to_position(pos: Vector3)` method
5. Implement `_update_selection_visual()` to apply material overlay

### Adding New Buildings

1. Extend `Node3D`
2. Add to group `"buildings"` in the scene tree
3. Implement `selected` property with setter
4. Optionally implement `get_command_options()` to add commands to CommandCard
5. Implement `_update_selection_visual()` using recursive overlay pattern

### Animation Path Convention

Animations are referenced with prefix format: `"unit_name/AnimationName"`
- Example: `"worker/Running_B"`, `"worker/Jump_Idle"`
- This matches the structure of extracted animation resources

### Physics and Collision

- Floor uses `StaticBody3D` with `ConcavePolygonShape3D`
- Units are `CharacterBody3D` (require collision shapes for selection)
- Raycasting uses collision mask `4294967295` (all layers)
- Areas can be raycast by setting `query.collide_with_areas = true`

### Common Debugging

- RTS controller prints selection count on each selection change
- Movement commands print target positions
- Check group membership with `get_tree().get_nodes_in_group("units")`
- Ensure collision shapes exist on all selectable entities
- Verify `selected` property has a setter that calls `_update_selection_visual()`