class_name Territory
extends RefCounted

const REFRESH_DAYS := 10
const BASE_RADIUS := 3

static var _map := {}
static var _signature := ""
static var _day := -99999
static var _state: Dictionary = {}
static var _land := 0
static var _land_sig := ""


static func _sig(state: Dictionary) -> String:
	var parts := PackedStringArray()
	for s in state["settlements"]:
		parts.append("x" if s["abandoned"] >= 0 else "%d:%d:%d" % [s["id"], s.get("civ", -1), radius(state, s)])
	return "|".join(parts)


static func radius(state: Dictionary, s: Dictionary) -> int:
	return max(1, BASE_RADIUS + s["level"] - (1 if Sieges.besieged(s) else 0) + (1 if Sieges.advancing(state, s) else 0))


static func map_of(state: Dictionary) -> Dictionary:
	var sig := _sig(state)
	if is_same(_state, state) and sig == _signature and state["day"] - _day < REFRESH_DAYS:
		return _map
	_state = state
	_signature = sig
	_day = state["day"]
	_map = _compute(state)
	return _map


static func _compute(state: Dictionary) -> Dictionary:
	var owner := {}
	var dist := {}
	for s in state["settlements"]:
		if s["abandoned"] >= 0 or s.get("civ", -1) < 0:
			continue
		var r := radius(state, s)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var d: int = absi(dx) + absi(dy)
				var pos := Vector2i(s["x"] + dx, s["y"] + dy)
				if d > r or d >= dist.get(pos, 9999) or not WorldGen.is_walkable(state["world"], pos.x, pos.y):
					continue
				dist[pos] = d
				owner[pos] = s["civ"]
	return owner


static func civ_at(state: Dictionary, x: int, y: int) -> int:
	return map_of(state).get(Vector2i(x, y), -1)


static func share(state: Dictionary, civ: Dictionary) -> int:
	var owned := 0
	var map := map_of(state)
	for pos in map:
		if map[pos] == civ["id"]:
			owned += 1
	return int(round(100.0 * owned / max(1, known_land(state["world"]))))


static func known_land(world: Dictionary) -> int:
	var sig := "%d:%d" % [world["chunks"].size(), world.get("rev", 0)]
	if sig == _land_sig:
		return _land
	_land_sig = sig
	_land = 0
	for key in world["chunks"]:
		for t in world["chunks"][key]["tiles"]:
			if Biomes.walkable(t["biome"]):
				_land += 1
	return _land
