class_name WorldState
extends RefCounted

const PIONEERS := 20
const VERSION := 1


const COLONY_LEFT_BEHIND := ["machines", "electricite", "fusee", "espace"]


static func create(world_name: String, seed_text: String = "", colony: Dictionary = {}) -> Dictionary:
	var used_seed: String = seed_text if seed_text != "" else "%s-%d" % [world_name, Time.get_ticks_usec() + int(Time.get_unix_time_from_system())]
	var seed_value := Rng.hash_string(used_seed)
	var rng := Rng.new(seed_value)
	var state := {
		"version": VERSION, "id": "%x%x" % [int(Time.get_unix_time_from_system()), seed_value & 0xFFFF],
		"name": world_name, "seed": seed_value, "rng_state": 0, "day": 0, "next_id": 0, "acc_ms": 0.0,
		"world": WorldGen.generate(seed_value), "people": [], "settlements": [], "herds": [],
		"journal": [], "journal_seq": 0, "pending_summary": {}, "pending_highlights": [], "last_summary_day": 0,
		"weather": "sun", "weather_days": 5, "powers": {"rain": 0, "sun": 0}, "discoveries": {},
		"followed": [], "last_sim_time": Time.get_unix_time_from_system(), "extinct": false, "seed_text": used_seed,
	}
	var spot = _first_spot(state, rng)
	var s := Settlements.create(state, rng, spot.x, spot.y)
	if not colony.is_empty():
		_land_colony(state, rng, s, colony)
		return _finish(state, rng)
	for i in PIONEERS:
		var p := People.create(state, rng, rng.range_int(16, 35), s["id"])
		p["sex"] = "F" if i % 2 == 1 else "M"
	s["level"] = Settlements.initial_level(PIONEERS)
	s["max_level"] = s["level"]
	s["houses"] = 3
	Herds.seed_herds(state, rng)
	Journal.log_event(state, "fondation", "🏕️ %s est fondé par %d pionniers." % [s["name"], PIONEERS], {"x": s["x"], "y": s["y"], "settlement": s["id"]})
	return _finish(state, rng)


static func _finish(state: Dictionary, rng: Rng) -> Dictionary:
	state["pending_summary"] = {}
	state["pending_highlights"] = []
	state["rng_state"] = rng.state
	return state


static func _land_colony(state: Dictionary, rng: Rng, s: Dictionary, colony: Dictionary) -> void:
	var crew: Array = colony["crew"].slice(0, 30)
	for c in crew:
		var p := People.create(state, rng, clampi(c["age"], 16, 45), s["id"])
		p.merge({"name": c["name"], "sex": c["sex"], "traits": c["traits"]}, true)
	for k in colony["techs"]:
		if not COLONY_LEFT_BEHIND.has(k) and Techs.DATA.has(k):
			s["techs"].append(k)
			s["rooted"].append(k)
			state["discoveries"][k] = {"day": 0, "person": -1, "name": "les voyageurs des étoiles", "place": colony["origin"]}
	s["level"] = Settlements.initial_level(crew.size())
	s["max_level"] = s["level"]
	s["houses"] = max(3, crew.size() / 4)
	state["origin"] = colony["origin"]
	Herds.seed_herds(state, rng)
	Journal.log_event(state, "fondation", "🚀 Le vaisseau venu de %s se pose sur une terre inconnue. %s fondent %s." % [colony["origin"], Names.plural(crew.size(), "colon"), s["name"]], {"x": s["x"], "y": s["y"], "settlement": s["id"], "highlight": true})


static func _first_spot(state: Dictionary, rng: Rng) -> Vector2i:
	var center := WorldGen.SIZE / 2
	for radius in [10, 16, 22]:
		var spot = Geography.find_spot(state, rng, center, center, radius, true)
		if spot != null:
			return spot
	for i in WorldGen.SIZE * WorldGen.SIZE:
		var t: Dictionary = state["world"]["tiles"][i]
		if Biomes.walkable(t["biome"]) and t["biome"] != "river" and t["biome"] != "mountain":
			return Vector2i(i % WorldGen.SIZE, i / WorldGen.SIZE)
	return Vector2i(center, center)
