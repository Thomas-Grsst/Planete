class_name Migration
extends RefCounted

const RADIUS := 10
const MAX_GROUP := 8
const FOLLOW_CHANCE := 0.25
const MIN_COLONISTS := 3
const ISLAND_SHARE := 0.4
const LEAD_SHARE := 0.7


static func depart(state: Dictionary, rng: Rng, from: Dictionary, e: Dictionary) -> void:
	var harbour := Ports.has_port(from) and not Sieges.blockaded(from)
	var sailors: bool = e["mods"]["cross_water"] > 0 or harbour
	var reach: int = RADIUS + e["mods"]["migration"] + (Exploration.PORT_REACH if harbour else 0)
	var spot = _lead(state, rng, from, sailors)
	if spot == null and sailors and rng.chance(ISLAND_SHARE):
		spot = Geography.find_spot(state, rng, from["x"], from["y"], reach, true, true)
	if spot == null:
		spot = Geography.find_spot(state, rng, from["x"], from["y"], reach, sailors)
	if spot == null:
		return
	var adults: Array = e["people"].filter(func(p): return People.age_of(state, p) >= People.MIGRANT_MIN_AGE and not p["traits"].has("prudent"))
	if adults.size() < 4:
		return
	var leader: Dictionary = rng.pick(adults)
	var group: Array = []
	for p in adults:
		if group.size() < min(MAX_GROUP, adults.size() / 3) and (is_same(p, leader) or p["partner"] == leader["id"] or rng.chance(FOLLOW_CHANCE)):
			group.append(p)
	if group.size() < MIN_COLONISTS:
		return
	var target := Settlements.create(state, rng, spot.x, spot.y, from)
	var travellers := 0
	for p in group:
		p["home"] = target["id"]
		travellers += 1
		for cid in p["children"]:
			var c = People.by_id(state, cid)
			if c != null and c["alive"] and People.age_of(state, c) < People.MIGRANT_MIN_AGE:
				c["home"] = target["id"]
				travellers += 1
	target["level"] = Settlements.initial_level(travellers)
	target["max_level"] = target["level"]
	var company := "avec %s" % Names.plural(group.size() - 1, "compagnon")
	var by_boat: bool = not Regions.same_landmass(state["world"], from["x"], from["y"], spot.x, spot.y)
	var leaving := "⛵ %s quitte %s en bateau %s." if by_boat else "🧭 %s quitte %s %s."
	Journal.log_event(state, "migration", leaving % [leader["name"], from["name"], company], {"x": from["x"], "y": from["y"], "person": leader["id"], "from": from["id"], "to": target["id"], "boat": by_boat})
	Journal.log_event(state, "fondation", "🏕️ %s est fondé par %s." % [target["name"], leader["name"]], {"x": target["x"], "y": target["y"], "person": leader["id"], "settlement": target["id"]})


static func _lead(state: Dictionary, rng: Rng, from: Dictionary, sailors: bool) -> Variant:
	var leads: Array = from.get("leads", [])
	if leads.is_empty() or not rng.chance(LEAD_SHARE):
		return null
	var pick := leads.size() - 1
	if not from["geo"]["coast"]:
		for i in leads.size():
			if Geography.is_coastal(state["world"], leads[i]["x"], leads[i]["y"]):
				pick = i
	var lead: Dictionary = leads.pop_at(pick)
	var t = WorldGen.tile_at(state["world"], lead["x"], lead["y"])
	if t == null or not Biomes.walkable(t["biome"]) or Geography._too_close(state, lead["x"], lead["y"]):
		return null
	if not sailors and not Regions.same_landmass(state["world"], from["x"], from["y"], lead["x"], lead["y"]):
		return null
	return Vector2i(lead["x"], lead["y"])
