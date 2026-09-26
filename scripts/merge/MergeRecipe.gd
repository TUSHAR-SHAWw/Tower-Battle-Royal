class_name MergeRecipe
extends Resource

## Defines a merge: inputs -> output with cost/success chance.

@export var input_item: ItemResource
@export var input_count: int = 2
@export var output_item: ItemResource
@export var gold_cost: int = 0
@export var success_chance: float = 1.0
@export var xp_reward: int = 10

func validate() -> Array[String]:
	var problems: Array[String] = []
	if input_item == null:
		problems.append("input_item required")
	if output_item == null:
		problems.append("output_item required")
	if input_count < 2:
		problems.append("input_count must be >= 2")
	if success_chance < 0.0 or success_chance > 1.0:
		problems.append("success_chance must be 0.0-1.0")
	return problems