class_name Nature
extends RefCounted

const REGROW_EVERY := 4
const FOOD_CAP := 12.0
const FOOD_GROWTH := 0.7
const FISH_CAP := {"ocean": 20.0, "lake": 14.0, "river": 10.0}
const FISH_GROWTH := 0.32
const FISH_SPAWN := 0.1
const FISH_FULL := 0.98
const RAIN := {"rain": 1.5, "drought": 0.3, "snow": 0.4}


static func ensure(world: Dictionary) -> void:
	if not world.has("depleted"):
		world["depleted"] = {}
	if not world.has("fished"):
		world["fished"] = {}


static func food_cap(t: Dictionary) -> float:
	return t["fertility"] * FOOD_CAP


static func fish_cap(t: Dictionary) -> float:
	return FISH_CAP.get(t["biome"], 0.0)


static func fish_of(t: Dictionary) -> float:
	return t.get("fish", fish_cap(t))


static func mark_food(world: Dictionary, x: int, y: int) -> void:
	world["depleted"][Vector2i(x, y)] = true


static func take_food(world: Dictionary, x: int, y: int, t: Dictionary, amount: float) -> float:
	var take: float = min(t["food"], amount)
	if take <= 0.0:
		return 0.0
	t["food"] -= take
	mark_food(world, x, y)
	return take


static func take_fish(world: Dictionary, x: int, y: int, t: Dictionary, amount: float) -> float:
	var have := fish_of(t)
	var take: float = min(have, amount)
	if take <= 0.0:
		return 0.0
	t["fish"] = have - take
	world["fished"][Vector2i(x, y)] = true
	return take


static func regrow(state: Dictionary) -> void:
	if state["day"] % REGROW_EVERY != 0:
		return
	var world: Dictionary = state["world"]
	ensure(world)
	var rain: float = RAIN.get(state["weather"], 1.0) * REGROW_EVERY
	var depleted: Dictionary = world["depleted"]
	for pos in depleted.keys():
		var t = WorldGen.tile_at(world, pos.x, pos.y)
		if t == null:
			depleted.erase(pos)
			continue
		var cap := food_cap(t)
		t["food"] = min(cap, t["food"] + t["fertility"] * FOOD_GROWTH * rain)
		if t["food"] >= cap:
			depleted.erase(pos)
	var fished: Dictionary = world["fished"]
	for pos in fished.keys():
		var t = WorldGen.tile_at(world, pos.x, pos.y)
		var cap: float = fish_cap(t) if t != null else 0.0
		if cap <= 0.0:
			fished.erase(pos)
			continue
		var f := fish_of(t)
		f = min(cap, f + FISH_GROWTH * f * (1.0 - f / cap) + FISH_SPAWN)
		t["fish"] = f
		if f >= cap * FISH_FULL:
			t["fish"] = cap
			fished.erase(pos)


static func fish_share(world: Dictionary, x: int, y: int, radius: int) -> float:
	var have := 0.0
	var cap := 0.0
	for o in Geography.offsets(radius):
		var t = WorldGen.tile_at(world, x + o.x, y + o.y)
		if t == null:
			continue
		var c := fish_cap(t)
		if c > 0.0:
			cap += c
			have += fish_of(t)
	return have / cap if cap > 0.0 else 0.0
