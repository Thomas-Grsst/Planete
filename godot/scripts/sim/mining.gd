class_name Mining
extends RefCounted

# Mines : les mineurs creusent la montagne ou un filon proche du village et remontent des minerais.
# Chaque minerai a sa rareté, et on ne le remonte que si le village connaît le savoir qui permet de le reconnaître.

const METAL_ORES := ["cuivre", "etain", "fer", "charbon"]
const MINE_RADIUS := 6
const DIG_PER_MINER := 0.35
const SMITH_DIG := 0.15
const USE_PER_SMITH := 0.12
const METAL_CAP := 40.0
const VEIN_MIN := 200
const VEIN_MAX := 500
const GEO_REFRESH_RADIUS := 8
const COAL_BOOST := 1.5
# Rareté dans la mine, savoir nécessaire, stock maximum et part qui devient du métal pour les forgerons.
const YIELDS := {
	"pierre": {"weight": 50.0, "tech": "outils", "cap": 60.0, "metal": 0.0},
	"charbon": {"weight": 18.0, "tech": "metallurgie", "cap": 40.0, "metal": 0.0},
	"cuivre": {"weight": 14.0, "tech": "cuivre", "cap": 30.0, "metal": 1.0},
	"etain": {"weight": 9.0, "tech": "metallurgie", "cap": 30.0, "metal": 0.8},
	"fer": {"weight": 7.0, "tech": "fer", "cap": 30.0, "metal": 1.2},
	"or": {"weight": 2.0, "tech": "metallurgie", "cap": 20.0, "metal": 0.0},
	"diamant": {"weight": 0.6, "tech": "fer", "cap": 10.0, "metal": 0.0},
}
const ROCKY := ["mountain", "rock"]


static func vein_amount(rng: Rng) -> float:
	return float(rng.range_int(VEIN_MIN, VEIN_MAX))


static func ore_left(t: Dictionary) -> float:
	return t.get("ore_left", float(VEIN_MIN + VEIN_MAX) * 0.5)


static func has_metal(s: Dictionary) -> bool:
	return s.get("metal", 0.0) > 0.5


static func has_supply(s: Dictionary) -> bool:
	return has_metal(s) or s["geo"]["ores"].any(func(o): return METAL_ORES.has(o))


static func stock(s: Dictionary) -> Dictionary:
	return s.get_or_add("stock", {})


static func knows(s: Dictionary, ore: String) -> bool:
	return YIELDS.has(ore) and Techs.has_tech(s, YIELDS[ore]["tech"])


# Ce que la mine peut donner : les filons proches ; une mine creusée dans la roche donne aussi la pierre
# et, au fond, tous les métaux que le village sait reconnaître. L'or et le diamant demandent un vrai gisement.
static func available(s: Dictionary) -> Array:
	var out: Array = s["geo"]["ores"].filter(func(o): return YIELDS.has(o) and knows(s, o))
	var rocky: bool = s["geo"]["mountain"] > 0 or s["geo"]["ores"].has("pierre") or s.get("mine_rock", false)
	if not rocky:
		return out
	for ore in ["pierre", "charbon", "cuivre", "etain", "fer"]:
		if knows(s, ore) and not out.has(ore):
			out.append(ore)
	return out


static func site(state: Dictionary, s: Dictionary) -> Variant:
	var known = s.get("mine")
	if known is Vector2i:
		var t = WorldGen.tile_at(state["world"], known.x, known.y)
		if t != null and (ROCKY.has(t["biome"]) or YIELDS.has(t["ore"])):
			return known
	s.erase("mine")
	if not Techs.has_tech(s, "outils"):
		return null
	var best = null
	var best_score := -1
	for o in Geography.offsets(MINE_RADIUS):
		if max(absi(o.x), absi(o.y)) <= Settlements.clear_radius(s) or WorldGen.tile_at(state["world"], s["x"] + o.x, s["y"] + o.y) == null:
			continue
		var t = WorldGen.tile_at(state["world"], s["x"] + o.x, s["y"] + o.y)
		if t == null or not Biomes.walkable(t["biome"]) or t["biome"] == "river":
			continue
		var score := 0
		if METAL_ORES.has(t["ore"]) and knows(s, t["ore"]):
			score = 3
		elif YIELDS.has(t["ore"]) and knows(s, t["ore"]):
			score = 2
		elif ROCKY.has(t["biome"]):
			score = 1
		if score > best_score:
			best_score = score
			best = Vector2i(s["x"] + o.x, s["y"] + o.y)
	if best_score <= 0:
		return null
	s["mine"] = best
	var ground: Dictionary = WorldGen.tile_at(state["world"], best.x, best.y)
	s["mine_rock"] = ROCKY.has(ground["biome"])
	s["wood"] += ground["trees"]
	ground["trees"] = 0
	if not s.has("mine_day"):
		s["mine_day"] = state["day"]
		Journal.log_event(state, "mine", "⛏️ %s creuse une mine dans la roche : les premiers mineurs descendent sous terre." % s["name"], {"x": best.x, "y": best.y, "settlement": s["id"]})
	return best


static func step(state: Dictionary, rng: Rng, s: Dictionary, miners: int, smiths: int) -> void:
	var diggers: float = miners * DIG_PER_MINER + smiths * SMITH_DIG
	if diggers > 0.0:
		var pos = site(state, s)
		if pos != null:
			_dig(state, rng, s, pos, diggers)
	s["metal"] = max(0.0, s.get("metal", 0.0) - USE_PER_SMITH * smiths)


static func _pick(rng: Rng, options: Array) -> String:
	var total := 0.0
	for o in options:
		total += YIELDS[o]["weight"]
	var r := rng.next() * total
	for o in options:
		r -= YIELDS[o]["weight"]
		if r <= 0.0:
			return o
	return options[-1]


static func _dig(state: Dictionary, rng: Rng, s: Dictionary, pos: Vector2i, amount: float) -> void:
	var options := available(s)
	if options.is_empty():
		return
	var ore := _pick(rng, options)
	var info: Dictionary = YIELDS[ore]
	var store := stock(s)
	store[ore] = min(info["cap"], store.get(ore, 0.0) + amount)
	if info["metal"] > 0.0:
		var boost: float = COAL_BOOST if store.get("charbon", 0.0) >= 1.0 else 1.0
		s["metal"] = min(METAL_CAP, s.get("metal", 0.0) + amount * info["metal"] * boost)
		if boost > 1.0:
			store["charbon"] = max(0.0, store["charbon"] - amount * 0.3)
	_first_find(state, s, ore, pos)
	var t: Dictionary = WorldGen.tile_at(state["world"], pos.x, pos.y)
	if t["ore"] == ore:
		t["ore_left"] = ore_left(t) - amount
		if t["ore_left"] <= 0.0:
			_exhaust(state, s, pos, t)


static func _first_find(state: Dictionary, s: Dictionary, ore: String, pos: Vector2i) -> void:
	var found: Array = s.get_or_add("found_ores", [])
	if found.has(ore):
		return
	found.append(ore)
	if ore == "pierre":
		return
	var rare: bool = ore in ["or", "diamant"]
	var text := "⛏️ Les mineurs %s remontent %s pour la première fois." % [Names.of_place(s["name"]), Discovery._ore(ore)]
	if ore == "diamant":
		text = "💎 Au fond de la mine %s, un mineur trouve un diamant qui brille comme une étoile !" % Names.of_place(s["name"])
	elif ore == "or":
		text = "🪙 Les mineurs %s découvrent un filon d'or : tout le village accourt pour le voir." % Names.of_place(s["name"])
	Journal.log_event(state, "minerai", text, {"x": pos.x, "y": pos.y, "settlement": s["id"], "ore": ore, "highlight": rare})


static func _exhaust(state: Dictionary, s: Dictionary, pos: Vector2i, t: Dictionary) -> void:
	var ore: String = t["ore"]
	t["ore"] = ""
	t.erase("ore_left")
	if not ROCKY.has(t["biome"]):
		s.erase("mine")
	for o in state["settlements"]:
		if o["abandoned"] < 0 and absi(o["x"] - pos.x) + absi(o["y"] - pos.y) <= GEO_REFRESH_RADIUS:
			o["geo"] = Geography.of(state["world"], o["x"], o["y"])
	Journal.log_event(state, "filon", "⛏️ Le filon %s près %s est épuisé. Les mineurs devront creuser ailleurs." % [Discovery._ore(ore).replace("le ", "de ").replace("l'", "d'").replace("la ", "de "), Names.of_place(s["name"])], {"x": pos.x, "y": pos.y, "settlement": s["id"], "highlight": true})
