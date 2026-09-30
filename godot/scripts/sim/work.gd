class_name Work
extends RefCounted

const GATHER_RADIUS := 4
const GATHER_PER_WORKER := 1.6
const HELPER_SHARE := 0.5
const HUNT_PER_HUNTER := 2.6
const HUNT_TAKE := 0.05
const FARM_WEATHER := {"drought": 0.3, "rain": 1.2, "snow": 0.4}
const ADULT_MEAL := 1.0
const CHILD_MEAL := 0.5
const STORE_BASE := 40.0
const STORE_PER_HOUSE := 15.0
const WOOD_CAP_BASE := 40.0
const WOOD_PER_HOUSE := 10.0
const HUNGER_STEP := 6.0
const HUNGER_RELIEF := 12.0
const TREE_REGROW_EVERY := 10
const TREE_REGROW_CHANCE := 0.012
const PLANTED_BOOST := 4.0
const PLANTED_TREES := 5


static func offsets() -> Array:
	return Geography.offsets(GATHER_RADIUS)


static func regrow(state: Dictionary) -> void:
	Nature.regrow(state)


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for id in census:
		var e: Dictionary = census[id]
		if e["pop"] <= 0:
			continue
		var s: Dictionary = e["s"]
		var m: Dictionary = e["mods"]
		var jobs: Dictionary = e["jobs"]
		var gatherers: float = jobs.get("cueilleur", 0) + e["helpers"] * HELPER_SHARE
		var gain := _gather(state, s, gatherers * GATHER_PER_WORKER * m["gather"])
		gain += _hunt(state, s, jobs.get("chasseur", 0), m["hunt"])
		if s["geo"]["water"] > 0:
			gain += Harvest.fish(state, s, jobs.get("pêcheur", 0), m["fish"])
		gain += Harvest.farm(state, s, jobs.get("fermier", 0), m["farm"], FARM_WEATHER.get(state["weather"], 1.0))
		_feed(s, e, gain, m)
		_cut_wood(state, rng, s, jobs.get("bâtisseur", 0) + 1, m["wood"])
		Mining.step(state, s, jobs.get("forgeron", 0))


static func _gather(state: Dictionary, s: Dictionary, wanted: float) -> float:
	var got := 0.0
	var world: Dictionary = state["world"]
	for o in offsets():
		if got >= wanted:
			break
		var x: int = s["x"] + o.x
		var y: int = s["y"] + o.y
		var t = WorldGen.tile_at(world, x, y)
		if t == null or t["food"] <= 0:
			continue
		got += Nature.take_food(world, x, y, t, wanted - got)
	return got


static func _hunt(state: Dictionary, s: Dictionary, hunters: int, mod: float) -> float:
	if hunters <= 0:
		return 0.0
	var herd = Herds.huntable_near(state, s)
	if herd == null:
		return 0.0
	herd["count"] = max(0.0, herd["count"] - HUNT_TAKE * hunters)
	return hunters * HUNT_PER_HUNTER * mod


static func _feed(s: Dictionary, e: Dictionary, gain: float, m: Dictionary) -> void:
	var need: float = e["adults"] * ADULT_MEAL + e["kids"] * CHILD_MEAL
	var cap: float = (STORE_BASE + s["houses"] * STORE_PER_HOUSE) * m["store"]
	s["food"] = min(cap, s["food"] + gain)
	s["last_gain"] = gain
	if s["food"] >= need:
		s["food"] -= need
		for p in e["people"]:
			p["hunger"] = max(0.0, p["hunger"] - HUNGER_RELIEF)
		return
	var shortage: float = 1.0 - s["food"] / max(0.01, need)
	s["food"] = 0.0
	for p in e["people"]:
		p["hunger"] = min(100.0, p["hunger"] + HUNGER_STEP * shortage * (0.6 if p["job"] == "enfant" else 1.0))


static func _cut_wood(state: Dictionary, rng: Rng, s: Dictionary, workers: int, mod: float) -> void:
	var cap: float = WOOD_CAP_BASE + s["houses"] * WOOD_PER_HOUSE
	for o in offsets():
		if s["wood"] >= cap or workers <= 0:
			break
		var t = WorldGen.tile_at(state["world"], s["x"] + o.x, s["y"] + o.y)
		if t == null or t["trees"] <= 0 or not rng.chance(0.35):
			continue
		t["trees"] -= 1
		s["wood"] += 1.0 * mod
		workers -= 1
	if (state["day"] + s["id"]) % TREE_REGROW_EVERY != 0:
		return
	var planted := Techs.has_tech(s, "sylviculture")
	var chance: float = TREE_REGROW_CHANCE * TREE_REGROW_EVERY * (PLANTED_BOOST if planted else 1.0)
	for o in offsets():
		var t = WorldGen.tile_at(state["world"], s["x"] + o.x, s["y"] + o.y)
		var in_village: bool = max(absi(o.x), absi(o.y)) <= Settlements.clear_radius(s)
		if t == null or in_village or t["fertility"] <= 0.3 or not Biomes.walkable(t["biome"]) or t["biome"] == "river":
			continue
		var most: int = 9 if t["biome"] == "forest" else (PLANTED_TREES if planted else 2)
		if t["trees"] < most and rng.chance(chance):
			t["trees"] += 1


static func trees_near(state: Dictionary, s: Dictionary) -> int:
	var n := 0
	for o in offsets():
		var t = WorldGen.tile_at(state["world"], s["x"] + o.x, s["y"] + o.y)
		if t != null and max(absi(o.x), absi(o.y)) > Settlements.clear_radius(s):
			n += t["trees"]
	return n
