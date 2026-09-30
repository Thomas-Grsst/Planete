class_name Ports
extends RefCounted

const CHECK_DAYS := 30
const MIN_HOUSES := 3
const REACH := 3


static func has_port(s: Dictionary) -> bool:
	return not s.get("port", {}).is_empty()


static func tile(s: Dictionary) -> Vector2i:
	return Vector2i(s["port"]["x"], s["port"]["y"])


static func check(state: Dictionary, s: Dictionary) -> void:
	if has_port(s) or (state["day"] + s["id"]) % CHECK_DAYS != 0 or s["houses"] < MIN_HOUSES or not Techs.has_tech(s, "radeau"):
		return
	var spot = _spot(state["world"], s)
	if spot == null:
		return
	s["port"] = {"x": spot.x, "y": spot.y, "day": state["day"]}
	Journal.log_event(state, "port", "⚓ %s construit un port : les premières barques de pêche prennent la mer." % s["name"], {"x": spot.x, "y": spot.y, "settlement": s["id"]})


static func _spot(world: Dictionary, s: Dictionary) -> Variant:
	for o in Geography.offsets(REACH):
		if o == Vector2i.ZERO:
			continue
		var x: int = s["x"] + o.x
		var y: int = s["y"] + o.y
		var t = WorldGen.tile_at(world, x, y)
		if t == null or t["biome"] != "ocean":
			continue
		for n in WorldGen.neighbors(x, y):
			if WorldGen.is_walkable(world, n.x, n.y):
				return Vector2i(x, y)
	return null
