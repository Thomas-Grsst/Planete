class_name Names
extends RefCounted

const SYLLABLES_A := ["Ni", "Mi", "E", "Ly", "As", "No", "Va", "Ka", "Te", "Ori", "Sa", "Lu", "Ra", "Il", "Ju", "Ma", "Fe", "To", "Ae", "Bri"]
const SYLLABLES_B := ["lo", "ra", "no", "a", "ter", "ria", "rek", "mar", "lis", "en", "do", "va", "ni", "ko", "sa", "wen", "ris", "la", "mo", "thi"]
const SYLLABLES_C := ["", "", "", "n", "s", "r", "l", "th", "k", "m"]
const PLACE_A := ["As", "Na", "Va", "El", "Or", "Tal", "Bel", "Kor", "Mir", "Sol", "Ven", "Dul", "Fal", "Hel", "Isk"]
const PLACE_B := ["ter", "mar", "rek", "ys", "ia", "dun", "wick", "heim", "ora", "ande", "ford", "mont", "vale", "holm", "brook"]
const TRAITS := ["curieux", "courageux", "agressif", "sociable", "travailleur", "inventif", "prudent", "aventurier"]
const TRAITS_FEM := {"curieux": "curieuse", "courageux": "courageuse", "agressif": "agressive", "travailleur": "travailleuse", "inventif": "inventive", "aventurier": "aventurière"}
const NAME_TRIES := 30


static func person_name(rng: Rng) -> String:
	return rng.pick(SYLLABLES_A) + rng.pick(SYLLABLES_B) + rng.pick(SYLLABLES_C)


static func place_name(rng: Rng, taken: Dictionary) -> String:
	var name: String = rng.pick(PLACE_A) + rng.pick(PLACE_B)
	for i in NAME_TRIES:
		if not taken.has(name):
			break
		name = rng.pick(PLACE_A) + rng.pick(PLACE_B)
	return name


static func trait_label(trait_key: String, sex: String) -> String:
	return TRAITS_FEM.get(trait_key, trait_key) if sex == "F" else trait_key


static func of_place(name: String) -> String:
	return "d'%s" % name if "AEIOUYÉÈÊÀÂÎÔÛ".contains(name.substr(0, 1).to_upper()) else "de %s" % name


static func plural(n: int, word: String) -> String:
	return "%d %s%s" % [n, word, "s" if n > 1 else ""]
