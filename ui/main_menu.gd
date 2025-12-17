extends Control
## Main Menu Scene
##
## Handles navigation between game start, settings, credits, and quit

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var new_game_button: Button = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/NewGameButton
@onready var continue_button: Button = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/ContinueButton
@onready var settings_button: Button = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/SettingsButton
@onready var credits_button: Button = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/CreditsButton
@onready var quit_button: Button = $CenterContainer/MenuPanel/MarginContainer/VBoxContainer/QuitButton

# ============================================================================
# SCENE PATHS
# ============================================================================
const GAME_SCENE = "res://world.tscn"
const SETTINGS_SCENE = "res://ui/settings_menu.tscn"

# ============================================================================
# INITIALIZATION
# ============================================================================
func _ready() -> void:
	# Connect button signals
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	credits_button.pressed.connect(_on_credits_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	# Check if save file exists to enable/disable continue button
	_check_save_file()

	# Focus new game button by default
	new_game_button.grab_focus()

# ============================================================================
# BUTTON CALLBACKS
# ============================================================================

func _on_new_game_pressed() -> void:
	print("Starting new game...")
	# Reset resources to starting values
	ResourceManager.wood = 100
	ResourceManager.gold = 500
	ResourceManager.ore = 0
	ResourceManager.supply_current = 0
	ResourceManager.supply_max = 10

	# Load game scene
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_continue_pressed() -> void:
	print("Continuing game...")
	# TODO: Load save data
	get_tree().change_scene_to_file(GAME_SCENE)

func _on_settings_pressed() -> void:
	print("Opening settings...")
	# Load settings menu
	get_tree().change_scene_to_file(SETTINGS_SCENE)

func _on_credits_pressed() -> void:
	print("Showing credits...")
	# Show credits popup
	_show_credits_popup()

func _on_quit_pressed() -> void:
	print("Quitting game...")
	get_tree().quit()

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _check_save_file() -> void:
	# Check if save file exists
	# For now, disable continue button (no save system yet)
	continue_button.disabled = true

func _show_credits_popup() -> void:
	# Create a simple popup for credits
	var popup = AcceptDialog.new()
	popup.dialog_text = """RTS Commander

Created with Godot Engine 4.6

Game Design & Development
- RTS Commander Team

Assets
- Character Models: Kenney.nl
- Building Models: Kenney.nl

Special Thanks
- Godot Engine Community
- All Playtesters

Thank you for playing!"""
	popup.title = "Credits"
	popup.size = Vector2(400, 350)
	add_child(popup)
	popup.popup_centered()