class_name Jobs
extends RefCounted

const DATA := {
	"enfant": {"emoji": "🧒", "label": "enfant", "fem": "enfant"},
	"cueilleur": {"emoji": "🌿", "label": "cueilleur", "fem": "cueilleuse"},
	"fermier": {"emoji": "🌾", "label": "fermier", "fem": "fermière"},
	"chasseur": {"emoji": "🏹", "label": "chasseur", "fem": "chasseuse"},
	"pêcheur": {"emoji": "🎣", "label": "pêcheur", "fem": "pêcheuse"},
	"bâtisseur": {"emoji": "🪓", "label": "bâtisseur", "fem": "bâtisseuse"},
}
const REVIEW_DAYS := 15
const FAVORED := {"chasseur": ["courageux", "aventurier"], "pêcheur": ["prudent", "aventurier"], "bâtisseur": ["travailleur", "inventif"], "fermier": ["travailleur", "prudent"]}


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
		d["pêcheur"] = int(round(workers * (0.25 if Techs.has_tech(s, "peche") else 0.1)))
	if Techs.has_tech(s, "agriculture"):
		d["fermier"] = int(round(workers * 0.35))
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
