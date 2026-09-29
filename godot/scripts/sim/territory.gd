class_name Territory
extends RefCounted

const REFRESH_DAYS := 10
const BASE_RADIUS := 3

static var _map := PackedInt32Array()
static var _signature := ""
static var _day := -99999
static var _state: Dictionary = {}


static func _sig(state: Dictionary) -> String:
	var parts := PackedStringArray()
	for s in state["settlements"]:
		parts.append("x" if s["abandoned"] >= 0 else "%d:%d:%d" % [s["id"], s.get("civ", -1), s["level"]])
	return "|".join(parts)


static func map_of(state: Dictionary) -> PackedInt32Array:
	var sig := _sig(state)
	if is_same(_state, state) and sig == _signature and state["day"] - _day < REFRESH_DAYS:
		return _map
	_state = state
	_signature = sig
	_day = state["day"]
	_map = _compute(state)
	return _map


static func _compute(state: Dictionary) -> PackedInt32Array:
	var size := WorldGen.SIZE
	var map := PackedInt32Array()
	map.resize(size * size)
	map.fill(-1)
	var claims: Array = state["settlements"].filter(func(s): return s["abandoned"] < 0 and s.get("civ", -1) >= 0)
	if claims.is_empty():
		return map
	for y in size:
		for x in size:
			if not WorldGen.is_walkable(state["world"], x, y):
				continue
			var best := -1
			var best_d := 9999
			for s in claims:
				var d: int = absi(x - s["x"]) + absi(y - s["y"])
				if d <= BASE_RADIUS + s["level"] and d < best_d:
					best_d = d
					best = s["civ"]
			map[y * size + x] = best
	return map


static func share(state: Dictionary, civ: Dictionary) -> int:
	var map := map_of(state)
	var land := 0
	var owned := 0
	for i in map.size():
		if WorldGen.is_walkable(state["world"], i % WorldGen.SIZE, i / WorldGen.SIZE):
			land += 1
			if map[i] == civ["id"]:
				owned += 1
	return int(round(100.0 * owned / max(1, land)))
