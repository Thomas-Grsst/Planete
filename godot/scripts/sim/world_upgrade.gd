class_name WorldUpgrade
extends RefCounted


static func run(state: Dictionary) -> void:
	var world: Dictionary = state["world"]
	if not world.has("depleted"):
		Nature.ensure(world)
		var size: int = world.get("size", WorldGen.SIZE)
		for i in world["tiles"].size():
			var t: Dictionary = world["tiles"][i]
			if t["food"] < Nature.food_cap(t):
				Nature.mark_food(world, i % size, i / size)
