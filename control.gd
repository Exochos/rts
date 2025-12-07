extends Control

@onready var label := $Label


func _process(_delta: float) -> void:
	label.add_theme_color_override("font_color", Color(1, 0, 0))
	label.text = "FPS: %d" % Engine.get_frames_per_second()
