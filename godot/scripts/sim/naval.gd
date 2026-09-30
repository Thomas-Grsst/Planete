class_name Naval
extends RefCounted

const SEA_PENALTY := 10
const RAFT_LANDING := 20
const SHIP_LANDING := 45
const SEA_BATTLE_CHANCE := 0.5
const SHIP_BONUS := 1.5


static func can_land(s: Dictionary, d: int) -> bool:
	if not Ports.has_port(s) or Sieges.blockaded(s):
		return false
	if Techs.has_tech(s, "navigation"):
		return d <= SHIP_LANDING
	return Techs.has_tech(s, "radeau") and d <= RAFT_LANDING


static func _fleet(s: Dictionary, e: Dictionary, rng: Rng) -> float:
	var crews: float = 1.0 + e["jobs"].get("pêcheur", 0) * 0.5 + e["jobs"].get("gardien", 0) * 0.5
	return crews * (SHIP_BONUS if Techs.has_tech(s, "navigation") else 1.0) * (0.7 + rng.next() * 0.6)


static func cross(state: Dictionary, rng: Rng, war: Dictionary, f: Dictionary, attacker: Dictionary, defender: Dictionary, ea: Dictionary, ed: Dictionary) -> bool:
	var target: Dictionary = f["to"]
	var guarded: bool = Ports.has_port(target) and (Techs.has_tech(target, "radeau") or Techs.has_tech(target, "navigation"))
	if not guarded or not rng.chance(SEA_BATTLE_CHANCE):
		return true
	var wins := _fleet(f["from"], ea, rng) > _fleet(target, ed, rng)
	var dead := Wars._casualties(state, rng, ed if wins else ea, rng.range_int(1, 3))
	war["deaths"] += dead
	war["battles"] += 1
	var story := "la flotte %s coule les barques %s" % [Civs.of_title(attacker), Names.of_place(target["name"])] if wins else "les marins %s repoussent la flotte %s" % [Names.of_place(target["name"]), Civs.of_title(attacker)]
	var port := Ports.tile(target)
	Journal.log_event(state, "bataille_navale", "⚓ Bataille navale au large %s : %s. %s." % [Names.of_place(target["name"]), story, Names.plural(dead, "mort")], {"x": port.x, "y": port.y, "from": f["from"]["id"], "settlement": target["id"], "civ": (attacker if wins else defender)["id"]})
	return wins
