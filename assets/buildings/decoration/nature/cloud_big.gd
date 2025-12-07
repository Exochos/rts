extends Node3D

@onready var cloud = $cloud_big
func set_cloud_alpha(value: float):
    var mat: Material = cloud.get_active_material(0)
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color.a = clamp(value, 0.0, 0.01)
