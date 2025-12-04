extends Node3D

#Export variables
@export_range(0,100,1) var camera_move_speed:float = 20.00
@export_range(0,1,0.01) var camera_zoom_speed:float = 0.10
@export_range(1,100,1) var camera_zoom_min:float = 10.00
@export_range(1,100,1) var camera_zoom_max:float = 50.00

#Nodes 
@onready var camera_pivot:Node3D = $camera_pivot
@onready var camera:Camera3D = $camera_pivot/Camera3D

func _ready() -> void:
	pass

func _process(delta: float) -> void:
		var direction := Vector3.ZERO

		# camera-relative axes
		var forward = transform.basis.x
		var right   =  transform.basis.z

		if Input.is_action_pressed("camera_forward"):
				direction += forward
		if Input.is_action_pressed("camera_backward"):
				direction -= forward
		if Input.is_action_pressed("camera_left"):
				direction -= right
		if Input.is_action_pressed("camera_right"):
				direction += right

		if direction != Vector3.ZERO:
				move_camera(direction, delta)
	
func _unhandled_input(event: InputEvent) -> void:
		# Zoom --------------------------------------
		if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
						zoom_camera(1)
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
						zoom_camera(-1)

		if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_MIDDLE:
						if event.pressed:
								Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
						else:
								Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
				orbit_camera(event)

func move_camera(direction:Vector3, delta:float) -> void:
		var move_vector:Vector3 = direction.normalized() * camera_move_speed * delta
		global_position += move_vector

func zoom_camera(amount:float) -> void:
		var new_fov:float = camera.fov - amount * camera_zoom_speed * camera.fov
		new_fov = clamp(new_fov, camera_zoom_min, camera_zoom_max)
		camera.fov = new_fov

func orbit_camera(event: InputEventMouseMotion) -> void:
		var sensitivity := 0.003
		rotate_y(-event.relative.x * sensitivity)
