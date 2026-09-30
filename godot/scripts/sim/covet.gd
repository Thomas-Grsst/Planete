class_name Covet
extends RefCounted

const REACH := 30
const OVERFISHED := 0.4
const BARE_TREES := 12
const RICH_FOREST := 15
const TENSION := 0.05


static func reason(state: Dictionary, a: Dictionary, b: Dictionary) -> Dictionary:
	var mine: Array = Civs.members(state, a)
	var theirs: Array = Civs.members(state, b)
	var needs := _needs(state, mine)
	if needs.is_empty():
		return {}
	for o in theirs:
		if not _near(mine, o):
			continue
		if needs.has("metal"):
			var ores: Array = o["geo"]["ores"].filter(func(k): return Mining.METAL_ORES.has(k))
			if not ores.is_empty():
				return {"kind": "metal", "ore": ores[0], "place": o}
		if needs.has("fish") and o["geo"]["coast"] and o.get("fish_rate", 1.0) > 0.7:
			return {"kind": "fish", "place": o}
		if needs.has("wood") and o["geo"]["forest"] >= RICH_FOREST:
			return {"kind": "wood", "place": o}
	return {}


static func _needs(state: Dictionary, members: Array) -> Array:
	var out: Array = []
	var smiths := members.any(func(s): return Techs.METALS.any(func(k): return Techs.has_tech(s, k)))
	if smiths and not members.any(func(s): return Mining.has_supply(s)):
		out.append("metal")
	if members.any(func(s): return s["geo"]["water"] > 0 and s.get("fish_rate", 1.0) < OVERFISHED):
		out.append("fish")
	if members.any(func(s): return s["houses"] >= Sieges.WALL_MIN_HOUSES and Work.cached_trees(state, s) < BARE_TREES):
		out.append("wood")
	return out


static func _near(members: Array, o: Dictionary) -> bool:
	return members.any(func(s): return absi(s["x"] - o["x"]) + absi(s["y"] - o["y"]) <= REACH)


static func why(found: Dictionary) -> String:
	var place: String = Names.of_place(found["place"]["name"])
	match found["kind"]:
		"metal":
			return "pour s'emparer des mines %s %s" % [Discovery._ore(found["ore"]).replace("le ", "de ").replace("l'", "d'"), place]
		"fish":
			return "pour les eaux poissonneuses %s" % place
		"wood":
			return "pour les forêts %s" % place
	return ""
