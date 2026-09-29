class_name PeoplePanels
extends RefCounted

const TREE_DEPTH := 3


static func _plink(st: Dictionary, id: int) -> String:
	var p = People.by_id(st, id)
	if p == null:
		return InfoPanels.muted("inconnu")
	return InfoPanels.link("person:%d" % p["id"], p["name"]) + ("" if p["alive"] else (" 🚀" if p.get("departed", false) else " ✝"))


static func details(st: Dictionary, p: Dictionary) -> String:
	var out := ""
	if p.get("fame", 0) >= Fame.STATUE_FAME:
		out += "⭐ Célèbre : %s\n" % Fame.title(p)
	if p.get("dynasty", "") != "":
		out += "👑 Lignée : %s\n" % FaithData.capitalize(p["dynasty"])
	if p["alive"] and Diseases.is_sick(p):
		out += "🤒 %s\n" % Diseases.label_of(st, p)
	if p["alive"] and p.get("bitten", -1) >= 0:
		out += "🧟 %s depuis %d j\n" % ["Mordue" if p["sex"] == "F" else "Mordu", st["day"] - p["bitten"]]
	var knows: Array = p.get("knows", []).filter(func(k): return Techs.DATA.has(k))
	if not knows.is_empty():
		out += "🔑 Secrets : %s\n" % ", ".join(knows.map(func(k): return "%s %s" % [Techs.DATA[k]["emoji"], Techs.DATA[k]["name"]]))
	var immune: Array = p.get("immune", []).filter(func(k): return Diseases.DATA.has(k))
	if not immune.is_empty():
		out += InfoPanels.muted("🛡️ Immunisé%s : %s" % ["e" if p["sex"] == "F" else "", ", ".join(immune.map(func(k): return Diseases.DATA[k]["name"]))]) + "\n"
	var friends: Array = p.get("friends", []).slice(0, 5)
	if not friends.is_empty():
		out += "🤝 Amis : %s\n" % ", ".join(friends.map(func(id): return _plink(st, id)))
	var rivals: Array = p.get("rivals", []).slice(0, 5)
	if not rivals.is_empty():
		out += "😠 Rivaux : %s\n" % ", ".join(rivals.map(func(id): return _plink(st, id)))
	out += InfoPanels.link("family:%d" % p["id"], "🌳 Arbre généalogique") + "\n"
	return out


static func family(st: Dictionary, p: Dictionary) -> String:
	var out := "[b]🌳 Famille de %s[/b]\n\n[b]Ancêtres[/b]\n" % p["name"]
	var line: Array = [p]
	for depth in TREE_DEPTH:
		var parents: Array = []
		for q in line:
			for id in q.get("parents", []):
				var parent = People.by_id(st, id)
				if parent != null:
					parents.append(parent)
		if parents.is_empty():
			break
		var label: String = ["Parents", "Grands-parents", "Arrière-grands-parents"][depth]
		out += "%s : %s\n" % [label, ", ".join(parents.map(func(q): return _plink(st, q["id"])))]
		line = parents
	if p.get("partner", -1) >= 0:
		out += "\n💞 %s\n" % _plink(st, p["partner"])
	out += "\n[b]Descendants[/b]\n"
	out += _descendants(st, p, 0)
	return out


static func _descendants(st: Dictionary, p: Dictionary, depth: int) -> String:
	if depth >= TREE_DEPTH:
		return ""
	var out := ""
	for id in p["children"]:
		var c = People.by_id(st, id)
		if c == null:
			continue
		out += "%s└ %s\n" % ["    ".repeat(depth), _plink(st, c["id"])]
		out += _descendants(st, c, depth + 1)
	return out if out != "" or depth > 0 else InfoPanels.muted("Pas d'enfant.") + "\n"
