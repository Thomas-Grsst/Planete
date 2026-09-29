class_name Disasters
extends RefCounted

const STORM_HOUSE_CHANCE := 0.005
const FIRE_CHANCE := 0.03
const VOLCANO_CHANCE := 0.00004
const QUAKE_CHANCE := 0.00006
const FLOOD_CHANCE := 0.004
const METEOR_CHANCE := 0.00002
const LAVA_COOL_DAYS := 540
const MIN_DAY := 1800


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	var alive: Array = census.values().map(func(e): return e["s"])
	if alive.is_empty():
		return
	if state["weather"] == "storm" and rng.chance(STORM_HOUSE_CHANCE):
		_storm(state, rng, alive)
	if state["weather"] == "drought" and rng.chance(FIRE_CHANCE):
		_wildfire(state, rng.pick(alive))
	if state["weather"] == "rain" and rng.chance(FLOOD_CHANCE):
		_flood(state, rng, alive)
	_cool_lava(state)
	if state["day"] < MIN_DAY:
		return
	if rng.chance(VOLCANO_CHANCE):
		Cataclysms.volcano(state, rng, census)
	if rng.chance(QUAKE_CHANCE):
		Cataclysms.quake(state, rng, census)
	if rng.chance(METEOR_CHANCE):
		Cataclysms.meteor(state, rng, census)


static func _storm(state: Dictionary, rng: Rng, alive: Array) -> void:
	var targets: Array = alive.filter(func(s): return s["houses"] > 1 and not Techs.has_tech(s, "architecture"))
	if targets.is_empty():
		return
	var s: Dictionary = rng.pick(targets)
	s["houses"] -= 1
	s["storm_damage_day"] = state["day"]
	Journal.log_event(state, "catastrophe", "🌪️ La tempête détruit une maison à %s." % s["name"], {"x": s["x"], "y": s["y"], "settlement": s["id"], "houses_lost": 1})


static func _wildfire(state: Dictionary, s: Dictionary) -> void:
	var burnt := 0
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var t = WorldGen.tile_at(state["world"], s["x"] + dx, s["y"] + dy)
			if t != null and t["trees"] > 0:
				burnt += t["trees"]
				t["trees"] = 0
				t["food"] *= 0.3
	if burnt > 5:
		Journal.log_event(state, "catastrophe", "🔥 Un incendie ravage les forêts autour de %s." % s["name"], {"x": s["x"], "y": s["y"], "settlement": s["id"], "fire": true})


static func _flood(state: Dictionary, rng: Rng, alive: Array) -> void:
	var river_towns: Array = alive.filter(func(s): return s["geo"]["river"] and state["day"] - s.get("flood_day", -99999) > 1800)
	if river_towns.is_empty():
		return
	var s: Dictionary = rng.pick(river_towns)
	s["flood_day"] = state["day"]
	s["food"] *= 0.4
	var lost: int = 1 if s["houses"] > 2 and rng.chance(0.5) else 0
	s["houses"] -= lost
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var t = WorldGen.tile_at(state["world"], s["x"] + dx, s["y"] + dy)
			if t != null and Biomes.walkable(t["biome"]):
				t["food"] *= 0.5
	var ruin := " et emporte une maison" if lost > 0 else ""
	Journal.log_event(state, "catastrophe", "🌊 La rivière sort de son lit à %s : les réserves et les champs sont noyés%s." % [s["name"], ruin], {"x": s["x"], "y": s["y"], "settlement": s["id"], "flood": true, "houses_lost": lost, "highlight": true})


static func _cool_lava(state: Dictionary) -> void:
	if state["day"] % 30 != 0:
		return
	var changed := false
	for t in state["world"]["tiles"]:
		if t["biome"] == "lava" and state["day"] - t.get("since", 0) >= LAVA_COOL_DAYS:
			t["biome"] = "rock"
			t["fertility"] = 0.1
			changed = true
	if changed:
		Regions.invalidate()
		Journal.log_event(state, "paysage", "🪨 La lave refroidit et devient roche.", {"map": true})
