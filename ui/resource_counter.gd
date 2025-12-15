extends Control
## Resource counter UI that displays wood, gold, ore, and supply in top-right corner

@onready var wood_label: Label = $VBoxContainer/WoodLabel
@onready var gold_label: Label = $VBoxContainer/GoldLabel
@onready var ore_label: Label = $VBoxContainer/OreLabel
@onready var supply_label: Label = $VBoxContainer/SupplyLabel

func _ready() -> void:
	# Connect to resource manager signals
	ResourceManager.resources_changed.connect(_on_resources_changed)

	# Initialize with current values
	_update_display(
		ResourceManager.wood,
		ResourceManager.gold,
		ResourceManager.ore,
		ResourceManager.supply_current,
		ResourceManager.supply_max
	)

func _on_resources_changed(wood: int, gold: int, ore: int, supply_current: int, supply_max: int) -> void:
	_update_display(wood, gold, ore, supply_current, supply_max)

func _update_display(wood: int, gold: int, ore: int, supply_current: int, supply_max: int) -> void:
	wood_label.text = "Wood: %d" % wood
	gold_label.text = "Gold: %d" % gold
	ore_label.text = "Ore: %d" % ore
	supply_label.text = "Supply: %d/%d" % [supply_current, supply_max]