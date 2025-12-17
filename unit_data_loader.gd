extends Node
## Global unit and building data loader
##
## This singleton loads unit/building stats from JSON and provides
## easy access to costs, supply requirements, and other properties

var unit_data: Dictionary = {}
var building_data: Dictionary = {}

func _ready() -> void:
	_load_data()

func _load_data() -> void:
	var file_path = "res://data/unit_data.json"
	var file = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		push_error("Failed to open unit data file: %s" % file_path)
		return

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)

	if error != OK:
		push_error("Failed to parse JSON: %s" % json.get_error_message())
		return

	var data = json.data

	if data.has("units"):
		unit_data = data["units"]

	if data.has("buildings"):
		building_data = data["buildings"]

	print("UnitDataLoader initialized with %d units and %d buildings" % [unit_data.size(), building_data.size()])

## Get unit data by unit type (e.g., "worker")
func get_unit_data(unit_type: String) -> Dictionary:
	if unit_data.has(unit_type):
		return unit_data[unit_type]

	push_warning("Unit type '%s' not found in data" % unit_type)
	return {}

## Get building data by building type (e.g., "townhall")
func get_building_data(building_type: String) -> Dictionary:
	if building_data.has(building_type):
		return building_data[building_type]

	push_warning("Building type '%s' not found in data" % building_type)
	return {}

## Get gold cost for a unit
func get_unit_cost(unit_type: String, resource_type: String = "gold") -> int:
	var data = get_unit_data(unit_type)
	if data.has("cost") and data["cost"].has(resource_type):
		return data["cost"][resource_type]
	return 0

## Get supply cost for a unit
func get_unit_supply_cost(unit_type: String) -> int:
	var data = get_unit_data(unit_type)
	if data.has("supply_cost"):
		return data["supply_cost"]
	return 0

## Check if player can afford a unit (resources + supply)
func can_afford_unit(unit_type: String) -> Dictionary:
	var data = get_unit_data(unit_type)

	if data.is_empty():
		return {"can_afford": false, "reason": "Unit data not found"}

	# Check resource costs
	var cost = data.get("cost", {})
	var gold_cost = cost.get("gold", 0)
	var wood_cost = cost.get("wood", 0)
	var ore_cost = cost.get("ore", 0)

	if not ResourceManager.has_resources(wood_cost, gold_cost, ore_cost):
		return {"can_afford": false, "reason": "Not enough resources"}

	# Check supply
	var supply_cost = data.get("supply_cost", 0)
	if ResourceManager.supply_current + supply_cost > ResourceManager.supply_max:
		return {"can_afford": false, "reason": "Not enough supply"}

	return {"can_afford": true, "reason": ""}

## Deduct costs for training a unit (resources + supply)
func pay_for_unit(unit_type: String) -> bool:
	var data = get_unit_data(unit_type)

	if data.is_empty():
		push_error("Cannot pay for unit: data not found for '%s'" % unit_type)
		return false

	# Check if can afford first
	var afford_check = can_afford_unit(unit_type)
	if not afford_check["can_afford"]:
		print("Cannot afford %s: %s" % [unit_type, afford_check["reason"]])
		return false

	# Deduct resources
	var cost = data.get("cost", {})
	var gold_cost = cost.get("gold", 0)
	var wood_cost = cost.get("wood", 0)
	var ore_cost = cost.get("ore", 0)

	if gold_cost > 0:
		ResourceManager.remove_resource("gold", gold_cost)
	if wood_cost > 0:
		ResourceManager.remove_resource("wood", wood_cost)
	if ore_cost > 0:
		ResourceManager.remove_resource("ore", ore_cost)

	# Add to supply
	var supply_cost = data.get("supply_cost", 0)
	if supply_cost > 0:
		ResourceManager.add_supply(supply_cost)

	print("Trained %s - Costs: Gold:%d Wood:%d Ore:%d Supply:%d" % [unit_type, gold_cost, wood_cost, ore_cost, supply_cost])
	return true