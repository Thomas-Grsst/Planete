class_name Regions
extends RefCounted

const NONE := -1

static var _world: Dictionary = {}
static var _regions := PackedInt32Array()


static func invalidate() -> void:
	_world = {}


static func of(world: Dictionary) -> PackedInt32Array:
	if not is_same(_world, world):
		_world = world
		_regions = _compute(world)
	return _regions


static func at(world: Dictionary, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= WorldGen.SIZE or y >= WorldGen.SIZE:
		return NONE
	return of(world)[y * WorldGen.SIZE + x]


static func same_landmass(world: Dictionary, ax: int, ay: int, bx: int, by: int) -> bool:
	var a := at(world, ax, ay)
	return a >= 0 and a == at(world, bx, by)


static func _compute(world: Dictionary) -> PackedInt32Array:
	var size := WorldGen.SIZE
	var regions := PackedInt32Array()
	regions.resize(size * size)
	regions.fill(NONE)
	var next_region := 0
	for start in regions.size():
		if regions[start] != NONE or not WorldGen.is_walkable(world, start % size, start / size):
			continue
		var stack: Array[int] = [start]
		regions[start] = next_region
		while not stack.is_empty():
			var i: int = stack.pop_back()
			for j in WorldGen.neighbors(i):
				if regions[j] == NONE and WorldGen.is_walkable(world, j % size, j / size):
					regions[j] = next_region
					stack.append(j)
		next_region += 1
	return regions
