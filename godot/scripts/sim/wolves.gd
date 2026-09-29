class_name Wolves
extends RefCounted

const REACH := 2
const ATTACK_CHANCE := 0.02
const REPEL_THRESHOLD := 2.0
const REPEL_DISTANCE := 4
const WOUND := 40.0
const LETHALITY := 0.2


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for herd in state["herds"]:
		if herd["species"] != "wolf" or herd["count"] < 1:
			continue
		for id in census:
			var e: Dictionary = census[id]
			var s: Dictionary = e["s"]
			if e["pop"] > 0 and absi(herd["x"] - s["x"]) + absi(herd["y"] - s["y"]) <= REACH:
				if rng.chance(ATTACK_CHANCE):
					_attack(state, rng, herd, s, e)
				break


static func _attack(state: Dictionary, rng: Rng, herd: Dictionary, s: Dictionary, e: Dictionary) -> void:
	if Threats.defense(state, e) >= REPEL_THRESHOLD:
		_push_away(state, herd, s)
		var who := "Les gardiens" if e["jobs"].get("gardien", 0) > 0 else "Les habitants"
		Journal.log_event(state, "attaque", "🐺 %s %s repoussent une meute de loups." % [who, Names.of_place(s["name"])], {"x": s["x"], "y": s["y"], "settlement": s["id"]})
		return
	var victim = rng.pick(e["people"])
	_push_away(state, herd, s)
	if victim == null:
		return
	victim["health"] -= WOUND
	var female: bool = victim["sex"] == "F"
	if rng.chance(LETHALITY) or victim["health"] <= 0:
		People.kill(state, victim, "dévorée par les loups" if female else "dévoré par les loups")
		return
	Journal.log_event(state, "attaque", "🐺 Une meute de loups attaque %s : %s est %s." % [s["name"], victim["name"], "blessée" if female else "blessé"], {"x": s["x"], "y": s["y"], "person": victim["id"], "settlement": s["id"]})


static func _push_away(state: Dictionary, herd: Dictionary, s: Dictionary) -> void:
	var dx: int = sign(herd["x"] - s["x"]) if herd["x"] != s["x"] else 1
	var dy: int = sign(herd["y"] - s["y"])
	for k in range(REPEL_DISTANCE, 0, -1):
		if WorldGen.is_walkable(state["world"], herd["x"] + dx * k, herd["y"] + dy * k):
			herd["x"] += dx * k
			herd["y"] += dy * k
			return
