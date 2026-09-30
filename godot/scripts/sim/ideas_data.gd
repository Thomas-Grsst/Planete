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
	"radeau": {"mean": 400, "needs": {"island": 2.0, "hunger": 1.3}, "triggers": [
		["river", 1.0, "🛶 {name} voit un tronc flotter sur la rivière près de {place}. Quelques troncs liés plus tard, le premier radeau glisse sur l'eau."],
		["water", 0.4, "🛶 {name} assemble le premier radeau à {place}."]]},
	"plantes": {"mean": 400, "needs": {}, "triggers": [
		["sick+forest", 1.0, "🌱 Pendant l'épidémie, {name} remarque que certaines feuilles apaisent les malades de {place}."],
		["swamp", 0.2, "🌱 {name} découvre les herbes qui soignent dans le marais près de {place}."],
		["forest", 0.15, "🌱 {name} découvre les plantes qui soignent dans la forêt près de {place}."]]},
	"agriculture": {"mean": 1200, "needs": {"hunger": 3.0, "bigpop": 1.5}, "triggers": [
		["fertile", 1.0, "🌾 {name} remarque que des graines tombées près du camp de {place} ont germé. {Il} en sème d'autres : l'agriculture est née."],
		["river", 0.7, "🌾 Sur les berges fertiles près de {place}, {name} plante les premières graines : l'agriculture est née."],
		["dream", 0.2, "🌾 {name} invente l'agriculture à {place}."]]},
	"poterie": {"mean": 600, "needs": {"tech:agriculture": 2.0}, "triggers": [
		["argile", 1.0, "🏺 {name} façonne la terre grasse près de {place} et la cuit dans le feu : les premières poteries."],
		["dream", 0.05, "🏺 {name} façonne les premières poteries à {place}."]]},
	"cuivre": {"mean": 150, "needs": {}, "triggers": [
		["cuivre", 1.0, "🟢 {name} ramasse une pierre verte dans la montagne près de {place}. Chauffée dans le feu, elle suinte un métal rouge : le cuivre."],
		["trade:cuivre", 0.3, "🟢 Des voyageurs montrent à {name} une pierre verte qui fond au feu : le cuivre arrive à {place}."],
		["mine", 0.3, "⛏️ Au fond de la mine de {place}, {name} tombe sur une veine de pierre verte. Chauffée dans le feu, elle donne un métal rouge : le cuivre."]]},
	"metallurgie": {"mean": 1000, "needs": {"wolves": 1.5, "zombies": 2.0}, "triggers": [
		["etain", 1.0, "⚒️ {name} mêle le cuivre à un métal gris et mou trouvé près de {place} : le bronze, plus dur que tout."],
		["trade:etain", 0.4, "⚒️ Grâce à un métal gris venu d'ailleurs, {name} invente le bronze à {place}."],
		["mine", 0.12, "⚒️ Les mineurs de {place} remontent un métal gris et mou. {name} le mêle au cuivre : le bronze, plus dur que tout."]]},
	"fer": {"mean": 3000, "needs": {"tech:metallurgie": 3.0, "charbon": 1.5}, "triggers": [
		["fer", 1.0, "⛓️ {name} chauffe une roche rouge et lourde plus fort que jamais à {place} : le fer."],
		["trade:fer", 0.3, "⛓️ Avec une roche rouge rapportée par des voyageurs, {name} obtient le fer à {place}."],
		["dream", 0.03, "☄️ Une pierre tombe du ciel près de {place}. {name} en tire un métal inconnu : le fer."],
		["mine", 0.08, "⛓️ Dans la mine de {place}, {name} trouve une roche rouge et lourde qui, chauffée très fort, donne le fer."]]},
	"epee": {"mean": 200, "needs": {}, "triggers": [
		["zombies", 2.0, "🗡️ Face aux morts qui marchent, {name} forge la première épée à {place}."],
		["wolves", 1.0, "🗡️ Après une attaque de loups, {name} forge la première lame à {place}."],
		["dream", 0.05, "🗡️ {name} forge la première épée à {place}."]]},
	"charrue": {"mean": 800, "needs": {}, "triggers": [
		["hunger", 1.0, "🚜 La faim pousse {name} à fixer du métal à un soc de bois : la première charrue retourne la terre de {place}."],
		["bigpop", 0.5, "🚜 Pour nourrir tout {place}, {name} invente la charrue."],
		["dream", 0.1, "🚜 {name} invente la charrue à {place}."]]},
	"sylviculture": {"mean": 600, "needs": {"hunger": 1.3}, "triggers": [
		["deforested", 1.0, "🌳 Il ne reste presque plus d'arbres autour de {place}. {name} plante des glands et protège les jeunes pousses : la forêt reviendra."],
		["dream", 0.01, "🌳 {name} apprend à replanter les arbres à {place}."]]},
	"roue": {"mean": 5000, "needs": {"bigpop": 1.5}, "triggers": [
		["tech:poterie", 1.0, "☸️ En regardant son tour de potier tourner, {name} a une idée à {place} : la roue."],
		["stone", 0.4, "☸️ {name} voit un tronc dévaler la pente près de {place} : la roue."],
		["dream", 0.1, "☸️ {name} invente la roue à {place}."]]},
	"navigation": {"mean": 5000, "needs": {"island": 3.0, "crowded": 1.5}, "triggers": [
		["coast", 1.0, "⛵ {name} dresse une voile sur un grand radeau à {place} : le premier bateau prend la mer."],
		["sea", 0.5, "🌊 De retour d'une longue marche, {name} raconte à {place} la mer sans fin qu'{il} a vue. On y descend avec un radeau à voile : la navigation est née."]]},
	"ecriture": {"mean": 45000, "needs": {"lostLore": 4.0, "bigpop": 1.5}, "triggers": [
		["lostLore+pop30", 1.0, "📜 Après la perte d'un savoir ancien, {name} invente des signes pour ne plus jamais oublier, à {place} : l'écriture."],
		["pop30", 1.0, "📜 {name} grave des signes dans l'argile à {place} pour que rien ne s'oublie : l'écriture."]]},
	"medecine": {"mean": 24000, "needs": {}, "triggers": [
		["sick", 1.0, "⚕️ Pendant l'épidémie, {name} note les remèdes de chaque malade de {place} : la médecine est née."],
		["dream", 0.2, "⚕️ {name} fonde la médecine à {place}."]]},
	"architecture": {"mean": 40000, "needs": {}, "triggers": [
		["stormDamage", 1.0, "🏛️ Après que la tempête a détruit des maisons de {place}, {name} dessine des murs plus solides : l'architecture."],
		["bigpop", 0.4, "🏛️ {name} dessine les premiers grands bâtiments de {place}."],
		["dream", 0.1, "🏛️ {name} invente l'architecture à {place}."]]},
	"lois": {"mean": 40000, "needs": {"bigpop": 1.5, "crowded": 1.3}, "triggers": [
		["council", 1.0, "⚖️ Le conseil de {place} demande à {name} de graver les premières lois."],
		["chef", 0.6, "⚖️ {name} établit les premières lois de {place}."]]},
	"machines": {"mean": 50000, "needs": {}, "triggers": [
		["charbon", 1.0, "⚙️ {name} fait bouillir de l'eau sur un feu de charbon à {place} : la vapeur met en marche la première machine."],
		["trade:charbon", 0.5, "⚙️ Avec du charbon venu d'ailleurs, {name} met en marche la première machine à {place}."],
		["forest", 0.2, "⚙️ {name} met en marche une machine à vapeur au bois à {place}."]]},
	"electricite": {"mean": 40000, "needs": {}, "triggers": [
		["storm", 1.0, "💡 Pendant l'orage, {name} capture la foudre dans un fil de métal à {place} : l'électricité. Les nuits s'illuminent."],
		["dream", 0.3, "💡 {name} apprivoise l'électricité à {place}. Les nuits s'illuminent."]]},
	"fusee": {"mean": 30000, "needs": {"crowded": 1.5}, "triggers": [
		["dream", 1.0, "🚀 {name} lève les yeux vers les étoiles et construit la première fusée à {place}. Tous les regards se tournent vers le ciel."]]},
	"espace": {"mean": 20000, "needs": {}, "triggers": [
		["dream", 1.0, "🌌 {name} maîtrise le voyage spatial à {place}. Le grand départ est prévu dans 60 jours."]]},
}
