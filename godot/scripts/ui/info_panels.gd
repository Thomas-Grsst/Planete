class_name InfoPanels
extends RefCounted

const MUTED := "#8fa3b3"
const LINK := "#8fd3ff"
const GOLD := "#ffd54f"
const JOURNAL_SHOWN := 60
const WELCOME_TYPES := ["naissance", "deces", "couple", "construction", "decouverte", "fondation", "croissance", "migration", "diffusion", "religion", "conversion", "temple", "schisme", "civilisation", "guerre", "bataille", "conquete", "paix", "epidemie", "apocalypse", "raid", "cataclysme", "statue", "succes", "exploration", "port", "surpeche", "filon"]
const SUMMARY_LABELS := {
	"naissance": "👶 naissances", "deces": "🕯️ décès", "couple": "💞 couples formés", "construction": "🏠 maisons construites",
	"decouverte": "💡 découvertes", "fondation": "🏕️ colonies fondées", "croissance": "📈 colonies qui grandissent",
	"migration": "🧭 départs", "diffusion": "🧳 savoirs transmis",
	"religion": "🙏 religions fondées", "conversion": "🕯️ conversions", "temple": "🛕 temples élevés", "schisme": "⚡ schismes",
	"civilisation": "🏰 civilisations fondées", "guerre": "⚔️ guerres déclarées", "bataille": "🗡️ batailles", "conquete": "🏴 conquêtes", "paix": "🕊️ paix signées",
	"epidemie": "🦠 épidémies", "apocalypse": "🧟 apocalypses", "raid": "🔥 raids", "cataclysme": "🌋 cataclysmes", "statue": "🗿 statues", "succes": "🏆 succès",
	"exploration": "🗺️ expéditions", "port": "⚓ ports construits", "surpeche": "🐟 zones trop pêchées", "filon": "⛏️ filons épuisés",
}


static func render(kind: String, id: int) -> String:
	var st: Dictionary = Sim.state
	match kind:
		"person":
			var p = People.by_id(st, id)
			return person(st, p) if p != null else ""
		"settlement":
			var s = Settlements.by_id(st, id)
			return settlement(st, s) if s != null else ""
		"journal":
			return journal(st)
		"stats":
			return stats(st)
		"world":
			return StoryPanels.world(st)
		"chronicle":
			return StoryPanels.chronicle(st)
		"pantheon":
			return StoryPanels.pantheon(st)
		"achievements":
			return StoryPanels.achievements(st)
		"family":
			var fp = People.by_id(st, id)
			return PeoplePanels.family(st, fp) if fp != null else ""
		"civ":
			var c = Civs.by_id(st, id)
			return CivPanels.civ(st, c) if c != null else ""
		"welcome":
			return welcome(st, id)
		"powers":
			return FaithPanels.powers(st)
		"faith":
			var rel = Religions.by_id(st, id)
			return FaithPanels.religion(st, rel) if rel != null else ""
	return ""


static func muted(text: String) -> String:
	return "[color=%s]%s[/color]" % [MUTED, text]


static func link(meta: String, text: String) -> String:
	return "[url=%s][color=%s]%s[/color][/url]" % [meta, LINK, text]


static func person(st: Dictionary, p: Dictionary) -> String:
	var home = Settlements.by_id(st, p["home"])
	var age := People.age_of(st, p)
	var status := "%d ans" % age if p["alive"] else "✝ %s à %d ans" % ["morte" if p["sex"] == "F" else "mort", (p["death_day"] - p["birth_day"]) / 360]
	var out := "[b]%s[/b]  %s\n" % [p["name"], muted("%s · %s" % ["Femme" if p["sex"] == "F" else "Homme", status])]
	out += "%s %s" % [Jobs.emoji(p["job"]), Jobs.label(p["job"], p["sex"])]
	if home != null:
		out += " à " + link("settlement:%d" % home["id"], home["name"])
	out += "\n" + muted(", ".join(p["traits"].map(func(t): return Names.trait_label(t, p["sex"])))) + "\n"
	out += FaithPanels.prophet_line(st, p)
	out += PeoplePanels.details(st, p)
	if p["alive"]:
		out += "❤️ Santé %d %%   😊 Bonheur %d %%   🍽️ Faim %d %%\n" % [p["health"], p["happiness"], p["hunger"]]
	var partner = People.by_id(st, p["partner"]) if p["partner"] >= 0 else null
	out += "\n[b]Famille[/b]\n"
	out += ("💞 " + link("person:%d" % partner["id"], partner["name"])) if partner != null else muted("Célibataire")
	var kids: Array = p["children"].map(func(c): return People.by_id(st, c)).filter(func(c): return c != null)
	if not kids.is_empty():
		out += "\n👶 " + ", ".join(kids.map(func(c): return link("person:%d" % c["id"], c["name"]) + ("" if c["alive"] else " ✝")))
	out += "\n\n[b]Histoire[/b]\n"
	var history: Array = p["history"].slice(-8)
	history.reverse()
	for h in history:
		out += "%s %s\n" % [muted(Journal.format_day(h["day"])), h["text"]]
	return out


static func settlement(st: Dictionary, s: Dictionary) -> String:
	var census := Census.build(st)
	var e = census.get(s["id"])
	var pop: int = e["pop"] if e != null else 0
	var out := "[b]%s[/b]  %s\n" % [s["name"], muted(Settlements.level_name(s))]
	out += "👥 %d habitants · 🏠 %d maisons · 🪵 %d bois · 🍖 %d vivres\n" % [pop, s["houses"], s["wood"], s["food"]]
	out += resources(st, s)
	out += muted("Fondé %s" % Journal.format_day(s["founded_day"])) + "\n"
	if s["construction"] >= 0.0:
		out += "🔨 Maison en construction : %d %%\n" % int(s["construction"] * 100)
	var techs: Array = s["techs"].map(func(k): return "%s %s" % [Techs.DATA[k]["emoji"], Techs.DATA[k]["name"]])
	out += "💡 " + (" · ".join(techs) if not techs.is_empty() else muted("Aucun savoir pour l'instant")) + "\n"
	out += CivPanels.settlement_lines(st, s)
	out += FaithPanels.settlement_lines(st, s)
	if e != null:
		var jobs: Array = []
		for j in e["jobs"]:
			jobs.append("%s %d" % [Jobs.emoji(j), e["jobs"][j]])
		out += muted(" · ".join(jobs)) + "\n\n[b]Habitants[/b]\n"
		for p in e["people"].slice(0, 30):
			out += "%s %s\n" % [link("person:%d" % p["id"], p["name"]), muted("· %d ans · %s" % [People.age_of(st, p), Jobs.label(p["job"], p["sex"])])]
	return out


static func resources(st: Dictionary, s: Dictionary) -> String:
	var parts: Array = ["🌳 %d arbres" % Work.trees_near(st, s)]
	if s["geo"]["water"] > 0:
		parts.append("🐟 poissons %d %%" % int(round(Nature.fish_share(st["world"], s["x"], s["y"], Harvest.fish_radius(s)) * 100)))
	if Techs.has_tech(s, "agriculture"):
		parts.append("🌾 %d champs · sol %d %%" % [Harvest.fields(st, s, false)["count"], int(round(s.get("soil", 1.0) * 100))])
	var ores: Array = s["geo"]["ores"].filter(func(o): return Mining.METAL_ORES.has(o)).map(func(o): return Biomes.ORES[o]["name"].to_lower())
	if not ores.is_empty():
		parts.append("⛏️ " + ", ".join(ores))
	if s.get("metal", 0.0) >= 1.0:
		parts.append("⚒️ %d métal" % int(s["metal"]))
	return muted(" · ".join(parts)) + "\n"


static func journal(st: Dictionary) -> String:
	var out := "[b]📜 Journal du monde[/b]\n"
	var entries: Array = st["journal"].slice(-JOURNAL_SHOWN)
	entries.reverse()
	for e in entries:
		var text: String = e["text"]
		if e.has("x"):
			text = link("tile:%d:%d" % [e["x"], e["y"]], text)
		if Journal.is_rare(e):
			text = "⭐ " + text
		out += "%s  %s\n" % [muted(Journal.format_day(e["day"])), text]
	return out


static func stats(st: Dictionary) -> String:
	var out := "[b]👥 %d habitants[/b]\n\n[b]Colonies[/b]\n" % People.alive_count(st)
	var census := Census.build(st)
	for s in st["settlements"]:
		if s["abandoned"] < 0 and census.has(s["id"]):
			out += "%s %s\n" % [link("settlement:%d" % s["id"], s["name"]), muted("· %s · %d hab." % [Settlements.level_name(s), census[s["id"]]["pop"]])]
	out += "\n[b]💡 Savoirs · %d/%d[/b]\n" % [st["discoveries"].size(), Techs.ORDER.size()]
	for k in Techs.ORDER:
		if st["discoveries"].has(k):
			var d: Dictionary = st["discoveries"][k]
			out += "%s %s — %s à %s, %s\n" % [Techs.DATA[k]["emoji"], Techs.DATA[k]["name"], link("person:%d" % d["person"], d["name"]), d["place"], muted(Journal.format_day(d["day"]))]
	out += CivPanels.stats_section(st)
	out += FaithPanels.stats_section(st)
	out += "\n[b]Animaux[/b]\n"
	for key in Herds.SPECIES:
		var total := 0.0
		for h in st["herds"]:
			if h["species"] == key:
				total += h["count"]
		out += "%s %s : %d\n" % [Herds.SPECIES[key]["emoji"], Herds.SPECIES[key]["name"], total]
	return out


static func welcome(st: Dictionary, days: int) -> String:
	var out := "[b]🌍 Bon retour ![/b]\n%s\n\n" % muted("%d jours se sont écoulés à %s pendant ton absence." % [days, st["name"]])
	var counts: Dictionary = st["pending_summary"]
	for k in WELCOME_TYPES:
		if counts.get(k, 0) > 0:
			out += "%s : %d\n" % [SUMMARY_LABELS[k], counts[k]]
	out += "\n"
	for h in st["pending_highlights"].slice(-5):
		out += "[color=%s]%s[/color]\n" % [GOLD, h["text"]]
	st["pending_summary"] = {}
	st["pending_highlights"] = []
	return out
