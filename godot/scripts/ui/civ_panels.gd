class_name CivPanels
extends RefCounted


static func civ_link(civ: Dictionary) -> String:
	return "[color=#%s]●[/color] %s" % [civ["color"].to_html(false), InfoPanels.link("civ:%d" % civ["id"], Civs.title(civ, true))]


static func civ(st: Dictionary, c: Dictionary) -> String:
	var status := "" if c["alive"] else InfoPanels.muted(" · disparue %s" % Journal.format_day(c["fall_day"]))
	var out := "[b]%s[/b]%s\n" % [civ_link(c), status]
	var founder := InfoPanels.link("person:%d" % c["founder"], c["founder_name"]) if c["founder"] >= 0 else "ses premiers habitants"
	var capital = Settlements.by_id(st, c["capital"])
	out += InfoPanels.muted("Fondée par ") + founder + InfoPanels.muted(", %s" % Journal.format_day(c["founded_day"])) + "\n"
	if capital != null:
		out += "🏰 Capitale : %s\n" % InfoPanels.link("settlement:%d" % capital["id"], capital["name"])
	out += "👥 %s · 🏘️ %s\n" % [Names.plural(Civs.population(st, c), "habitant"), Names.plural(Civs.members(st, c).size(), "ville")]
	out += "🗺️ Territoire %d %% · 💡 Technologie %d %% · 🎭 Culture %d %%\n" % [Territory.share(st, c), Civs.tech_share(st, c), c["culture"]]
	var rel = Religions.by_id(st, c.get("religion", -1))
	if rel != null and rel["alive"]:
		out += "🙏 Religion officielle : %s\n" % FaithPanels.faith_link(rel)
	if c["conquests"] > 0:
		out += "🏴 %s\n" % Names.plural(c["conquests"], "conquête")
	var wars: Array = st.get("wars", []).filter(func(w): return w["a"] == c["id"] or w["b"] == c["id"])
	if not wars.is_empty():
		out += "\n[b]Guerres[/b]\n" + "\n".join(wars.map(func(w): return Wars.line(st, w))) + "\n"
	out += "\n[b]Relations[/b]\n"
	for o in Civs.alive(st):
		if o["id"] != c["id"]:
			out += "%s : %s\n" % [civ_link(o), Diplomacy.label(st, c, o)]
	out += "\n[b]Villes[/b]\n"
	for s in Civs.members(st, c):
		out += "%s%s%s\n" % [InfoPanels.link("settlement:%d" % s["id"], s["name"]), " 🏰" if s["id"] == c["capital"] else "", " 🏴" if s.get("conquered_day", -1) >= 0 else ""]
	return out


static func settlement_lines(st: Dictionary, s: Dictionary) -> String:
	var out := ""
	var c = Civs.of(st, s)
	out += (civ_link(c) + (" · 🏰 capitale" if c["capital"] == s["id"] else "") + "\n") if c != null else InfoPanels.muted("🏳️ Indépendant") + "\n"
	var chef = Governance.chef_of(st, s)
	if chef != null:
		out += "👑 %s : %s %s\n" % ["Cheffe" if chef["sex"] == "F" else "Chef", InfoPanels.link("person:%d" % chef["id"], chef["name"]), InfoPanels.muted("depuis %s" % Journal.format_day(s["chef_since"]))]
	if not s.get("council", []).is_empty():
		out += "🏛️ Conseil : %s\n" % ", ".join(s["council"].map(func(id): return InfoPanels.link("person:%d" % id, People.by_id(st, id)["name"]) if People.by_id(st, id) != null else ""))
	if not s.get("dynasty", {}).is_empty():
		out += InfoPanels.muted("👑 Dynastie : %s (%s)" % [FaithData.capitalize(s["dynasty"]["name"]), Names.plural(s["dynasty"]["rulers"], "règne")]) + "\n"
	var o: Dictionary = s.get("outbreak", {})
	if not o.is_empty():
		var d: Dictionary = Diseases.DATA[o["key"]]
		out += "🦠 %s sévit depuis %d j · %s\n" % [d["name"], st["day"] - o["since"], Names.plural(o["deaths"], "mort")]
	var fragile: Array = s["techs"].filter(func(k): return Lore.is_fragile(s, k))
	if not fragile.is_empty():
		out += InfoPanels.muted("🕯️ Savoirs fragiles : %s" % ", ".join(fragile.map(func(k): return Techs.DATA[k]["name"]))) + "\n"
	for statue in s.get("statues", []):
		out += "🗿 Statue de %s, %s\n" % [InfoPanels.link("person:%d" % statue["person"], statue["name"]), statue["title"]]
	return out


static func stats_section(st: Dictionary) -> String:
	var out := "\n[b]🏰 Civilisations[/b]\n"
	var civs := Civs.alive(st)
	if civs.is_empty():
		out += InfoPanels.muted("Aucune pour l'instant : il faut un village de 30 habitants avec un chef.") + "\n"
	for c in civs:
		out += "%s %s\n" % [civ_link(c), InfoPanels.muted("· %d hab. · %d %%" % [Civs.population(st, c), Territory.share(st, c)])]
	for w in st.get("wars", []):
		out += Wars.line(st, w) + "\n"
	var z: Dictionary = st.get("zombies", {})
	if z.get("active", false):
		out += "[color=#b9f6ca]🧟 Apocalypse : %s · %s[/color]\n" % [Names.plural(z["hordes"].size(), "horde"), Names.plural(z["dead"], "mort")]
	for band in st.get("raiders", []):
		out += "%s %s ×%d\n" % [Raiders.KINDS[band["kind"]]["emoji"], FaithData.capitalize(Raiders.KINDS[band["kind"]]["name"]), band["count"]]
	return out
