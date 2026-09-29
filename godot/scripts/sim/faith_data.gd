class_name FaithData
extends RefCounted

const SOURCES := {
	"rain": {
		"player": true, "emoji": "🌧️", "color": Color("64b5f6"), "deity": "le Faiseur de Pluie",
		"names": ["le Culte de la Pluie", "l'Église des Nuées", "les Enfants de l'Averse"],
		"legends": ["la Grande Pluie", "le Déluge béni", "les Larmes du Ciel"],
		"sign": "la pluie tombe",
		"founding": "🙏 Depuis {legend}, {name} en est sûr{e} : quelqu'un, là-haut, veille sur {place}. {Il} fonde {religion} et prie {deity}.",
	},
	"sun": {
		"player": true, "emoji": "☀️", "color": Color("ffd54f"), "deity": "l'Œil d'Or",
		"names": ["le Culte du Soleil", "l'Ordre de l'Aube", "les Fils de la Lumière"],
		"legends": ["le Grand Soleil", "le Jour sans Nuage", "l'Éveil du Ciel"],
		"sign": "le soleil revient",
		"founding": "🙏 Le jour où le ciel s'est ouvert, {name} a vu un œil d'or veiller sur {place}. {Il} fonde {religion} en l'honneur {ofDeity}.",
	},
	"grow": {
		"player": true, "emoji": "🌱", "color": Color("81c784"), "deity": "la Mère Verte",
		"names": ["le Culte de la Moisson", "la Voie des Semences", "les Gardiens du Bosquet"],
		"legends": ["le Printemps miraculeux", "la Grande Floraison", "l'Année d'Abondance"],
		"sign": "la terre reverdit en une nuit",
		"founding": "🙏 Depuis {legend}, {name} entend la voix {ofDeity} dans les champs de {place}. {Il} fonde {religion}.",
	},
	"storm": {
		"player": false, "emoji": "⛈️", "color": Color("9575cd"), "deity": "le Dieu de l'Orage",
		"names": ["le Culte de l'Orage", "les Enfants de la Foudre"],
		"founding": "⛈️ Chaque orage fait trembler {place}. {name} y voit la colère {ofDeity} et fonde {religion}.",
	},
	"ancestors": {
		"player": false, "emoji": "🕯️", "color": Color("bcaaa4"), "deity": "les Ancêtres",
		"names": ["le Culte des Ancêtres", "la Voie des Aïeux"],
		"founding": "🕯️ {name} rassemble {place} autour des tombes : les défunts veillent sur les vivants. {Il} fonde {religion}.",
	},
}

const PRAYERS := {
	"drought": {"answers": ["rain"], "wish": "la fin de la sécheresse"},
	"hunger": {"answers": ["grow", "rain"], "wish": "de quoi nourrir les affamés"},
	"storm": {"answers": ["sun"], "wish": "la fin de la tempête"},
	"cold": {"answers": ["sun"], "wish": "le retour de la chaleur"},
	"mourning": {"answers": [], "wish": "le repos de leurs morts"},
}

const POWER_LABELS := {"rain": "🌧️ Pluie", "sun": "☀️ Soleil", "grow": "🌱 Végétation"}
const SCHISM_NAMES := ["les Purs", "les Réformés", "les Fidèles de l'Aube", "les Nouveaux Croyants", "les Gardiens de la Vraie Foi"]
const SCHISM_COLORS := [Color("f06292"), Color("4db6ac"), Color("ff8a65"), Color("aed581"), Color("ba68c8"), Color("90a4ae")]


static func capitalize(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


static func of_name(name: String) -> String:
	if name.begins_with("le "):
		return "du " + name.substr(3)
	if name.begins_with("les "):
		return "des " + name.substr(4)
	return "de " + name


static func to_name(name: String) -> String:
	if name.begins_with("le "):
		return "au " + name.substr(3)
	if name.begins_with("les "):
		return "aux " + name.substr(4)
	return "à " + name


static func tell(story: String, p: Dictionary, s: Dictionary, fields: Dictionary) -> String:
	var female: bool = p["sex"] == "F"
	return story.replace("{name}", p["name"]).replace("{place}", s["name"]) \
		.replace("{religion}", fields.get("religion", "")).replace("{ofDeity}", of_name(fields.get("deity", ""))) \
		.replace("{deity}", fields.get("deity", "")).replace("{legend}", fields.get("legend", "le miracle")) \
		.replace("{Il}", "Elle" if female else "Il").replace("{il}", "elle" if female else "il").replace("{e}", "e" if female else "")
