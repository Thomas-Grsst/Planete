class_name IdeasData
extends RefCounted

const DATA := {
	"feu": {"mean": 10, "needs": {"winter": 2.0}, "triggers": [
		["lightning", 1.0, "⚡ La foudre frappe un arbre près de {place}. {name} ose approcher des flammes et rapporte une braise : le feu est à eux."],
		["drought", 0.6, "🔥 Un feu de brousse gronde près de {place}. {name} garde une branche enflammée : le feu ne s'éteindra plus."],
		["stone", 0.08, "🪨 En frappant deux pierres, {name} fait jaillir une étincelle à {place}. Le feu est né."],
		["dream", 0.03, "🪵 À force de frotter deux bâtons, {name} fait naître une flamme à {place}."]]},
	"outils": {"mean": 60, "needs": {}, "triggers": [
		["obsidienne", 1.5, "🔷 {name} trouve un verre noir tranchant près de {place} : les premières lames d'obsidienne."],
		["stone", 1.0, "🪨 {name} taille un silex contre un rocher près de {place} : les premiers outils."],
		["bone", 0.5, "🦴 Après une chasse, {name} façonne des outils avec les os du gibier à {place}."],
		["dream", 0.05, "🪨 {name} apprend à tailler la pierre à {place}."]]},
	"peche": {"mean": 120, "needs": {"hunger": 2.0}, "triggers": [
		["water", 1.0, "🎣 {name} observe les poissons près de {place} et tresse le premier filet."]]},
	"radeau": {"mean": 400, "needs": {"hunger": 1.3}, "triggers": [
		["river", 1.0, "🛶 {name} voit un tronc flotter sur la rivière près de {place}. Quelques troncs liés plus tard, le premier radeau glisse sur l'eau."],
		["water", 0.4, "🛶 {name} assemble le premier radeau à {place}."]]},
	"plantes": {"mean": 400, "needs": {}, "triggers": [
		["swamp", 0.3, "🌱 {name} découvre les herbes qui soignent dans le marais près de {place}."],
		["forest", 0.2, "🌱 {name} découvre les plantes qui soignent dans la forêt près de {place}."]]},
	"agriculture": {"mean": 1200, "needs": {"hunger": 3.0, "bigpop": 1.5}, "triggers": [
		["fertile", 1.0, "🌾 {name} remarque que des graines tombées près du camp de {place} ont germé. {Il} en sème d'autres : l'agriculture est née."],
		["river", 0.7, "🌾 Sur les berges fertiles près de {place}, {name} plante les premières graines : l'agriculture est née."],
		["dream", 0.2, "🌾 {name} invente l'agriculture à {place}."]]},
	"poterie": {"mean": 600, "needs": {"tech:agriculture": 2.0}, "triggers": [
		["argile", 1.0, "🏺 {name} façonne la terre grasse près de {place} et la cuit dans le feu : les premières poteries."],
		["dream", 0.05, "🏺 {name} façonne les premières poteries à {place}."]]},
	"cuivre": {"mean": 150, "needs": {}, "triggers": [
		["cuivre", 1.0, "🟢 {name} ramasse une pierre verte dans la montagne près de {place}. Chauffée dans le feu, elle suinte un métal rouge : le cuivre."]]},
	"roue": {"mean": 5000, "needs": {"bigpop": 1.5}, "triggers": [
		["tech:poterie", 1.0, "☸️ En regardant son tour de potier tourner, {name} a une idée à {place} : la roue."],
		["dream", 0.1, "☸️ {name} invente la roue à {place}."]]},
}
