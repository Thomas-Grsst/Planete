class_name Migration
extends RefCounted

const RADIUS := 10
const MAX_GROUP := 8
const FOLLOW_CHANCE := 0.25
const MIN_COLONISTS := 3


static func depart(state: Dictionary, rng: Rng, from: Dictionary, e: Dictionary) -> void:
	var sailors: bool = e["mods"]["cross_water"] > 0
	var spot = Geography.find_spot(state, rng, from["x"], from["y"], RADIUS + e["mods"]["migration"], sailors)
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
