class_name Seafaring
extends RefCounted

# La vie des ports : chantiers navals, phares, naufrages dans les tempêtes et épaves qu'on finit par fouiller.

const CHECK_DAYS := 30
const SHIPYARD_HOUSES := 5
const LIGHTHOUSE_LEVEL := 3
const STORM_WRECK_CHANCE := 0.02
const CALM_WRECK_CHANCE := 0.0005
const LIGHTHOUSE_SHELTER := 0.3
const CREW := [1, 3]
const CARGO := [15.0, 40.0]
const SALVAGE_RANGE := 8
const SALVAGE_CHANCE := 0.06
const SALVAGE_AFTER_DAYS := 360
const WRECK_LIFE_DAYS := 36000
const MAX_WRECKS := 24


static func wrecks(state: Dictionary) -> Array:
	return state.get_or_add("wrecks", [])


static func has_lighthouse(s: Dictionary) -> bool:
	return Ports.has_port(s) and s["port"].has("lighthouse")


static func has_shipyard(s: Dictionary) -> bool:
	return Ports.has_port(s) and s["port"].has("shipyard")


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for id in census:
		var s: Dictionary = census[id]["s"]
		if Ports.has_port(s) and (state["day"] + s["id"]) % CHECK_DAYS == 0:
			_build(state, s)
	if state["day"] % CHECK_DAYS == 0:
		_salvage(state, rng, census)


static func _build(state: Dictionary, s: Dictionary) -> void:
	var port: Dictionary = s["port"]
	if not port.has("shipyard") and Techs.has_tech(s, "navigation") and s["houses"] >= SHIPYARD_HOUSES:
		port["shipyard"] = state["day"]
		Journal.log_event(state, "chantier", "🛠️ %s ouvre un chantier naval : de grands navires sortent de ses cales." % s["name"], {"x": port["x"], "y": port["y"], "settlement": s["id"]})
	if not port.has("lighthouse") and Techs.has_tech(s, "architecture") and Techs.has_tech(s, "navigation") and s["level"] >= LIGHTHOUSE_LEVEL:
		port["lighthouse"] = state["day"]
		Journal.log_event(state, "phare", "🗼 %s élève un phare : ses feux guideront les marins dans la nuit." % s["name"], {"x": port["x"], "y": port["y"], "settlement": s["id"]})


# Un navire qui fait la route peut sombrer, surtout dans la tempête et loin d'un phare.
static func voyage_risk(state: Dictionary, rng: Rng, census: Dictionary, from: Dictionary, to: Dictionary) -> bool:
	var odds: float = STORM_WRECK_CHANCE if state["weather"] == "storm" else CALM_WRECK_CHANCE
	if has_lighthouse(from) or has_lighthouse(to):
		odds *= LIGHTHOUSE_SHELTER
	if not rng.chance(odds):
		return false
	_wreck(state, rng, census, from, to)
	return true


static func _sea_tile(world: Dictionary, around: Vector2i) -> Variant:
	for o in Geography.offsets(6):
		var t = WorldGen.tile_at(world, around.x + o.x, around.y + o.y)
		if t != null and t["biome"] == "ocean":
			return Vector2i(around.x + o.x, around.y + o.y)
	return null


static func _wreck(state: Dictionary, rng: Rng, census: Dictionary, from: Dictionary, to: Dictionary) -> void:
	var a := Vector2(Ports.tile(from)) if Ports.has_port(from) else Vector2(from["x"], from["y"])
	var b := Vector2(Ports.tile(to)) if Ports.has_port(to) else Vector2(to["x"], to["y"])
	var mid := a.lerp(b, 0.3 + rng.next() * 0.4)
	var spot = _sea_tile(state["world"], Vector2i(int(round(mid.x)), int(round(mid.y))))
	if spot == null:
		return
	var adults: Array = census[from["id"]]["people"].filter(func(p): return p["alive"] and People.is_adult(state, p))
	var sailors: Array = adults.filter(func(p): return p["job"] == "pêcheur")
	var pool: Array = sailors if not sailors.is_empty() else adults
	var lost := 0
	for i in rng.range_int(CREW[0], CREW[1]):
		if pool.size() <= 1 or census[from["id"]]["pop"] - lost <= Trade.MIN_POP:
			break
		var p: Dictionary = pool.pop_at(rng.range_int(0, pool.size() - 1))
		People.kill(state, p, "noyé dans un naufrage")
		lost += 1
	state["next_id"] += 1
	var all := wrecks(state)
	all.append({"id": state["next_id"], "x": spot.x, "y": spot.y, "day": state["day"], "from": from["name"], "cargo": CARGO[0] + rng.next() * (CARGO[1] - CARGO[0])})
	if all.size() > MAX_WRECKS:
		all.pop_front()
	var storm: bool = state["weather"] == "storm"
	var toll := "avec %s" % Names.plural(lost, "marin") if lost > 0 else "sans perte humaine"
	Journal.log_event(state, "naufrage", "🌊 %s, un navire %s sombre au large %s %s." % ["Pris dans la tempête" if storm else "Sur un récif", Names.of_place(from["name"]), Names.of_place(to["name"]), toll], {"x": spot.x, "y": spot.y, "settlement": from["id"], "wreck": true, "highlight": lost >= 2})


static func _salvage(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	var all := wrecks(state)
	for w in all.duplicate():
		if state["day"] - w["day"] > WRECK_LIFE_DAYS:
			all.erase(w)
			continue
		if state["day"] - w["day"] < SALVAGE_AFTER_DAYS or not rng.chance(SALVAGE_CHANCE):
			continue
		for id in census:
			var s: Dictionary = census[id]["s"]
			if not Ports.has_port(s) or absi(s["port"]["x"] - w["x"]) + absi(s["port"]["y"] - w["y"]) > SALVAGE_RANGE:
				continue
			if census[id]["jobs"].get("pêcheur", 0) <= 0 and not Techs.has_tech(s, "navigation"):
				continue
			s["metal"] = min(Mining.METAL_CAP, s.get("metal", 0.0) + w["cargo"] * 0.4)
			s["food"] = s["food"] + w["cargo"] * 0.3
			all.erase(w)
			var years: int = (state["day"] - w["day"]) / 360
			Journal.log_event(state, "epave", "🐚 Des plongeurs %s fouillent l'épave du navire %s, coulé il y a %s, et remontent sa cargaison." % [Names.of_place(s["name"]), Names.of_place(w["from"]), Names.plural(max(1, years), "an")], {"x": w["x"], "y": w["y"], "settlement": s["id"]})
			break
