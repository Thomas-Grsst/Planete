class_name Techs
extends RefCounted

const DEFAULT_MODS := {"gather": 1.0, "wood": 1.0, "fish": 0.6, "farm": 0.0, "hunt": 1.0, "store": 1.0, "heal": 0.0, "capacity": 4, "spread": 1.0}

const DATA := {
	"feu": {"the": "le feu", "name": "Feu", "emoji": "🔥", "needs": [], "job": "", "mods": {"gather": ["mul", 1.1], "heal": ["add", 0.1]}},
	"outils": {"the": "les outils", "name": "Outils", "emoji": "🪨", "needs": [], "job": "bâtisseur", "mods": {"gather": ["mul", 1.2], "wood": ["mul", 1.5], "hunt": ["mul", 1.2]}},
	"peche": {"the": "la pêche", "name": "Pêche", "emoji": "🎣", "needs": ["outils"], "job": "pêcheur", "mods": {"fish": ["set", 1.2]}},
	"radeau": {"the": "le radeau", "name": "Radeau", "emoji": "🛶", "needs": ["outils"], "job": "pêcheur", "mods": {"fish": ["mul", 1.3], "spread": ["mul", 1.2]}},
	"plantes": {"the": "les plantes qui soignent", "name": "Plantes médicinales", "emoji": "🌱", "needs": [], "job": "cueilleur", "mods": {"heal": ["add", 0.3]}},
	"agriculture": {"the": "l'agriculture", "name": "Agriculture", "emoji": "🌾", "needs": [], "job": "cueilleur", "mods": {"farm": ["set", 1.0]}},
	"poterie": {"the": "la poterie", "name": "Poterie", "emoji": "🏺", "needs": ["feu"], "job": "", "mods": {"store": ["mul", 1.6]}},
	"cuivre": {"the": "le cuivre", "name": "Cuivre", "emoji": "🟢", "needs": ["feu"], "job": "", "mods": {"wood": ["mul", 1.2], "farm": ["mul", 1.2], "hunt": ["mul", 1.2]}},
	"roue": {"the": "la roue", "name": "Roue", "emoji": "☸️", "needs": ["poterie"], "job": "", "mods": {"spread": ["mul", 1.5], "capacity": ["add", 1]}},
}

const ORDER := ["feu", "outils", "peche", "radeau", "plantes", "agriculture", "poterie", "cuivre", "roue"]


static func has_tech(s: Dictionary, key: String) -> bool:
	return s["techs"].has(key)


static func can_learn(s: Dictionary, key: String) -> bool:
	if has_tech(s, key):
		return false
	for need in DATA[key]["needs"]:
		if not has_tech(s, need):
			return false
	return true


static func mods_of(s: Dictionary) -> Dictionary:
	var m := DEFAULT_MODS.duplicate()
	for key in s["techs"]:
		if not DATA.has(key):
			continue
		for stat in DATA[key]["mods"]:
			var op: Array = DATA[key]["mods"][stat]
			match op[0]:
				"mul": m[stat] *= op[1]
				"add": m[stat] += op[1]
				"set": m[stat] = max(m[stat], op[1])
	return m
