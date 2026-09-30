# Petite Planète — Feuille de route

État actuel : **version Godot 4 complète + APK Android avec notifications et widget** (la version web est figée dans `web/`) : civilisations, territoires, diplomatie et guerres, religions nées de tes miracles, en plus des métiers, des 22 savoirs découverts par causes, des maladies, de l'apocalypse zombie et du cycle jour/nuit de 5 min.

---

## 🎮 Passage à Godot 4 (fait)

Objectif : un monde **qui bouge sous tes yeux**, pas seulement dans le journal, et une vraie app Android.

- [x] Monde généré, terrain isométrique, eau animée, arbres qui ondulent, saisons visibles.
- [x] Habitants animés qui suivent l'heure : travail, récolte rapportée au village, veillée au feu, sommeil.
- [x] Villages : maisons qui apparaissent, chantiers visibles, champs, feu de camp, fumée, fenêtres allumées, défrichage.
- [x] Troupeaux (cerfs, moutons, loups) qui errent ; météo (pluie, neige, éclairs) ; jour et nuit.
- [x] Simulation : naissances, couples, famines, métiers, migrations et nouvelles colonies, 9 premiers savoirs par causes.
- [x] Sauvegarde, rattrapage hors ligne progressif, écran « Bon retour », fiches habitant et village, journal.
- [x] Pouvoirs (pluie, soleil, végétation, avancer le temps) et religions : prières visibles le soir, miracles, légendes, prophètes auréolés, pèlerins missionnaires, temples et grands temples, schismes.
- [x] Tout le reste de la version web : 22 savoirs, savoir fragile, maladies, loups, zombies et leur pouvoir, chefs, conseils, civilisations, territoires, diplomatie, guerres, religion officielle et guerres saintes.
- [x] Export Android (APK, testé dans l'émulateur).
- [x] Notifications Android et widget d'écran d'accueil (plugin Android natif, prévision déterministe des événements).
- [x] Sons d'ambiance générés (oiseaux, grillons, pluie, feu, cloche, carillon, cor, tonnerre).

## ⏱️ Rythme du temps (à faire en premier)

- [x] 1 jour de jeu = **5 min réelles** (2 min 30 de jour + 2 min 30 de nuit) → ~292 ans de jeu par an réel.
- [x] Vrai **cycle jour/nuit visible** : lumière, nuit sombre, fenêtres et feux allumés.
- [x] Revoir les vitesses ▶▶ / ▶▶▶ (ajouter un ×100 pour voir le monde bouger).
- [x] Ajuster `MAX_OFFLINE_DAYS` au nouveau rythme.

## 💡 Découvertes par causes (priorité n°1, avant ou avec la V3)

Remplacer les « points de savoir » par des **idées déclenchées** : fini le rythme identique d'un monde à l'autre.

- [x] Chaque découverte = **déclencheur concret** + **besoin** + **bonne personne** (curieux / inventif).
  - Foudre qui enflamme un arbre → feu ; pierre verte ramassée → cuivre ; tronc qui flotte → radeau ; graine qui germe → agriculture…
  - Besoins : famine → agriculture, loups/guerre → armes, île voisine → bateau, épidémie → remèdes.
- [x] **Ressources réparties inégalement** sur la carte : cuivre, étain, fer, argile, charbon, obsidienne.
- [x] **Objets inventés** avec un vrai effet : épée, charrue, radeau, poterie, roue…
- [x] Arbre en **réseau à plusieurs chemins** (métal → épée *ou* charrue selon le besoin).
- [x] **Savoir qui se perd** : l'inventeur meurt avant de transmettre → à redécouvrir. Maître/apprenti, puis l'écriture empêche l'oubli.
- [x] Portes de sortie contre la stagnation : voyageurs qui rapportent des idées, commerce, chemins alternatifs (outils en os/obsidienne sans bronze).
- [x] Journal qui raconte **pourquoi** (« Nilo ramasse une pierre verte… »), pas seulement quand.
- [x] Tester sur des dizaines de mondes : écarts de rythme intéressants mais pas frustrants.

## 🏛️ V3 — Civilisations

- [x] Plusieurs colonies se regroupent en **civilisation** (nom, culture, capitale).
- [x] **Territoires** visibles sur la carte.
- [x] **Diplomatie** : alliances, traités, commerce.
- [x] **Guerres et conquêtes** entre colonies/civilisations.
- [x] Base existante : chef, conseil, tech Lois (`governance.js`).
- [x] Chaque civilisation a sa propre histoire technologique (grâce aux découvertes par causes).

## 🔧 Restes de la V2 à corriger

- [x] La **Navigation** se déclenche rarement : les colonies s'installent peu sur les côtes (dépend de la carte). *Les côtes comptent comme zones de pêche, et un explorateur qui a vu la mer peut inspirer la navigation : 16 mondes sur 16 l'ont (vers l'an 20 en médiane), contre 5 sur 16 avant.*
- [x] L'écran « Bon retour » affiche toujours les naissances et les décès (jusqu'à 10 catégories).

## 📱 Widget et notifications

- [x] Version web figée (`web/`, étiquette git `web-final`) : tout continue dans Godot.
- [x] App Android : faite avec l'export Godot (APK installé sans Play Store).
- [x] Vraies notifications (« Aster a découvert le bronze »), programmées à l'heure où l'événement arrive, jamais la nuit.
- [x] Widget : nom du monde, jour, population et dernier grand événement, sans ouvrir le jeu.
- [x] Rattrapage aussi quand le jeu revient de l'arrière-plan (écran « Bon retour »).
- ~~iPhone~~ : pas prévu.

---

## 🌟 Idées pour les versions suivantes

### 🌍 Monde vivant
- [x] Saisons visibles (neige, arbres roux, rivières gelées).
- [x] Catastrophes qui changent la carte : volcans, séismes, inondations, météorites.
- [x] Changement climatique causé par une civilisation industrielle (montée des eaux).

### 👤 Attachement aux habitants
- [x] Arbre généalogique interactif.
- [x] Personnages célèbres (inventeur, conquérant, prophète) avec statue.
- [x] Dynasties au pouvoir sur plusieurs générations.
- [x] Rivalités et amitiés (duels, alliances, trahisons).

### 🎭 Culture
- [x] Religions inventées, prophètes, schismes — **tes pouvoirs vus comme des miracles** (un culte envers toi).
  - Prières des villages en détresse, prières exaucées, missionnaires, temples, religion officielle, guerres saintes.
- [x] Langues inventées qui dérivent entre colonies isolées.
- [x] Monuments visibles de loin (pyramides, temples, observatoires).
- [x] Légendes qui racontent tes interventions (« Le Grand Déluge de l'An 12 »).

### 🌊 Monde ouvert
- [x] **Ressources limitées** : poissons qui se reproduisent (surpêche possible), champs limités par les terres fertiles et sol qui s'épuise, filons qui se vident, sylviculture pour replanter.
- [x] **Carte presque infinie** créée par morceaux quand on la découvre, brume aux limites des terres connues, rendu uniquement autour de la caméra.
- [x] **Ports**, barques de pêche, expéditions à pied et en bateau (explorateurs perdus en mer), colonies sur les îles.
- [x] **Routes commerciales** durables sur terre et sur mer, qui échangent vivres, bois et métal.
- [x] **Guerres sur terre et sur mer** : débarquements, batailles navales, blocus, sièges, palissades et murailles, fronts qui avancent, guerres pour les ressources.
- [x] **Rotation de la vue** par quarts de tour (↻).

### ⚔️ Après la V3
- [x] Routes commerciales et caravanes visibles, bateaux et ports.
- [x] Révolutions contre les chefs impopulaires.
- [x] Espions, pirates, barbares des terres sauvages.

### 🚀 Fin de partie spatiale
- [x] Suivre le vaisseau après l'exode et fonder une **nouvelle planète**.
- [x] Contact extraterrestre (ultra-rare).
- [x] Archéologie : une civilisation découvre les ruines de la précédente.

### 🧟 Autres fléaux
- [x] Animaux mutants, nouvelles espèces.
- [x] IA rebelle chez une civilisation avancée.

### 🎮 Pour le joueur
- [x] Replay accéléré (1 000 ans en 30 secondes).
- [x] **Chronique automatique** : « Le Livre de Noria ».
- [x] Partage de graine de monde entre amis.
- [x] Succès (« Atteindre l'espace », « Survivre à 3 apocalypses »…).

**Coups de cœur** (renforcent le « qu'est-ce qui s'est passé pendant mon absence ? ») : ~~découvertes par causes~~, ~~religions liées à tes pouvoirs~~, ~~personnages célèbres~~, ~~chronique automatique~~, ~~notifications et widget~~.
