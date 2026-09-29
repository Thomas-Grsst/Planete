class_name Dynasties
extends RefCounted

const HEIR_CHANCE := 0.6
const HEIR_MIN_AGE := 18
const LINEAGE_ANNOUNCE_FROM := 3


static func family_name(founder: String) -> String:
	var root := founder
	for ending in ["a", "e", "o", "i", "u", "y"]:
		if root.length() > 3 and root.ends_with(ending):
			root = root.substr(0, root.length() - 1)
	return "les %sides" % root


static func found(state: Dictionary, s: Dictionary, chef: Dictionary) -> void:
	s["dynasty"] = {"name": family_name(chef["name"]), "founder": chef["id"], "since": state["day"], "rulers": 1}
	chef["dynasty"] = s["dynasty"]["name"]


static func heir(state: Dictionary, rng: Rng, s: Dictionary, e: Dictionary) -> Variant:
	var dynasty: Dictionary = s.get("dynasty", {})
	if dynasty.is_empty() or not Techs.has_tech(s, "lois") or not rng.chance(HEIR_CHANCE):
		return null
	var heirs: Array = e["people"].filter(func(p): return p.get("dynasty", "") == dynasty["name"] and p["job"] != "chef" and People.age_of(state, p) >= HEIR_MIN_AGE)
	if heirs.is_empty():
		return null
	heirs.sort_custom(func(a, b): return a["birth_day"] < b["birth_day"])
	return heirs[0]


static func announce(state: Dictionary, s: Dictionary, p: Dictionary) -> void:
	var dynasty: Dictionary = s["dynasty"]
	dynasty["rulers"] += 1
	var title := "cheffe" if p["sex"] == "F" else "chef"
	var text := "👑 %s, de la lignée %s, devient %s %s." % [p["name"], FaithData.of_name(dynasty["name"]), title, Names.of_place(s["name"])]
	if dynasty["rulers"] >= LINEAGE_ANNOUNCE_FROM:
		text = "👑 %s devient %s %s : %s règnent depuis %s." % [p["name"], title, Names.of_place(s["name"]), FaithData.capitalize(dynasty["name"]), Names.plural(dynasty["rulers"], "génération")]
	Journal.log_event(state, "dynastie", text, {"x": s["x"], "y": s["y"], "person": p["id"], "settlement": s["id"], "highlight": dynasty["rulers"] >= LINEAGE_ANNOUNCE_FROM})


static func inherit(child: Dictionary, mother: Dictionary, father) -> void:
	var name: String = mother.get("dynasty", "")
	if name == "" and father != null:
		name = father.get("dynasty", "")
	if name != "":
		child["dynasty"] = name
