class_name Discovery
extends RefCounted

const LANDSCAPES := {
	"forest": "des forêts profondes", "plain": "de vastes plaines", "mountain": "de hautes montagnes", "desert": "un désert brûlant",
	"swamp": "des marais brumeux", "tundra": "une toundra glacée", "beach": "de longues plages", "river": "des rivières sinueuses", "rock": "des terres de roche",
}
const MIN_LAND := 6


static func describe(state: Dictionary, s: Dictionary, fresh: Array) -> Dictionary:
	var world: Dictionary = state["world"]
	var home := Regions.at(world, s["x"], s["y"])
	var biomes := {}
	var ores: Array = []
	var land := 0
	var island := false
	for key in fresh:
		var o := WorldGen.origin(key)
		var tiles: Array = world["chunks"][key]["tiles"]
		for i in tiles.size():
			var t: Dictionary = tiles[i]
			if not Biomes.walkable(t["biome"]):
				continue
			land += 1
			biomes[t["biome"]] = biomes.get(t["biome"], 0) + 1
			if t["ore"] != "" and not ores.has(t["ore"]):
				ores.append(t["ore"])
			if not island and home >= 0:
				var r := Regions.at(world, o.x + (i & WorldGen.LOCAL), o.y + (i >> WorldGen.SHIFT))
				island = r >= 0 and r != home
	var main := ""
	var best := 0
	for b in biomes:
		if biomes[b] > best and LANDSCAPES.has(b):
			best = biomes[b]
			main = b
	return {"land": land, "main": main, "ores": ores, "island": island and land >= MIN_LAND}


static func story(p: Dictionary, s: Dictionary, dir: String, sea: bool, found: Dictionary) -> String:
	var female: bool = p["sex"] == "F"
	if found["land"] < MIN_LAND:
		if sea:
			return "⛵ %s navigue des jours %s %s : rien que l'océan à perte de vue." % [p["name"], dir, Names.of_place(s["name"])]
		return "🧭 %s marche %s %s jusqu'au bout des terres connues : seulement de l'eau au loin." % [p["name"], dir, Names.of_place(s["name"])]
	var what: String = LANDSCAPES.get(found["main"], "des terres nouvelles")
	if found["island"]:
		what = "une île inconnue, avec %s" % what
	if not found["ores"].is_empty():
		what += " où affleure %s" % _ore(found["ores"][0])
	if sea:
		return "⛵ %s, %s %s en bateau, revient avec une nouvelle : %s, %s !" % [p["name"], "partie" if female else "parti", Names.of_place(s["name"]), what, dir]
	return "🧭 %s part explorer %s %s et découvre %s." % [p["name"], dir, Names.of_place(s["name"]), what]


static func _ore(key: String) -> String:
	var the := {"cuivre": "le cuivre", "etain": "l'étain", "fer": "le fer", "charbon": "le charbon", "obsidienne": "l'obsidienne", "argile": "l'argile", "pierre": "la pierre", "or": "l'or", "diamant": "le diamant"}
	return the.get(key, Biomes.ORES[key]["name"].to_lower())
