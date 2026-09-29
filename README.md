# 🌍 Petite Planète

Un petit monde vivant dans ta poche. Tu ne le diriges pas : tu l'observes.

Des habitants naissent, travaillent, s'aiment, découvrent le feu, le bronze ou l'écriture, fondent des villages, affrontent des épidémies… et tout continue **même quand l'application est fermée**. Quand tu reviens, le jeu te raconte ce qui s'est passé pendant ton absence.

> *« Nilo ramasse une pierre verte dans la montagne près d'Aster. Chauffée dans le feu, elle suinte un métal rouge : le cuivre. »*

---

## ✨ Ce que fait le jeu

- **Un monde généré** : plaines, forêts, montagnes, déserts, marais, rivières, lacs et océans, avec des gisements (cuivre, étain, fer, charbon, obsidienne, argile) répartis différemment dans chaque monde.
- **Des habitants autonomes** : nom, âge, traits (curieux, courageux, inventif…), famille, santé, bonheur, et un métier (cueilleur, fermier, chasseur, pêcheur, bâtisseur, guérisseur, forgeron, gardien, chef).
- **Des colonies qui grandissent** : camp → hameau → village → bourg → ville → grande ville, avec migrations et fondations de nouvelles colonies.
- **Des découvertes qui ont une cause** : chaque savoir naît d'un déclencheur concret (la foudre, un minerai touché, un tronc qui flotte), d'un besoin (famine, loups, épidémie) et d'un inventeur. 22 savoirs, du feu au voyage spatial, en réseau à plusieurs chemins.
- **Du savoir fragile** : il se transmet de maître à apprenti, et peut se perdre si son dernier gardien meurt.
- **Des maladies**, des **loups**, et une rare **🧟 apocalypse zombie**.
- **Une gouvernance** : chefs élus, conseils de sages, lois.
- **Des civilisations** : un village d'au moins 30 habitants avec un chef peut proclamer un royaume, un empire, une république… selon le caractère de son chef. Les colonies voisines s'y rallient, les villes lointaines ou conquises peuvent proclamer leur indépendance.
- **Des territoires** visibles sur la carte, avec les frontières de chaque civilisation.
- **De la diplomatie** : relations qui évoluent (frontières, commerce, caractère des chefs), routes commerciales qui échangent des savoirs, alliances, ruptures.
- **Des guerres** : batailles entre villes frontalières avec leurs héros et leurs morts, conquêtes, paix, chute de civilisations.
- **Des religions** : un orage ou un deuil fait naître le culte de l'Orage ou des Ancêtres… mais **tes pouvoirs sont vus comme des miracles**. Les villages en détresse prient ; si ta pluie répond à leur sécheresse, ils crient au miracle et fondent un culte envers toi (le Faiseur de Pluie, l'Œil d'Or, la Mère Verte… ou le Semeur de Morts). Prophètes, missionnaires, temples, religions officielles qui rapprochent ou opposent les civilisations, guerres saintes et schismes.
- **Des légendes** : chacune de tes interventions entre dans les récits (« la Grande Pluie de l'An 12 »).
- **Le retour du joueur** : un écran « Bon retour » résume tout ce qui s'est passé, avec les événements marquants.
- **Le journal du monde** et la possibilité de **suivre** un habitant ou un village.
- **Des pouvoirs** ponctuels : pluie, soleil, végétation, accélération du temps… et réveiller les morts. Le panneau ✨ montre qui prie, et pour quoi.

## ⏱️ Le temps

| Temps réel | Temps dans le jeu |
|---|---|
| 10 min | 1 jour (5 min de jour, 5 min de nuit) |
| 1 journée | 144 jours |
| 1 mois | ≈ 12 ans |
| 1 an | ≈ 146 ans |

Vitesses disponibles : ⏸ pause, ▶ ×1, ▶▶ ×10, ▶▶▶ ×100.
Quand l'application est fermée, le monde continue au rythme normal (jusqu'à 30 jours d'absence rattrapés).

## 🎮 Version Godot 4 (dossier `godot/`)

La version principale du jeu est désormais faite avec **Godot 4** : un monde qui bouge sous tes yeux, et une vraie app Android.

- **Vie quotidienne visible** : les habitants se lèvent, partent travailler (cueillette, bois, pêche, chasse, champs, forge, garde, soins), rapportent leur récolte, se retrouvent au feu le soir et rentrent dormir. Arbres qui ondulent, eau animée, fumée des cheminées, fenêtres allumées, saisons, rivières gelées, pluie, neige, orages et sons d'ambiance.
- **Toute la simulation de la version web** : 22 savoirs découverts par causes et savoir fragile, maladies, loups, zombies, chefs, conseils, lois, dynasties, révoltes, civilisations, territoires, diplomatie, commerce, guerres, conquêtes, religions nées de tes miracles, temples, schismes.
- **Nouveautés** : catastrophes qui changent la carte (volcans, séismes, crues, météorites, montée des eaux), barbares, pirates, espions, machines rebelles, loups mutants, visiteurs venus d'ailleurs, archéologie, langues qui dérivent, monuments, personnages célèbres et statues, amitiés, rivalités, duels, arbre généalogique, chronique « Le Livre du monde », replay accéléré, succès, graine de monde à partager, et nouvelle planète fondée par l'équipage du vaisseau.

```bash
godot --path godot
```

Ou ouvre `godot/project.godot` dans l'éditeur Godot puis F5.

### 📱 Android

L'export produit `godot/build/PetitePlanete.apk` (Android 7 et plus, ARM64 et x86_64). Il faut OpenJDK 17, le kit Android (build-tools 35.0.1, plateforme 35) et les modèles d'export Godot 4.7.2 :

```bash
godot --headless --path godot --export-debug "Android" build/PetitePlanete.apk
```

Copie l'APK sur ton téléphone et installe-le (autoriser les sources inconnues). La version web ci-dessous reste disponible.

## 🚀 Lancer le jeu

Le jeu est une **PWA** (application web installable) en JavaScript pur : aucune dépendance, aucune compilation.

### En local (Windows)

```bash
powershell -ExecutionPolicy Bypass -File serve.ps1
```

Puis ouvre http://localhost:8080 dans ton navigateur.

N'importe quel serveur de fichiers statiques fonctionne aussi. Il en faut un, car les modules JavaScript ne se chargent pas en ouvrant `index.html` directement.

### Sur téléphone

1. Héberge le dossier sur un site en **HTTPS** (GitHub Pages, Netlify…).
2. Ouvre le site sur ton téléphone.
3. **Android** : menu du navigateur → « Installer l'application ».
   **iPhone** : bouton Partager → « Sur l'écran d'accueil ».

Pas besoin de Play Store ni d'App Store.

## 🎮 Comment jouer

- **Glisser** pour déplacer la caméra, **pincer** ou **molette** pour zoomer.
- **Toucher** un habitant, un village ou une case pour voir ses informations.
- **👁️ Suivre** un habitant ou un village pour garder ses événements dans le journal.
- **📜 Journal** : toute l'histoire du monde. Touche un événement pour y aller.
- **👥** : population, colonies, savoirs découverts, animaux.
- **✨ Pouvoirs** : intervenir ponctuellement. Chaque action a des conséquences.
- **☰** : gérer plusieurs mondes.

## 🗂️ Organisation du code

| Dossier / fichier | Rôle |
|---|---|
| `index.html`, `css/`, `manifest.json`, `sw.js` | Page, style, installation PWA et cache hors ligne |
| `js/main.js` | Démarrage, boucle de jeu, rattrapage du temps |
| `js/simulation.js` | Tick quotidien, météo, catastrophes, rattrapage hors ligne |
| `js/world.js`, `js/resources.js`, `js/regions.js` | Génération du terrain, gisements, masses de terre |
| `js/people.js`, `js/jobs.js`, `js/work.js` | Habitants, métiers et leurs effets |
| `js/settlements.js`, `js/governance.js` | Colonies, migrations, chefs et conseils |
| `js/civs.js`, `js/civFormation.js`, `js/territory.js` | Civilisations, ralliements, indépendances, culture, territoires |
| `js/diplomacy.js`, `js/war.js` | Relations, commerce, alliances, guerres, batailles et conquêtes |
| `js/religions.js`, `js/faith*.js`, `js/miracles.js` | Religions, prières, miracles et légendes, missionnaires, temples, schismes |
| `js/techTree.js`, `js/ideasEarly.js`, `js/ideasLate.js` | Savoirs, leurs effets, déclencheurs et besoins |
| `js/context.js`, `js/inspiration.js`, `js/lore.js`, `js/technology.js` | Ce que voient les habitants, naissance des idées, transmission et perte du savoir |
| `js/disease*.js`, `js/epidemics.js` | Maladies et épidémies |
| `js/zombies.js`, `js/hordes.js`, `js/defense.js`, `js/animals.js` | Zombies, défense, animaux et loups |
| `js/render.js`, `js/decor.js`, `js/daylight.js`, `js/borders.js`, `js/camera.js` | Rendu 2.5D, cycle jour/nuit, frontières, caméra |
| `js/panels*.js`, `js/ui.js`, `js/navigation.js`, `js/events.js` | Interface, fiches, journal, écran de retour |
| `js/save.js`, `js/migrate.js` | Sauvegarde locale et compatibilité des anciennes parties |

La simulation est **déterministe** : tout le hasard passe par un générateur à graine, pour que le rattrapage hors ligne soit fiable.

## 🛣️ La suite

La feuille de route complète est dans [ROADMAP.md](ROADMAP.md). La V3 (civilisations) et les religions sont livrées ; les prochaines idées : personnages célèbres, chronique automatique, commerce visible sur la carte.
