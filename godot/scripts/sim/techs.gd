class_name Techs
extends RefCounted

const DEFAULT_MODS := {
	"gather": 1.0, "wood": 1.0, "fish": 0.6, "farm": 0.0, "hunt": 1.0, "store": 1.0, "heal": 0.0, "capacity": 4, "spread": 1.0,
	"happiness": 0.0, "defense": 1.0, "research": 1.0, "outbreak": 1.0, "care": 1.0, "contagion": 1.0, "build": 1.0,
	"migration": 0, "cross_water": 0, "storm_proof": 0,
}
const METALS := ["cuivre", "metallurgie", "fer"]

const DATA := {
	"feu": {"the": "le feu", "de": "du feu", "name": "Feu", "emoji": "🔥", "needs": [], "any": [], "job": "", "mods": {"gather": ["mul", 1.1], "heal": ["add", 0.1], "outbreak": ["mul", 0.8], "happiness": ["add", 0.02]}},
	"outils": {"the": "les outils", "de": "des outils", "name": "Outils", "emoji": "🪨", "needs": [], "any": [], "job": "bâtisseur", "mods": {"gather": ["mul", 1.2], "wood": ["mul", 1.5], "hunt": ["mul", 1.3], "defense": ["mul", 1.2]}},
	"peche": {"the": "la pêche", "de": "de la pêche", "name": "Pêche", "emoji": "🎣", "needs": ["outils"], "any": [], "job": "pêcheur", "mods": {"fish": ["set", 1.2]}},
	"radeau": {"the": "le radeau", "de": "du radeau", "name": "Radeau", "emoji": "🛶", "needs": ["outils"], "any": [], "job": "pêcheur", "mods": {"fish": ["mul", 1.3], "spread": ["mul", 1.2]}},
	"plantes": {"the": "les plantes qui soignent", "de": "des plantes médicinales", "name": "Plantes médicinales", "emoji": "🌱", "needs": ["feu"], "any": [], "job": "guérisseur", "mods": {"heal": ["add", 0.3], "care": ["mul", 0.85]}},
	"agriculture": {"the": "l'agriculture", "de": "de l'agriculture", "name": "Agriculture", "emoji": "🌾", "needs": ["outils"], "any": [], "job": "fermier", "mods": {"farm": ["set", 1.0]}},
	"poterie": {"the": "la poterie", "de": "de la poterie", "name": "Poterie", "emoji": "🏺", "needs": ["feu"], "any": [], "job": "", "mods": {"store": ["mul", 1.6], "outbreak": ["mul", 0.8]}},
	"cuivre": {"the": "le cuivre", "de": "du cuivre", "name": "Cuivre", "emoji": "🟢", "needs": ["feu", "outils"], "any": [], "job": "forgeron", "mods": {"defense": ["mul", 1.2], "hunt": ["mul", 1.1], "wood": ["mul", 1.1]}},
	"metallurgie": {"the": "le bronze", "de": "du bronze", "name": "Bronze", "emoji": "⚒️", "needs": ["cuivre"], "any": [], "job": "forgeron", "mods": {"defense": ["mul", 1.3], "build": ["mul", 1.2], "hunt": ["mul", 1.2]}},
	"fer": {"the": "le fer", "de": "du fer", "name": "Fer", "emoji": "⛓️", "needs": ["feu", "outils"], "any": [], "job": "forgeron", "mods": {"defense": ["mul", 1.4], "wood": ["mul", 1.3], "build": ["mul", 1.2]}},
	"epee": {"the": "l'épée", "de": "de l'épée", "name": "Épée", "emoji": "🗡️", "needs": [], "any": METALS, "job": "gardien", "mods": {"defense": ["mul", 1.6], "hunt": ["mul", 1.2]}},
	"charrue": {"the": "la charrue", "de": "de la charrue", "name": "Charrue", "emoji": "🚜", "needs": ["agriculture"], "any": METALS, "job": "fermier", "mods": {"farm": ["mul", 1.6]}},
	"roue": {"the": "la roue", "de": "de la roue", "name": "Roue", "emoji": "☸️", "needs": ["outils"], "any": [], "job": "bâtisseur", "mods": {"wood": ["mul", 1.3], "farm": ["mul", 1.3], "migration": ["add", 4], "spread": ["mul", 1.5]}},
	"navigation": {"the": "la navigation", "de": "de la navigation", "name": "Navigation", "emoji": "⛵", "needs": ["radeau"], "any": [], "job": "pêcheur", "mods": {"cross_water": ["set", 1], "migration": ["add", 8], "fish": ["mul", 1.5], "spread": ["mul", 1.5]}},
	"ecriture": {"the": "l'écriture", "de": "de l'écriture", "name": "Écriture", "emoji": "📜", "needs": ["poterie"], "any": [], "job": "", "mods": {"research": ["mul", 1.5], "spread": ["mul", 2.0]}},
	"medecine": {"the": "la médecine", "de": "de la médecine", "name": "Médecine", "emoji": "⚕️", "needs": ["ecriture", "plantes"], "any": [], "job": "guérisseur", "mods": {"outbreak": ["mul", 0.5], "care": ["mul", 0.5], "contagion": ["mul", 0.6]}},
	"architecture": {"the": "l'architecture", "de": "de l'architecture", "name": "Architecture", "emoji": "🏛️", "needs": ["ecriture"], "any": ["metallurgie", "fer"], "job": "bâtisseur", "mods": {"capacity": ["set", 6], "build": ["mul", 1.3], "storm_proof": ["set", 1]}},
	"lois": {"the": "les lois", "de": "des lois", "name": "Lois", "emoji": "⚖️", "needs": ["ecriture"], "any": [], "job": "chef", "mods": {"happiness": ["add", 0.05], "contagion": ["mul", 0.9], "defense": ["mul", 1.2]}},
	"machines": {"the": "les machines", "de": "des machines", "name": "Machines", "emoji": "⚙️", "needs": ["fer", "architecture"], "any": [], "job": "forgeron", "mods": {"wood": ["mul", 2.0], "farm": ["mul", 1.5], "build": ["mul", 1.5]}},
	"electricite": {"the": "l'électricité", "de": "de l'électricité", "name": "Électricité", "emoji": "💡", "needs": ["machines"], "any": [], "job": "forgeron", "mods": {"happiness": ["add", 0.1], "outbreak": ["mul", 0.7], "research": ["mul", 1.2]}},
	"fusee": {"the": "la fusée", "de": "de la fusée", "name": "Fusée", "emoji": "🚀", "needs": ["electricite"], "any": [], "job": "forgeron", "mods": {"research": ["mul", 1.2], "happiness": ["add", 0.05]}},
	"espace": {"the": "le voyage spatial", "de": "du voyage spatial", "name": "Voyage spatial", "emoji": "🌌", "needs": ["fusee", "lois"], "any": [], "job": "", "mods": {}},
}

const ORDER := [
	"feu", "outils", "peche", "radeau", "plantes", "agriculture", "poterie", "cuivre", "metallurgie", "fer", "epee", "charrue",
	"roue", "navigation", "ecriture", "medecine", "architecture", "lois", "machines", "electricite", "fusee", "espace",
]


static func has_tech(s: Dictionary, key: String) -> bool:
	return s["techs"].has(key)


static func can_learn(s: Dictionary, key: String) -> bool:
	if has_tech(s, key):
		return false
	var t: Dictionary = DATA[key]
	for need in t["needs"]:
		if not has_tech(s, need):
			return false
	if t["any"].is_empty():
		return true
	for alt in t["any"]:
		if has_tech(s, alt):
			return true
	return false


static func mods_of(s: Dictionary) -> Dictionary:
	var m := DEFAULT_MODS.duplicate()
	for key in ORDER:
		if not s["techs"].has(key):
			continue
		for stat in DATA[key]["mods"]:
			var op: Array = DATA[key]["mods"][stat]
			match op[0]:
				"mul": m[stat] *= op[1]
				"add": m[stat] += op[1]
				"set": m[stat] = op[1] if stat == "capacity" else max(m[stat], op[1])
	return m
