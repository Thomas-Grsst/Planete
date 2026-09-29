class_name Biomes
extends RefCounted

const DATA := {
	"ocean": {"name": "Océan", "color": Color("2a6fb3"), "walkable": false, "food": 0.2},
	"lake": {"name": "Lac", "color": Color("3a8fd0"), "walkable": false, "food": 0.3},
	"river": {"name": "Rivière", "color": Color("4aa3e0"), "walkable": true, "food": 0.9},
	"beach": {"name": "Plage", "color": Color("e5d59a"), "walkable": true, "food": 0.3},
	"plain": {"name": "Plaine", "color": Color("8bc34a"), "walkable": true, "food": 0.8},
	"forest": {"name": "Forêt", "color": Color("4f9a3f"), "walkable": true, "food": 0.6},
	"swamp": {"name": "Marais", "color": Color("6b8e5a"), "walkable": true, "food": 0.3},
	"desert": {"name": "Désert", "color": Color("d9b96b"), "walkable": true, "food": 0.05},
	"tundra": {"name": "Toundra", "color": Color("b9c9c9"), "walkable": true, "food": 0.15},
	"mountain": {"name": "Montagne", "color": Color("8d8d8d"), "walkable": true, "food": 0.05},
}

const ORES := {
	"cuivre": {"name": "Cuivre", "color": Color("3fbf8f"), "biomes": ["mountain"], "veins": [1, 4]},
	"etain": {"name": "Étain", "color": Color("d5d8e0"), "biomes": ["mountain", "tundra"], "veins": [0, 3]},
	"fer": {"name": "Fer", "color": Color("b5562c"), "biomes": ["mountain", "swamp"], "veins": [1, 3]},
	"charbon": {"name": "Charbon", "color": Color("222222"), "biomes": ["mountain", "forest"], "veins": [0, 3]},
	"obsidienne": {"name": "Obsidienne", "color": Color("5b4a8b"), "biomes": ["mountain", "desert"], "veins": [0, 2]},
	"argile": {"name": "Argile", "color": Color("c77a45"), "biomes": ["swamp", "beach"], "veins": [2, 6]},
}

const STILL_WATER := ["ocean", "lake"]


static func is_water(biome: String) -> bool:
	return biome == "ocean" or biome == "lake"


static func walkable(biome: String) -> bool:
	return DATA[biome]["walkable"]
