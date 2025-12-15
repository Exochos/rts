extends Node
## Global resource manager for tracking player resources
##
## This singleton manages all player resources (wood, gold, ore, supply)
## and emits signals when resources change so UI can update

# Resource storage
var wood: int = 0
var gold: int = 0
var ore: int = 0
var supply_current: int = 0
var supply_max: int = 10

# Signals for UI updates
signal resources_changed(wood: int, gold: int, ore: int, supply_current: int, supply_max: int)

func _ready() -> void:
	print("ResourceManager initialized")
	print("Starting resources - Wood: %d, Gold: %d, Ore: %d, Supply: %d/%d" % [wood, gold, ore, supply_current, supply_max])

## Add resources to the stockpile
func add_resource(resource_type: String, amount: int) -> void:
	match resource_type.to_lower():
		"wood":
			wood += amount
			print("Added %d wood. Total: %d" % [amount, wood])
		"gold":
			gold += amount
			print("Added %d gold. Total: %d" % [amount, gold])
		"ore":
			ore += amount
			print("Added %d ore. Total: %d" % [amount, ore])
		_:
			print("Warning: Unknown resource type '%s'" % resource_type)
			return

	_emit_change()

## Remove resources from the stockpile (for building costs, etc.)
func remove_resource(resource_type: String, amount: int) -> bool:
	match resource_type.to_lower():
		"wood":
			if wood >= amount:
				wood -= amount
				_emit_change()
				return true
			return false
		"gold":
			if gold >= amount:
				gold -= amount
				_emit_change()
				return true
			return false
		"ore":
			if ore >= amount:
				ore -= amount
				_emit_change()
				return true
			return false
		_:
			print("Warning: Unknown resource type '%s'" % resource_type)
			return false

## Check if player has enough resources
func has_resources(wood_cost: int = 0, gold_cost: int = 0, ore_cost: int = 0) -> bool:
	return wood >= wood_cost and gold >= gold_cost and ore >= ore_cost

## Get current amount of a specific resource
func get_resource(resource_type: String) -> int:
	match resource_type.to_lower():
		"wood":
			return wood
		"gold":
			return gold
		"ore":
			return ore
		_:
			return 0

## Modify supply
func add_supply(amount: int) -> void:
	supply_current += amount
	supply_current = clamp(supply_current, 0, supply_max)
	_emit_change()

func increase_supply_max(amount: int) -> void:
	supply_max += amount
	_emit_change()

## Emit signal to update UI
func _emit_change() -> void:
	resources_changed.emit(wood, gold, ore, supply_current, supply_max)