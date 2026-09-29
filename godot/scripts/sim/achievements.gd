class_name Achievements
extends RefCounted

const LIST := [
	["feu", "🔥 Prométhée", "Découvrir le feu"],
	["cent", "👥 Une vraie communauté", "Atteindre 100 habitants"],
	["villes", "🏘️ Terre peuplée", "Compter 5 colonies en même temps"],
	["civ", "🏰 Naissance d'un royaume", "Voir naître une civilisation"],
	["religion", "🙏 La première foi", "Voir naître une religion"],
	["miracle", "✨ Faiseur de miracles", "Exaucer une prière"],
	["guerre", "⚔️ Le fracas des armes", "Assister à une guerre"],
	["paix", "🕊️ Les mains tendues", "Voir une guerre finir en paix"],
	["statue", "🗿 Mémoire de pierre", "Voir un habitant célèbre honoré d'une statue"],
	["dynastie", "👑 Lignée royale", "Voir une dynastie régner sur 3 générations"],
	["savoirs", "📚 Tous les savoirs", "Découvrir les 22 savoirs"],
	["espace", "🚀 Vers les étoiles", "Voir le grand départ"],
	["apocalypses", "🧟 Survivants", "Survivre à 3 apocalypses zombies"],
	["volcan", "🌋 Sous les cendres", "Survivre à l'éveil d'un volcan"],
	["contact", "🛸 Nous ne sommes pas seuls", "Recevoir une visite venue d'ailleurs"],
	["ruines", "🏺 Archéologues", "Fouiller les ruines d'une cité oubliée"],
	["siecle", "⏳ Un siècle d'histoire", "Faire vivre un monde 100 ans"],
	["millenaire", "🌍 Mille ans", "Faire vivre un monde 1000 ans"],
]
const EVENT_UNLOCKS := {"civilisation": "civ", "religion": "religion", "miracle": "miracle", "guerre": "guerre", "paix": "paix", "statue": "statue", "exode": "espace", "contact": "contact", "archeologie": "ruines"}


static func unlocked(state: Dictionary) -> Dictionary:
	if not state.has("achievements"):
		state["achievements"] = {}
	return state["achievements"]


static func _unlock(state: Dictionary, id: String) -> void:
	var done := unlocked(state)
	if done.has(id):
		return
	done[id] = state["day"]
	for a in LIST:
		if a[0] == id:
			Journal.log_event(state, "succes", "🏆 Succès débloqué : %s — %s." % [a[1], a[2]], {"achievement": id})


static func on_event(state: Dictionary, entry: Dictionary) -> void:
	if EVENT_UNLOCKS.has(entry["type"]):
		_unlock(state, EVENT_UNLOCKS[entry["type"]])
	elif entry["type"] == "cataclysme" and entry.get("volcano", false) and People.alive_count(state) > 0:
		_unlock(state, "volcan")
	elif entry["type"] == "dynastie" and entry.get("highlight", false):
		_unlock(state, "dynastie")
	elif entry["type"] == "apocalypse_fin" and state.get("zombies", {}).get("count", 0) >= 3:
		_unlock(state, "apocalypses")


static func daily(state: Dictionary) -> void:
	if state["day"] % 30 != 0:
		return
	var d: Dictionary = state["discoveries"]
	if d.has("feu"):
		_unlock(state, "feu")
	if d.size() >= Techs.ORDER.size():
		_unlock(state, "savoirs")
	if People.alive_count(state) >= 100:
		_unlock(state, "cent")
	if state["settlements"].filter(func(s): return s["abandoned"] < 0).size() >= 5:
		_unlock(state, "villes")
	if state["day"] >= 36000:
		_unlock(state, "siecle")
	if state["day"] >= 360000:
		_unlock(state, "millenaire")
