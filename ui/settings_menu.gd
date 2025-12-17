extends Control
## Settings Menu Scene
##
## Handles audio, graphics, and other game settings

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var master_volume_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/AudioSection/MasterVolumeContainer/MasterVolumeSlider
@onready var master_volume_value: Label = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/AudioSection/MasterVolumeContainer/MasterVolumeValue
@onready var music_volume_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/AudioSection/MusicVolumeContainer/MusicVolumeSlider
@onready var music_volume_value: Label = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/AudioSection/MusicVolumeContainer/MusicVolumeValue
@onready var sfx_volume_slider: HSlider = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/AudioSection/SFXVolumeContainer/SFXVolumeSlider
@onready var sfx_volume_value: Label = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/AudioSection/SFXVolumeContainer/SFXVolumeValue

@onready var fullscreen_checkbox: CheckBox = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/GraphicsSection/FullscreenContainer/FullscreenCheckbox
@onready var vsync_checkbox: CheckBox = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/GraphicsSection/VsyncContainer/VsyncCheckbox

@onready var back_button: Button = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/ButtonsContainer/BackButton
@onready var apply_button: Button = $CenterContainer/SettingsPanel/MarginContainer/VBoxContainer/ButtonsContainer/ApplyButton

# ============================================================================
# CONSTANTS
# ============================================================================
const MAIN_MENU_SCENE = "res://ui/main_menu.tscn"

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	# Connect button signals
	back_button.pressed.connect(_on_back_pressed)
	apply_button.pressed.connect(_on_apply_pressed)

	# Connect slider signals
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)

	# Connect checkbox signals
	fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	vsync_checkbox.toggled.connect(_on_vsync_toggled)

	# Load saved settings
	_load_settings()

	# Focus back button
	back_button.grab_focus()

# ============================================================================
# SETTINGS MANAGEMENT
# ============================================================================

func _load_settings() -> void:
	# Load settings from ProjectSettings or saved config
	# For now, use default values

	# Audio settings
	var master_volume = 100.0
	var music_volume = 80.0
	var sfx_volume = 100.0

	master_volume_slider.value = master_volume
	music_volume_slider.value = music_volume
	sfx_volume_slider.value = sfx_volume

	# Graphics settings
	var is_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fullscreen_checkbox.button_pressed = is_fullscreen

	var vsync_enabled = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	vsync_checkbox.button_pressed = vsync_enabled

func _save_settings() -> void:
	# TODO: Save settings to file
	print("Settings saved:")
	print("  Master Volume: %d%%" % master_volume_slider.value)
	print("  Music Volume: %d%%" % music_volume_slider.value)
	print("  SFX Volume: %d%%" % sfx_volume_slider.value)
	print("  Fullscreen: %s" % fullscreen_checkbox.button_pressed)
	print("  VSync: %s" % vsync_checkbox.button_pressed)

# ============================================================================
# AUDIO CALLBACKS
# ============================================================================

func _on_master_volume_changed(value: float) -> void:
	master_volume_value.text = "%d%%" % int(value)
	# TODO: Apply to audio bus
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value / 100.0))

func _on_music_volume_changed(value: float) -> void:
	music_volume_value.text = "%d%%" % int(value)
	# TODO: Apply to music bus
	# AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(value / 100.0))

func _on_sfx_volume_changed(value: float) -> void:
	sfx_volume_value.text = "%d%%" % int(value)
	# TODO: Apply to SFX bus
	# AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value / 100.0))

# ============================================================================
# GRAPHICS CALLBACKS
# ============================================================================

func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_vsync_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

# ============================================================================
# BUTTON CALLBACKS
# ============================================================================

func _on_back_pressed() -> void:
	# Return to main menu without saving
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)

func _on_apply_pressed() -> void:
	# Save settings and return to main menu
	_save_settings()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)