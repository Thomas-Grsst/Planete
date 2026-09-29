class_name Cataclysms
extends RefCounted

const LAVA_RADIUS := 2
const DANGER_RADIUS := 4
const CRATER_RADIUS := 1


static func _victims(state: Dictionary, rng: Rng, e: Dictionary, max_dead: int, cause: String) -> int:
	var dead := 0
	for i in max_dead:
		var p = rng.pick(e["people"])
		if p != null and p["alive"]:
			People.kill(state, p, cause)
			dead += 1
	return dead


static func volcano(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	var peaks: Array = []
	var tiles: Array = state["world"]["tiles"]
	for i in tiles.size():
		if tiles[i]["biome"] == "mountain" and tiles[i]["height"] > 0.83:
			peaks.append(i)
	if peaks.is_empty():
		return
	var i: int = rng.pick(peaks)
	var cx := i % WorldGen.SIZE
	var cy := i / WorldGen.SIZE
	for dy in range(-LAVA_RADIUS, LAVA_RADIUS + 1):
		for dx in range(-LAVA_RADIUS, LAVA_RADIUS + 1):
			var t = WorldGen.tile_at(state["world"], cx + dx, cy + dy)
			if t != null and absi(dx) + absi(dy) <= LAVA_RADIUS and not Biomes.is_water(t["biome"]) and rng.chance(0.8):
				t["biome"] = "lava"
				t["since"] = state["day"]
				t["trees"] = 0
				t["food"] = 0.0
				t["fertility"] = 0.0
	Regions.invalidate()
	var dead := 0
	for id in census:
		var s: Dictionary = census[id]["s"]
		if absi(s["x"] - cx) + absi(s["y"] - cy) <= DANGER_RADIUS:
			dead += _victims(state, rng, census[id], rng.range_int(1, 4), "sous les cendres du volcan")
			s["houses"] = max(1, s["houses"] - rng.range_int(1, 3))
	var toll := " %s." % Names.plural(dead, "mort") if dead > 0 else " Personne ne vivait assez près pour en souffrir."
	Journal.log_event(state, "cataclysme", "🌋 Un volcan se réveille : la montagne crache du feu et la lave dévale les pentes.%s" % toll, {"x": cx, "y": cy, "map": true, "volcano": true, "highlight": true})


static func quake(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	var id = rng.pick(census.keys())
	var e: Dictionary = census[id]
	var s: Dictionary = e["s"]
	var solid := Techs.has_tech(s, "architecture")
	var lost: int = min(s["houses"] - 1, rng.range_int(0, 1) if solid else rng.range_int(1, 3))
	s["houses"] -= lost
	var dead := _victims(state, rng, e, 0 if solid else rng.range_int(0, 2), "écrasé sous les décombres")
	var detail := "les murs solides tiennent bon" if solid else "%s effondrées, %s" % [Names.plural(lost, "maison"), Names.plural(dead, "mort")]
	Journal.log_event(state, "cataclysme", "🌍 La terre tremble à %s : %s." % [s["name"], detail], {"x": s["x"], "y": s["y"], "settlement": s["id"], "quake": true, "houses_lost": lost, "highlight": true})


static func meteor(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	var cx := rng.range_int(3, WorldGen.SIZE - 4)
	var cy := rng.range_int(3, WorldGen.SIZE - 4)
	var center = WorldGen.tile_at(state["world"], cx, cy)
	if center == null or Biomes.is_water(center["biome"]):
		Journal.log_event(state, "cataclysme", "☄️ Une étoile filante géante plonge dans la mer. Une vague immense frappe les côtes.", {"x": cx, "y": cy, "meteor": true, "highlight": true})
		return
	for dy in range(-CRATER_RADIUS, CRATER_RADIUS + 1):
		for dx in range(-CRATER_RADIUS, CRATER_RADIUS + 1):
			var t = WorldGen.tile_at(state["world"], cx + dx, cy + dy)
			if t != null and not Biomes.is_water(t["biome"]):
				t["biome"] = "rock"
				t["trees"] = 0
				t["fertility"] = 0.05
				t["ore"] = "fer" if rng.chance(0.6) else t["ore"]
	Regions.invalidate()
	var dead := 0
	for id in census:
		var s: Dictionary = census[id]["s"]
		if absi(s["x"] - cx) + absi(s["y"] - cy) <= 3:
			dead += _victims(state, rng, census[id], rng.range_int(1, 5), "sous la pierre tombée du ciel")
			s["houses"] = max(1, s["houses"] - 2)
	var toll := " %s." % Names.plural(dead, "mort") if dead > 0 else " Le cratère fume au loin, rempli de fer."
	Journal.log_event(state, "cataclysme", "☄️ Une météorite s'écrase dans un fracas de tonnerre !%s" % toll, {"x": cx, "y": cy, "map": true, "meteor": true, "highlight": true})
