class_name Exploration
extends RefCounted

const SETTLER_SIGHT := 10
const GEO_REACH := 12


static func reveal(state: Dictionary, rng: Rng, x: int, y: int, radius: int) -> Array:
	var fresh := WorldGen.reveal_area(state["world"], x, y, radius)
	if fresh.is_empty():
		return fresh
	for key in fresh:
		Herds.populate(state, rng, key)
	_refresh_geo(state, fresh)
	return fresh


static func _refresh_geo(state: Dictionary, fresh: Array) -> void:
	for s in state["settlements"]:
		if s["abandoned"] >= 0:
			continue
		for key in fresh:
			var o := WorldGen.origin(key)
			if s["x"] >= o.x - GEO_REACH and s["x"] < o.x + WorldGen.CHUNK + GEO_REACH and s["y"] >= o.y - GEO_REACH and s["y"] < o.y + WorldGen.CHUNK + GEO_REACH:
				s["geo"] = Geography.of(state["world"], s["x"], s["y"])
				break
