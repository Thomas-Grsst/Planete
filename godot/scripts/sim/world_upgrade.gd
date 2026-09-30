class_name WorldUpgrade
extends RefCounted

const OLD_SIZE := 48


static func run(state: Dictionary) -> void:
	var world: Dictionary = state["world"]
	if world.has("tiles"):
		_to_chunks(state, world)


static func _to_chunks(state: Dictionary, world: Dictionary) -> void:
	var size: int = world.get("size", OLD_SIZE)
	var seed_value: int = state["seed"]
	var chunks := {}
	var lava := {}
	for i in world["tiles"].size():
		var x: int = i % size
		var y: int = i / size
		var key := WorldGen.key_of(x, y)
		if not chunks.has(key):
			var empty: Array = []
			empty.resize(WorldGen.CHUNK * WorldGen.CHUNK)
			chunks[key] = {"tiles": empty}
		var t: Dictionary = world["tiles"][i]
		chunks[key]["tiles"][((y & WorldGen.LOCAL) << WorldGen.SHIFT) | (x & WorldGen.LOCAL)] = t
		if t["biome"] == "lava":
			lava[Vector2i(x, y)] = true
	for key in chunks:
		var tiles: Array = chunks[key]["tiles"]
		for j in tiles.size():
			if tiles[j] == null:
				tiles[j] = TerrainGen.tile(seed_value, key.x * WorldGen.CHUNK + (j & WorldGen.LOCAL), key.y * WorldGen.CHUNK + (j >> WorldGen.SHIFT))
	world.erase("tiles")
	world.erase("size")
	world.merge({"version": WorldGen.VERSION, "seed": seed_value, "chunks": chunks, "rev": 0, "start": Vector2i(size / 2, size / 2), "lava": lava}, true)
	world.erase("regions")
	Nature.ensure(world)
	for key in chunks:
		var tiles: Array = chunks[key]["tiles"]
		for j in tiles.size():
			if tiles[j]["food"] < Nature.food_cap(tiles[j]):
				Nature.mark_food(world, key.x * WorldGen.CHUNK + (j & WorldGen.LOCAL), key.y * WorldGen.CHUNK + (j >> WorldGen.SHIFT))
