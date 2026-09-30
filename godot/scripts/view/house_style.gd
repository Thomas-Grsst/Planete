class_name HouseStyle
extends RefCounted

# L'allure des maisons : l'époque (savoirs du village) et la culture (civilisation) décident des murs, du toit et des étages.

const THATCH := Color("b8913f")
const TILES := Color("b5452f")
const HIDE := Color("c4a27a")
const HIDE_SHADE := Color("9c7c56")
const SLATE := Color("5d6470")
# Enduits d'une culture à l'autre : [mur éclairé, mur à l'ombre].
const PLASTERS := [["d8c3a0", "b59a74"], ["e9e4d8", "c9c2b2"], ["dcb67a", "b8904f"], ["c9a57a", "8f6b45"], ["e3b7a5", "bf8f7c"]]
const STONES := [["a9a39a", "87817a"], ["cfc6b4", "aaa08d"], ["8d8a86", "6d6a66"], ["bfae94", "998a72"]]
const BRICKS := [["b5563a", "8e3f2a"], ["a8664a", "834b35"], ["9a4b3c", "73382c"]]
const TOWN_LEVEL := 3
const CITY_LEVEL := 4


static func era(s: Dictionary) -> String:
	if Techs.has_tech(s, "machines"):
		return "brick"
	if Techs.has_tech(s, "architecture"):
		return "stone"
	if Techs.has_tech(s, "poterie"):
		return "tiled"
	if s["level"] == 0 and not Techs.has_tech(s, "agriculture"):
		return "tent"
	return "hut"


static func _culture(s: Dictionary) -> int:
	var civ: int = s.get("civ", -1)
	return civ if civ >= 0 else s["id"]


static func of(s: Dictionary, index: int) -> Dictionary:
	var e := era(s)
	var k := _culture(s)
	var civ = Civs.of(Sim.state, s)
	var pair: Array = PLASTERS[k % PLASTERS.size()]
	if e == "stone":
		pair = STONES[k % STONES.size()]
	elif e == "brick":
		pair = BRICKS[k % BRICKS.size()]
	elif e == "tent":
		pair = [HIDE.to_html(), HIDE_SHADE.to_html()]
	var roof := THATCH
	if e in ["tiled", "stone"]:
		roof = TILES if k % 3 != 2 else SLATE
	elif e == "brick":
		roof = Color(pair[1]).darkened(0.35)
	if civ != null and e != "tent":
		roof = roof.lerp(civ["color"], 0.25)
	return {"era": e, "wall": Color(pair[0]), "shade": Color(pair[1]), "roof": roof, "floors": _floors(s, e, index)}


static func _floors(s: Dictionary, e: String, index: int) -> int:
	var central: bool = index < max(3, s["houses"] / 2)
	if e == "brick":
		return 3 if s["level"] >= CITY_LEVEL and central else 2
	if e == "stone":
		return 2 if s["level"] >= TOWN_LEVEL and central else 1
	return 1
