class_name Regions
extends RefCounted

const NONE := -1
const C := TerrainGen.CHUNK


static func invalidate(world: Dictionary) -> void:
	world["rev"] = world.get("rev", 0) + 1


static func _data(world: Dictionary) -> Dictionary:
	var r = world.get("regions")
	if r == null or r["rev"] != world["rev"]:
		r = {"rev": world["rev"], "labels": {}, "parent": {}, "next": 0}
		world["regions"] = r
		for key in world["chunks"]:
			_label(world, r, key)
	return r


static func add_chunk(world: Dictionary, key: Vector2i) -> void:
	var r = world.get("regions")
	if r != null and r["rev"] == world["rev"]:
		_label(world, r, key)


static func at(world: Dictionary, x: int, y: int) -> int:
	var r := _data(world)
	var labels = r["labels"].get(Vector2i(x >> 4, y >> 4))
	if labels == null:
		return NONE
	var id: int = labels[((y & 15) << 4) | (x & 15)]
	return NONE if id == NONE else _find(r["parent"], id)


static func same_landmass(world: Dictionary, ax: int, ay: int, bx: int, by: int) -> bool:
	var a := at(world, ax, ay)
	return a >= 0 and a == at(world, bx, by)


static func _find(parent: Dictionary, a: int) -> int:
	var root := a
	while parent[root] != root:
		root = parent[root]
	while parent[a] != root:
		var up: int = parent[a]
		parent[a] = root
		a = up
	return root


static func _union(parent: Dictionary, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb:
		parent[max(ra, rb)] = min(ra, rb)


static func _label(world: Dictionary, r: Dictionary, key: Vector2i) -> void:
	var tiles: Array = world["chunks"][key]["tiles"]
	var labels := PackedInt32Array()
	labels.resize(C * C)
	labels.fill(NONE)
	for start in C * C:
		if labels[start] != NONE or not Biomes.walkable(tiles[start]["biome"]):
			continue
		var id: int = r["next"]
		r["next"] += 1
		r["parent"][id] = id
		labels[start] = id
		var stack: Array[int] = [start]
		while not stack.is_empty():
			var i: int = stack.pop_back()
			var x := i % C
			var y := i / C
			for j in [i - 1 if x > 0 else -1, i + 1 if x < C - 1 else -1, i - C if y > 0 else -1, i + C if y < C - 1 else -1]:
				if j >= 0 and labels[j] == NONE and Biomes.walkable(tiles[j]["biome"]):
					labels[j] = id
					stack.append(j)
	r["labels"][key] = labels
	_stitch(r, key, labels, Vector2i(1, 0))
	_stitch(r, key, labels, Vector2i(-1, 0))
	_stitch(r, key, labels, Vector2i(0, 1))
	_stitch(r, key, labels, Vector2i(0, -1))


static func _stitch(r: Dictionary, key: Vector2i, labels: PackedInt32Array, dir: Vector2i) -> void:
	var other = r["labels"].get(key + dir)
	if other == null:
		return
	for k in C:
		var mine: int
		var theirs: int
		if dir.x != 0:
			mine = k * C + (C - 1 if dir.x > 0 else 0)
			theirs = k * C + (0 if dir.x > 0 else C - 1)
		else:
			mine = (C - 1 if dir.y > 0 else 0) * C + k
			theirs = (0 if dir.y > 0 else C - 1) * C + k
		if labels[mine] != NONE and other[theirs] != NONE:
			_union(r["parent"], labels[mine], other[theirs])
