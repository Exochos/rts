extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D # Make sure you add this node if you use navigation!
@onready var selector = $Selector # Assuming "Selector" is the visual ring
@onready var anim: AnimationPlayer = $Skeleton_Minion/AnimationPlayer


@export var selected: bool = false:
		set(value):
				selected = value
				_update_selection_visual()

func _ready():
		# Initialize unselected
		_update_selection_visual()

func _update_selection_visual():
		# 1. Change this path to match your scene tree (Skeleton_Minion)
		var model_node = $Skeleton_Minion 
		if not model_node: return
		
		var overlay_material = null
		if selected:
				# 2. Use the same material resource you made for the house
				overlay_material = preload("res://materials/selected_outline.tres")
		
		_apply_overlay_recursive(model_node, overlay_material)

func _apply_overlay_recursive(node: Node, mat: Material):
		# This check works for character meshes too!
		if node is MeshInstance3D:
				node.material_overlay = mat
		
		for child in node.get_children():
				_apply_overlay_recursive(child, mat)

# Basic movement setup
var speed = 2.0
var target_pos: Vector3 = Vector3.ZERO
var moving = false


func _physics_process(_delta):
	if moving:
		var direction = (target_pos - global_position).normalized()
		velocity = direction * speed

		# Rotate worker as it moves
		look_at(global_position + direction, Vector3.UP)

		if global_position.distance_to(target_pos) < 0.5:
			velocity = Vector3.ZERO
			moving = false
	else:
		velocity = Vector3.ZERO

	move_and_slide()

	_update_animation()

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

func _update_animation():
	if moving:
		if anim.current_animation != "worker/Running_B":
			anim.play("worker/Running_B")
	else:
		if anim.current_animation != "worker/Jump_Idle":
			anim.play("worker/Jump_Idle")
