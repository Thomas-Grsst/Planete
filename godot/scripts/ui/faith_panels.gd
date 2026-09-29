class_name FaithPanels
extends RefCounted

const TEMPLES := ["", " · 🛕 temple", " · 🛕 grand temple"]
const RECENT_LEGENDS := 8


static func faith_link(rel: Dictionary) -> String:
	return "[color=#%s]%s[/color] %s" % [rel["color"].to_html(false), rel["emoji"], InfoPanels.link("faith:%d" % rel["id"], FaithData.capitalize(rel["name"]))]


static func _answers(need: String) -> String:
	var powers: Array = FaithData.PRAYERS[need]["answers"].map(func(k): return FaithData.POWER_LABELS[k])
	return " ou ".join(powers)


static func settlement_lines(st: Dictionary, s: Dictionary) -> String:
	var rel = Religions.of(st, s)
	var temple: String = TEMPLES[s.get("temple", 0)]
	var out := ""
	if rel != null:
		var holy := " · ✴️ ville sainte" if rel["holy"] == s["id"] else ""
		out = "%s · ferveur %d %%%s%s\n" % [faith_link(rel), s["devotion"], holy, temple]
	else:
		out = InfoPanels.muted("🙏 Aucune religion" + temple) + "\n"
	var need: String = s.get("prayer", {}).get("need", "")
	if need != "":
		var who := "On prie %s" % rel["deity"] if rel != null else "On implore le ciel"
		out += InfoPanels.muted("🙏 %s pour %s depuis %s" % [who, FaithData.PRAYERS[need]["wish"], Names.plural(st["day"] - s["prayer"]["since"], "jour")]) + "\n"
	return out


static func prophet_line(st: Dictionary, p: Dictionary) -> String:
	var rel = Religions.by_id(st, p.get("prophet_of", -1))
	return "" if rel == null else "✴️ %s : %s\n" % ["Prophétesse" if p["sex"] == "F" else "Prophète", faith_link(rel)]


static func religion(st: Dictionary, rel: Dictionary) -> String:
	var members := Religions.members(st, rel)
	var out := "[b]%s[/b]%s\n" % [faith_link(rel), "" if rel["alive"] else InfoPanels.muted(" · éteinte %s" % Journal.format_day(rel["fall_day"]))]
	out += InfoPanels.muted("Fondée par ") + InfoPanels.link("person:%d" % rel["founder"], rel["founder_name"]) + InfoPanels.muted(", %s" % Journal.format_day(rel["founded_day"])) + "\n"
	var parent = Religions.by_id(st, rel["parent"])
	if parent != null:
		out += InfoPanels.muted("Issue d'un schisme avec ") + faith_link(parent) + "\n"
	out += "✴️ Ville sainte : %s\n🙏 Divinité : %s\n" % [InfoPanels.link("settlement:%d" % rel["holy"], rel["holy_name"]), rel["deity"]]
	if Religions.is_player(rel):
		out += InfoPanels.muted("✨ C'est toi qu'ils prient : tes pouvoirs sont leurs miracles.") + "\n"
	var temples: int = members.filter(func(s): return s["temple"] > 0).size()
	out += "👥 %s · 🏘️ %s · 🛕 %s\n\n[b]Légendes[/b]\n" % [Names.plural(Religions.population(st, rel), "fidèle"), Names.plural(members.size(), "colonie"), Names.plural(temples, "temple")]
	var legends: Array = rel["legends"].map(func(id): return Religions.legend_by_id(st, id)).filter(func(l): return l != null)
	legends.reverse()
	for l in legends:
		out += legend_line(l)
	if legends.is_empty():
		out += InfoPanels.muted("Aucun miracle raconté pour l'instant.") + "\n"
	out += "\n[b]Colonies[/b]\n"
	for s in members:
		out += "%s%s %s\n" % [InfoPanels.link("settlement:%d" % s["id"], s["name"]), " ✴️" if s["id"] == rel["holy"] else "", InfoPanels.muted("· ferveur %d %%" % s["devotion"])]
	return out


static func legend_line(l: Dictionary) -> String:
	var answered := InfoPanels.muted(" · exaucé à %s" % ", ".join(l["answered"])) if not l["answered"].is_empty() else ""
	return "📖 %s%s\n" % [FaithData.capitalize(l["name"]), answered]


static func stats_section(st: Dictionary) -> String:
	var out := "\n[b]🙏 Religions[/b]\n"
	var all: Array = st.get("religions", [])
	if all.is_empty():
		return out + InfoPanels.muted("Aucune pour l'instant. Un orage, un deuil… ou un miracle pourrait en faire naître une.") + "\n"
	for rel in all:
		if rel["alive"]:
			out += "%s %s\n" % [faith_link(rel), InfoPanels.muted("· %d fidèles" % Religions.population(st, rel))]
	var legends: Array = st.get("legends", []).slice(-RECENT_LEGENDS)
	if not legends.is_empty():
		legends.reverse()
		out += "\n[b]📖 Légendes[/b]\n"
		for l in legends:
			out += legend_line(l)
	return out


static func powers(st: Dictionary) -> String:
	var out := "[b]✨ Pouvoirs[/b]\n%s\n\n" % InfoPanels.muted("Interviens ponctuellement. Les habitants y verront des miracles.")
	for p in Powers.LIST:
		out += "%s  %s\n" % [InfoPanels.link("action:power:%s" % p[0], "[b]%s[/b]" % p[1]), InfoPanels.muted(p[2])]
	out += "\n[b]🙏 Prières[/b]\n"
	var any := false
	for s in st["settlements"]:
		var need: String = s.get("prayer", {}).get("need", "")
		if s["abandoned"] < 0 and need != "" and _answers(need) != "":
			any = true
			out += "%s : %s %s\n" % [InfoPanels.link("settlement:%d" % s["id"], s["name"]), FaithData.PRAYERS[need]["wish"], InfoPanels.muted("→ " + _answers(need))]
	if not any:
		out += InfoPanels.muted("Personne n'implore le ciel pour l'instant.") + "\n"
	out += "\n" + InfoPanels.muted("Météo : %s" % Weather.LABELS.get(st["weather"], ""))
	return out
