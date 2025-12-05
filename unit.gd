extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D # Make sure you add this node if you use navigation!
@onready var selector = $Selector # Assuming "Selector" is the visual ring

# This is the variable the RTS Controller is trying to set
var selected: bool = false:
	set(value):
		selected = value
		_update_selection_visual()

func _update_selection_visual():
		var mesh_node = $unit 
		
		if not mesh_node:
				return
		if selected:
				mesh_node.material_overlay = preload("res://materials/selected_outline.tres")
		else:
				mesh_node.material_overlay = null

# Basic movement setup
var speed = 8.0
var target_pos: Vector3 = Vector3.ZERO
var moving = false

func _ready():
	# Ensure the selection ring is hidden by default
	if selector:
		selector.visible = false

func _physics_process(_delta):
	if moving:
		# Simple movement logic (replace with NavigationAgent logic for obstacles)
		var direction = (target_pos - global_position).normalized()
		velocity = direction * speed
		
		# Stop if close enough
		if global_position.distance_to(target_pos) < 0.5:
			velocity = Vector3.ZERO
			moving = false
			
		move_and_slide()

# The RTS Controller calls this function
func move_to_position(pos: Vector3):
	print("Unit received move command to: ", pos)
	target_pos = pos
	target_pos.y = global_position.y # Keep height consistent
	moving = true

# The RTS Controller calls this function
func attack_target(target_node):
	print("Unit attacking: ", target_node.name)
	# Add attack logic here