class_name Sieges
extends RefCounted

const SIEGE_DAYS := 90
const SIEGE_YIELD := 0.5
const BLOCKADE_DAYS := 120
const BLOCKADE_RANGE := 30
const BLOCKADE_CHANCE := 0.01
const BLOCKADE_FISH := 0.3
const WALL_WOOD := 30.0
const WALL_MIN_HOUSES := 4
const WALL_CHECK_DAYS := 20
const WALL_BONUS := 1.4
const STONE_WALL_BONUS := 1.7
const ADVANCE_DAYS := 180


static func besieged(s: Dictionary) -> bool:
	return not s.get("siege", {}).is_empty()


static func blockaded(s: Dictionary) -> bool:
	return not s.get("blockade", {}).is_empty()


static func yield_factor(s: Dictionary) -> float:
	return SIEGE_YIELD if besieged(s) else 1.0


static func fish_factor(s: Dictionary) -> float:
	return (BLOCKADE_FISH if blockaded(s) else 1.0) * yield_factor(s)


static func can_trade(s: Dictionary, kind: String) -> bool:
	return not besieged(s) and (kind != "sea" or not blockaded(s))


static func wall_bonus(s: Dictionary) -> float:
	if s.get("walls", -1) < 0:
		return 1.0
	return STONE_WALL_BONUS if s.get("stone_walls", false) else WALL_BONUS


static func advancing(state: Dictionary, s: Dictionary) -> bool:
	return state["day"] < s.get("advance_until", -1)


static func start(state: Dictionary, s: Dictionary, attacker: Dictionary, from: Dictionary) -> void:
	from["advance_until"] = state["day"] + ADVANCE_DAYS
	if besieged(s):
		s["siege"]["until"] = state["day"] + SIEGE_DAYS
		return
	s["siege"] = {"by": attacker["id"], "since": state["day"], "until": state["day"] + SIEGE_DAYS}
	Journal.log_event(state, "siege", "🏰 %s est assiégée par les troupes %s : les champs sont abandonnés et les réserves fondent." % [s["name"], Civs.of_title(attacker)], {"x": s["x"], "y": s["y"], "settlement": s["id"], "civ": attacker["id"]})


static func try_blockade(state: Dictionary, rng: Rng, attacker: Dictionary, defender: Dictionary) -> void:
	if not rng.chance(BLOCKADE_CHANCE):
		return
	for fleet in Civs.members(state, attacker):
		if not Ports.has_port(fleet) or not Techs.has_tech(fleet, "navigation"):
			continue
		for s in Civs.members(state, defender):
			if Ports.has_port(s) and not blockaded(s) and absi(s["x"] - fleet["x"]) + absi(s["y"] - fleet["y"]) <= BLOCKADE_RANGE:
				s["blockade"] = {"by": attacker["id"], "until": state["day"] + BLOCKADE_DAYS}
				Journal.log_event(state, "blocus", "⛵ La flotte %s bloque le port %s : plus une barque ne sort." % [Civs.of_title(attacker), Names.of_place(s["name"])], {"x": s["x"], "y": s["y"], "settlement": s["id"], "civ": attacker["id"]})
				return


static func step(state: Dictionary) -> void:
	for s in state["settlements"]:
		if s["abandoned"] >= 0:
			continue
		if besieged(s) and _over(state, s, s["siege"]):
			s.erase("siege")
			Journal.log_event(state, "siege_fin", "🏳️ Le siège %s est levé." % Names.of_place(s["name"]), {"x": s["x"], "y": s["y"], "settlement": s["id"]})
		if blockaded(s) and _over(state, s, s["blockade"]):
			s.erase("blockade")
		if s.get("walls", -1) < 0 and (state["day"] + s["id"]) % WALL_CHECK_DAYS == 0:
			_build_walls(state, s)


static func _over(state: Dictionary, s: Dictionary, hold: Dictionary) -> bool:
	if state["day"] >= hold["until"]:
		return true
	var enemy = Civs.by_id(state, hold["by"])
	var own = Civs.of(state, s)
	return enemy == null or own == null or own["id"] == enemy["id"] or Civs.war_between(state, own, enemy) == null


static func _build_walls(state: Dictionary, s: Dictionary) -> void:
	if s["houses"] < WALL_MIN_HOUSES or s["wood"] < WALL_WOOD or not Wars.at_war_any(state, s):
		return
	s["wood"] -= WALL_WOOD
	s["walls"] = state["day"]
	s["stone_walls"] = Techs.has_tech(s, "architecture")
	var kind := "de hautes murailles de pierre" if s["stone_walls"] else "d'une palissade de pieux"
	Journal.log_event(state, "murailles", "🧱 Craignant la guerre, %s s'entoure %s." % [s["name"], kind], {"x": s["x"], "y": s["y"], "settlement": s["id"]})
