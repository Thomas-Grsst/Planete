class_name Epics
extends RefCounted

# Épopées : un héros part avec quelques compagnons chercher une terre dont parlent les légendes.
# Le journal raconte le voyage en plusieurs étapes (épreuves, rencontres, pertes), puis le dénouement :
# une nouvelle colonie, un retour chargé de trésors et de savoir, ou une disparition qui devient légende.

const MIN_POP := 25
const START_CHANCE := 0.002
const GAP_DAYS := 900
const MAX_ACTIVE := 2
const PARTY := [2, 5]
const DISTANCE := [22, 40]
const STEP_DAYS := [45, 110]
const TRIALS := [2, 4]
const HERO_FAME := 5
const PLACES := ["la Terre", "l'Île", "la Vallée", "la Montagne", "la Source", "la Cité", "la Forêt", "la Mer"]
const MARVELS := ["des Mille Soleils", "aux Géants", "qui Chante", "Blanche", "d'Or", "sans Hiver", "des Premiers Ancêtres", "aux Étoiles Tombées", "d'Émeraude", "du Bout du Monde"]


static func epics(state: Dictionary) -> Array:
	return state.get_or_add("epics", [])


static func on_quest(p: Dictionary) -> bool:
	return p.get("quest", -1) >= 0


static func step(state: Dictionary, rng: Rng, census: Dictionary) -> void:
	for q in epics(state).duplicate():
		if state["day"] >= q["next_day"]:
			_advance(state, rng, census, q)
	if epics(state).size() < MAX_ACTIVE and state["day"] >= state.get("epic_next", 0):
		for id in census:
			if census[id]["pop"] >= MIN_POP and rng.chance(START_CHANCE):
				_start(state, rng, census[id])
				break


static func _legend(rng: Rng) -> String:
	return "%s %s" % [rng.pick(PLACES), rng.pick(MARVELS)]


static func _start(state: Dictionary, rng: Rng, e: Dictionary) -> void:
	var s: Dictionary = e["s"]
	var adults: Array = e["people"].filter(func(p): return People.is_adult(state, p) and People.age_of(state, p) <= 45 and p["job"] != "chef" and not on_quest(p))
	var bold: Array = adults.filter(func(p): return p["traits"].has("aventurier") or p["traits"].has("courageux"))
	if bold.is_empty() or adults.size() < 8:
		return
	var hero: Dictionary = rng.pick(bold)
	var party: Array = [hero]
	for p in adults:
		if party.size() >= rng.range_int(PARTY[0], PARTY[1]):
			break
		if not is_same(p, hero) and (p["id"] == hero["partner"] or p["traits"].has("aventurier") or rng.chance(0.15)):
			party.append(p)
	var a := rng.next() * TAU
	var d := rng.range_int(DISTANCE[0], DISTANCE[1])
	var goal := Vector2i(s["x"] + int(round(cos(a) * d)), s["y"] + int(round(sin(a) * d)))
	state["next_id"] += 1
	var q := {"id": state["next_id"], "hero": hero["id"], "party": party.map(func(p): return p["id"]), "from": s["id"], "legend": _legend(rng),
		"goal": goal, "step": 0, "trials": rng.range_int(TRIALS[0], TRIALS[1]), "next_day": state["day"] + rng.range_int(STEP_DAYS[0], STEP_DAYS[1]), "start": state["day"], "gift": ""}
	for p in party:
		p["quest"] = q["id"]
	epics(state).append(q)
	state["epic_next"] = state["day"] + GAP_DAYS
	var company := "seule" if party.size() == 1 and hero["sex"] == "F" else ("seul" if party.size() == 1 else "avec %s" % Names.plural(party.size() - 1, "compagnon"))
	Journal.log_event(state, "epopee", "🗺️ Les anciens %s parlent de %s. %s part %s pour la trouver." % [Names.of_place(s["name"]), q["legend"], hero["name"], company],
		{"x": s["x"], "y": s["y"], "settlement": s["id"], "person": hero["id"], "to_x": goal.x, "to_y": goal.y, "highlight": true, "epic": q["id"]})


static func _members(state: Dictionary, q: Dictionary) -> Array:
	var out: Array = []
	for id in q["party"]:
		var p = People.by_id(state, id)
		if p != null and p["alive"] and p.get("quest", -1) == q["id"]:
			out.append(p)
	return out


static func _where(q: Dictionary, state: Dictionary) -> Vector2i:
	var home = Settlements.by_id(state, q["from"])
	var start: Vector2i = Vector2i(home["x"], home["y"]) if home != null else q["goal"]
	var f: float = float(q["step"] + 1) / float(q["trials"] + 1)
	return Vector2i(Vector2(start).lerp(Vector2(q["goal"]), f).round())


static func _advance(state: Dictionary, rng: Rng, census: Dictionary, q: Dictionary) -> void:
	var party := _members(state, q)
	var hero = People.by_id(state, q["hero"])
	if party.is_empty() or hero == null or not hero["alive"]:
		_lost(state, q, party, "le héros a péri")
		return
	if q["step"] < q["trials"]:
		_trial(state, rng, census, q, party, hero)
		q["step"] += 1
		q["next_day"] = state["day"] + rng.range_int(STEP_DAYS[0], STEP_DAYS[1])
		return
	var roll := rng.next()
	if roll < 0.45 and _settle(state, rng, q, party, hero):
		return
	if roll < 0.8:
		_return(state, rng, census, q, party, hero)
	else:
		_lost(state, q, party, "")


static func _trial(state: Dictionary, rng: Rng, census: Dictionary, q: Dictionary, party: Array, hero: Dictionary) -> void:
	var at := _where(q, state)
	var extra := {"x": at.x, "y": at.y, "person": hero["id"], "epic": q["id"]}
	var kind: String = rng.pick(["storm", "danger", "people", "doubt", "marvel", "danger", "people"])
	if kind == "danger" and party.size() > 1:
		var victim: Dictionary = party[party.size() - 1]
		People.kill(state, victim, "pendant la quête de %s" % q["legend"])
		Journal.log_event(state, "epopee", "💀 Sur la route de %s, %s tombe sous les griffes d'un ours géant. %s l'enterre et repart." % [q["legend"], victim["name"], hero["name"]], extra)
	elif kind == "doubt" and party.size() > 1:
		var weary: Dictionary = party[party.size() - 1]
		weary.erase("quest")
		Journal.log_event(state, "epopee", "🥾 Épuisé%s, %s renonce et rebrousse chemin. %s continue vers %s." % ["e" if weary["sex"] == "F" else "", weary["name"], hero["name"], q["legend"]], extra)
	elif kind == "people":
		var home = Settlements.by_id(state, q["from"])
		var gift := _foreign_idea(state, home)
		if gift != "" and q["gift"] == "":
			q["gift"] = gift
			Journal.log_event(state, "epopee", "🏕️ %s et les siens croisent un peuple lointain qui leur enseigne le secret %s." % [hero["name"], Techs.DATA[gift]["de"]], extra)
		else:
			Journal.log_event(state, "epopee", "🏕️ Un peuple de bergers accueille %s pour l'hiver et lui indique le chemin de %s." % [hero["name"], q["legend"]], extra)
	elif kind == "marvel":
		Fame.add(hero, 1)
		Journal.log_event(state, "epopee", "✨ %s voit ce qu'aucun des siens n'a vu : des lumières qui dansent dans le ciel du nord. On le chantera longtemps." % hero["name"], extra)
	else:
		Journal.log_event(state, "epopee", "🌨️ Une tempête retient %s dans les montagnes pendant des semaines. Le groupe repart, amaigri." % hero["name"], extra)


# Un savoir que le village du héros ignore et qu'on peut apprendre en route.
static func _foreign_idea(state: Dictionary, home) -> String:
	if home == null:
		return ""
	for k in Techs.ORDER:
		if Techs.can_learn(home, k) and state["discoveries"].has(k):
			return k
	return ""


static func _finish(state: Dictionary, q: Dictionary, party: Array) -> void:
	for p in party:
		p.erase("quest")
	epics(state).erase(q)


static func _settle(state: Dictionary, rng: Rng, q: Dictionary, party: Array, hero: Dictionary) -> bool:
	if party.size() < 2:
		return false
	Exploration.reveal(state, rng, q["goal"].x, q["goal"].y, 5)
	var spot = Geography.find_spot(state, rng, q["goal"].x, q["goal"].y, 8, true)
	if spot == null:
		return false
	var home = Settlements.by_id(state, q["from"])
	var colony := Settlements.create(state, rng, spot.x, spot.y, home)
	for p in party:
		p["home"] = colony["id"]
	_finish(state, q, party)
	Fame.add(hero, HERO_FAME)
	var years: int = max(1, (state["day"] - q["start"]) / 360)
	Journal.log_event(state, "epopee", "🏝️ Après %s d'errance, %s atteint enfin %s et y fonde %s. La légende était vraie." % [Names.plural(years, "an"), hero["name"], q["legend"], colony["name"]],
		{"x": spot.x, "y": spot.y, "settlement": colony["id"], "person": hero["id"], "highlight": true, "map": true, "epic": q["id"]})
	return true


static func _return(state: Dictionary, rng: Rng, census: Dictionary, q: Dictionary, party: Array, hero: Dictionary) -> void:
	var home = Settlements.by_id(state, q["from"])
	_finish(state, q, party)
	Fame.add(hero, HERO_FAME)
	if home == null or home["abandoned"] >= 0:
		return
	var treasure := ""
	if q["gift"] != "" and Techs.can_learn(home, q["gift"]):
		Ideas.discover(state, home, q["gift"], hero, home, "📜 De retour de sa quête, %s enseigne à %s le secret %s appris au bout du monde." % [hero["name"], home["name"], Techs.DATA[q["gift"]]["de"]])
		treasure = " et un savoir inconnu"
	else:
		var store := Mining.stock(home)
		store["or"] = min(Mining.YIELDS["or"]["cap"], store.get("or", 0.0) + 5.0)
		treasure = " et un coffre d'or"
	Journal.log_event(state, "epopee", "🏠 %s rentre à %s sans avoir trouvé %s, mais avec des récits pour toute une vie%s." % [hero["name"], home["name"], q["legend"], treasure],
		{"x": home["x"], "y": home["y"], "settlement": home["id"], "person": hero["id"], "highlight": true, "epic": q["id"]})


static func _lost(state: Dictionary, q: Dictionary, party: Array, why: String) -> void:
	var home = Settlements.by_id(state, q["from"])
	var hero = People.by_id(state, q["hero"])
	for p in party:
		People.kill(state, p, "disparu pendant la quête de %s" % q["legend"])
	_finish(state, q, party)
	var name: String = hero["name"] if hero != null else "Le héros"
	var place: String = home["name"] if home != null else "son village"
	Journal.log_event(state, "epopee", "🌫️ On ne revit jamais %s ni ses compagnons. À %s, on chante encore leur départ pour %s." % [name, place, q["legend"]],
		{"x": home["x"] if home != null else 0, "y": home["y"] if home != null else 0, "highlight": true, "epic": q["id"]})
