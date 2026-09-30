class_name Jobs
extends RefCounted

const DATA := {
	"enfant": {"emoji": "🧒", "label": "enfant", "fem": "enfant"},
	"cueilleur": {"emoji": "🌿", "label": "cueilleur", "fem": "cueilleuse"},
	"fermier": {"emoji": "🌾", "label": "fermier", "fem": "fermière"},
	"chasseur": {"emoji": "🏹", "label": "chasseur", "fem": "chasseuse"},
	"pêcheur": {"emoji": "🎣", "label": "pêcheur", "fem": "pêcheuse"},
	"bâtisseur": {"emoji": "🪓", "label": "bâtisseur", "fem": "bâtisseuse"},
	"guérisseur": {"emoji": "🌱", "label": "guérisseur", "fem": "guérisseuse"},
	"forgeron": {"emoji": "⚒️", "label": "forgeron", "fem": "forgeronne"},
	"gardien": {"emoji": "🛡️", "label": "gardien", "fem": "gardienne"},
	"chef": {"emoji": "👑", "label": "chef", "fem": "cheffe"},
	"bûcheron": {"emoji": "🪵", "label": "bûcheron", "fem": "bûcheronne"},
	"mineur": {"emoji": "⛏️", "label": "mineur", "fem": "mineuse"},
	"explorateur": {"emoji": "🧭", "label": "explorateur", "fem": "exploratrice"},
}
const REVIEW_DAYS := 15
const FAVORED := {
	"chasseur": ["courageux", "aventurier"], "pêcheur": ["prudent", "aventurier"], "bâtisseur": ["travailleur", "inventif"], "fermier": ["travailleur", "prudent"],
	"guérisseur": ["sociable", "prudent", "curieux"], "forgeron": ["inventif", "travailleur"], "gardien": ["courageux", "agressif"],
	"bûcheron": ["travailleur", "courageux"], "mineur": ["travailleur", "prudent"], "explorateur": ["aventurier", "curieux"],
}


static func label(job: String, sex: String) -> String:
	var d: Dictionary = DATA.get(job, DATA["cueilleur"])
	return d["fem"] if sex == "F" else d["label"]


static func emoji(job: String) -> String:
	return DATA.get(job, DATA["cueilleur"])["emoji"]


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for id in census:
		var e: Dictionary = census[id]
		for p in e["people"]:
			if p["job"] == "enfant" and People.is_adult(state, p):
				p["job"] = "cueilleur"
				Journal.remember(state, p, "%s devient %s." % [p["name"], label("cueilleur", p["sex"])])
		if (state["day"] + int(id)) % REVIEW_DAYS == 0:
			_rebalance(state, rng, e)


static func _desired(state: Dictionary, e: Dictionary) -> Dictionary:
	var s: Dictionary = e["s"]
	var workers: int = e["adults"]
	var d := {"bâtisseur": clampi(int(round(workers * 0.15)), 1, 4), "chasseur": 0, "pêcheur": 0, "fermier": 0}
	if Herds.huntable_near(state, s) != null:
		d["chasseur"] = int(round(workers * 0.15))
	if s["geo"]["water"] > 0:
		d["pêcheur"] = int(round(workers * (0.25 if Techs.has_tech(s, "peche") else 0.1) * clamp(s.get("fish_rate", 1.0) + 0.25, 0.3, 1.0)))
	if Techs.has_tech(s, "agriculture"):
		d["fermier"] = mini(int(round(workers * 0.35)), int(ceil(Harvest.fields(state, s)["count"] * Harvest.FARMERS_PER_FIELD)))
	d["guérisseur"] = (1 + (2 if not s.get("outbreak", {}).is_empty() else 0)) if Techs.has_tech(s, "plantes") and workers >= 8 else 0
	d["forgeron"] = (1 if workers >= 8 else 0) + (1 if workers >= 30 else 0) if Techs.METALS.any(func(k): return Techs.has_tech(s, k)) and Mining.has_supply(s) else 0
	d["gardien"] = (1 if workers >= 12 else 0) + (int(round(workers * 0.15)) if Threats.pressing(state, s) else 0)
	# Quand on mange à sa faim, on peut envoyer des bras au bois, à la mine et au-delà des collines.
	var fed: bool = e["hungry"] <= max(1, e["pop"] * 0.1) and s["food"] >= Trade.food_cap(e) * 0.25
	d["bûcheron"] = (clampi(int(round(workers * 0.12)), 1, 4) if fed else 1) if workers >= 5 and Work.cached_trees(state, s) >= 8 else 0
	d["mineur"] = (clampi(int(round(workers * 0.12)), 1, 4) if fed else 1) if workers >= 5 and Mining.site(state, s) != null and not Mining.available(s).is_empty() else 0
	d["explorateur"] = (1 + (1 if workers >= 25 else 0)) if fed and workers >= 6 else 0
	return d


static func _rebalance(state: Dictionary, rng: Rng, e: Dictionary) -> void:
	var adults: Array = e["people"].filter(func(p): return p["job"] != "enfant")
	if adults.size() < 2:
		return
	var wanted := _desired(state, e)
	var counts := {}
	for p in adults:
		counts[p["job"]] = counts.get(p["job"], 0) + 1
	for job in wanted:
		while counts.get(job, 0) > wanted[job]:
			var worker = _find(adults, job)
			worker["job"] = "cueilleur"
			counts[job] -= 1
		while counts.get(job, 0) < wanted[job]:
			var idle = _best_for(adults, job)
			if idle == null:
				break
			idle["job"] = job
			counts[job] = counts.get(job, 0) + 1
			counts["cueilleur"] = counts.get("cueilleur", 0) - 1
			Journal.remember(state, idle, "%s devient %s." % [idle["name"], label(job, idle["sex"])])


static func _find(adults: Array, job: String):
	for p in adults:
		if p["job"] == job:
			return p
	return null


static func _best_for(adults: Array, job: String):
	var best = null
	var best_score := -1
	for p in adults:
		if p["job"] != "cueilleur":
			continue
		var score := 0
		for t in FAVORED.get(job, []):
			if p["traits"].has(t):
				score += 1
		if score > best_score:
			best_score = score
			best = p
	return best
