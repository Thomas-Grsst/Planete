class_name StoryPanels
extends RefCounted

const ERA_LINES := 12


static func chronicle(st: Dictionary) -> String:
	var out := "[b]📖 Le Livre %s[/b]\n" % Names.of_place(st["name"])
	out += InfoPanels.link("action:replay", "▶ Rejouer l'histoire en accéléré") + "\n"
	var eras := Chronicle.eras(st)
	if eras.is_empty():
		return out + InfoPanels.muted("Rien de mémorable n'est encore arrivé.")
	eras.reverse()
	for era in eras:
		var from: int = era["era"] * Chronicle.ERA_YEARS + 1
		out += "\n[b]%s[/b] %s\n" % [era["title"], InfoPanels.muted("· ans %d à %d" % [from, from + Chronicle.ERA_YEARS - 1])]
		var entries: Array = era["entries"].slice(-ERA_LINES)
		for e in entries:
			out += "%s %s\n" % [InfoPanels.muted("An %d" % (e["day"] / 360 + 1)), e["text"]]
	return out


static func pantheon(st: Dictionary) -> String:
	var out := "[b]🗿 Panthéon[/b]\n"
	var famous: Array = st.get("pantheon", [])
	if famous.is_empty():
		return out + InfoPanels.muted("Aucun habitant n'est encore entré dans la légende.")
	for f in famous:
		out += "🗿 %s, %s de %s %s\n" % [InfoPanels.link("person:%d" % f["person"], f["name"]), f["title"], f["place"], InfoPanels.muted("(%s)" % Journal.format_day(f["day"]))]
	return out


static func achievements(st: Dictionary) -> String:
	var done := Achievements.unlocked(st)
	var out := "[b]🏆 Succès · %d/%d[/b]\n" % [done.size(), Achievements.LIST.size()]
	for a in Achievements.LIST:
		if done.has(a[0]):
			out += "%s — %s %s\n" % [a[1], a[2], InfoPanels.muted("(%s)" % Journal.format_day(done[a[0]]))]
		else:
			out += InfoPanels.muted("🔒 %s" % a[2]) + "\n"
	return out


static func world(st: Dictionary) -> String:
	var out := "[b]🌍 %s[/b]\n%s\n\n" % [st["name"], InfoPanels.muted("Jour %d · %s" % [st["day"], Weather.LABELS.get(st["weather"], "")])]
	if st.has("origin"):
		out += InfoPanels.muted("Planète fondée par les voyageurs venus de %s." % st["origin"]) + "\n\n"
	out += "🌱 Graine du monde : [b]%s[/b]\n" % st.get("seed_text", "?")
	out += InfoPanels.muted("Partage-la : la même graine donne la même planète.") + "\n\n"
	out += InfoPanels.link("chronicle:0", "📖 Le Livre du monde") + "   " + InfoPanels.link("pantheon:0", "🗿 Panthéon") + "   " + InfoPanels.link("achievements:0", "🏆 Succès") + "\n\n"
	if not st.get("ended", {}).is_empty():
		out += InfoPanels.link("action:colony", "🚀 Suivre le vaisseau et fonder une nouvelle planète") + "\n"
	out += InfoPanels.link("action:sound", "🔊 Activer ou couper le son") + "\n"
	out += InfoPanels.link("action:new", "🌱 Créer un nouveau monde") + "\n"
	out += InfoPanels.link("action:seed", "🔑 Créer un monde à partir d'une graine") + "\n\n"
	out += InfoPanels.muted("Le monde continue de vivre quand l'application est fermée.")
	return out
