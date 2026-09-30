# 🌍 Petite Planète

Un petit monde vivant dans ta poche. Tu ne le diriges pas : tu l'observes.

Des habitants naissent, travaillent, s'aiment, découvrent le feu, le bronze ou l'écriture, fondent des villages, affrontent des épidémies… et tout continue **même quand l'application est fermée**. Quand tu reviens, le jeu te raconte ce qui s'est passé pendant ton absence. Sur Android, ton téléphone te prévient des grands événements et un widget montre ta planète en direct.

> *« Nilo ramasse une pierre verte dans la montagne près d'Aster. Chauffée dans le feu, elle suinte un métal rouge : le cuivre. »*

Le jeu est fait avec **Godot 4** (dossier [`godot/`](godot)). La première version web en JavaScript est figée dans [`web/`](web).

---

## ✨ Ce que fait le jeu

- **Un monde généré** : plaines, forêts, montagnes, déserts, marais, rivières, lacs et océans, avec des gisements (cuivre, étain, fer, charbon, obsidienne, argile) répartis différemment dans chaque monde.
- **Une vie quotidienne visible** : les habitants se lèvent, partent travailler (cueillette, bois, pêche, chasse, champs, forge, garde, soins), rapportent leur récolte, se retrouvent au feu le soir et rentrent dormir. Arbres qui ondulent, eau animée, fumée des cheminées, fenêtres allumées, saisons, rivières gelées, pluie, neige, orages et sons d'ambiance.
- **Des habitants autonomes** : nom, âge, traits, famille, santé, bonheur, métier, amitiés, rivalités et duels, arbre généalogique.
- **Des colonies qui grandissent** : camp → hameau → village → bourg → ville → grande ville, avec migrations et nouvelles colonies.
- **Des découvertes qui ont une cause** : chaque savoir naît d'un déclencheur concret (la foudre, un minerai touché, un tronc qui flotte), d'un besoin (famine, loups, épidémie) et d'un inventeur. 22 savoirs, du feu au voyage spatial.
- **Du savoir fragile** : il se transmet de maître à apprenti, et peut se perdre si son dernier gardien meurt.
- **Des fléaux** : maladies, loups et loups mutants, barbares, pirates, machines rebelles, et une rare **🧟 apocalypse zombie**.
- **Des catastrophes qui changent la carte** : volcans, séismes, crues, météorites, montée des eaux causée par une civilisation industrielle.
- **Une gouvernance** : chefs, conseils, lois, dynasties, révoltes.
- **Des civilisations** : royaumes, empires, républiques… avec territoires visibles, diplomatie, commerce et caravanes, espions, alliances, guerres, conquêtes et indépendances.
- **Des religions** nées d'un orage, d'un deuil… ou de **tes pouvoirs, vus comme des miracles**. Prophètes, pèlerins, temples, religions officielles, guerres saintes et schismes.
- **Une culture** : langues qui dérivent, monuments, personnages célèbres et statues, légendes qui racontent tes interventions.
- **Une fin de partie spatiale** : fusée, exode, et nouvelle planète fondée par l'équipage du vaisseau. Contact extraterrestre et archéologie, très rares.
- **Pour le joueur** : écran « Bon retour », journal, chronique « Le Livre du monde », replay accéléré, succès, graine de monde à partager, et des **pouvoirs** ponctuels (pluie, soleil, végétation, avancer le temps… et réveiller les morts).

## ⏱️ Le temps

| Temps réel | Temps dans le jeu |
|---|---|
| 5 min | 1 jour (2 min 30 de jour, 2 min 30 de nuit) |
| 1 h | 12 jours |
| 1 journée | 288 jours (≈ 10 mois) |
| 1 semaine | ≈ 5 ans et demi |
| 1 mois | 24 ans |
| 1 an | ≈ 292 ans |

Une année de jeu (360 jours) dure 30 h réelles, et une vie d'habitant d'environ 60 ans dure à peu près 2 mois et demi.

Quand l'application est fermée, le monde continue au rythme normal (jusqu'à 30 jours d'absence rattrapés), et ce, même si tu la mets simplement en arrière-plan.

## 🚀 Lancer le jeu

```bash
godot --path godot
```

Ou ouvre `godot/project.godot` dans l'éditeur Godot 4.7 puis F5.

## 📱 Android : APK, notifications et widget

L'export produit `godot/build/PetitePlanete.apk` (Android 7 et plus, ARM64 et x86_64). Il faut OpenJDK 17, le kit Android (platform-tools, build-tools et plateforme 36 : Gradle installe tout seul ce qui manque une fois les licences acceptées) et les modèles d'export Godot 4.7.

Les notifications et le widget utilisent du code Android natif (le plugin `godot/addons/petite_planete_android`). L'export passe donc par la **compilation Gradle**. Il faut installer une fois le modèle de compilation Android :

- dans l'éditeur : **Projet → Installer le modèle de compilation Android…**
- ou en ligne de commande, en même temps que l'export (l'option ne marche qu'avec lui) :

```bash
godot --headless --path godot --install-android-build-template --export-debug "Android" build/PetitePlanete.apk
```

Ensuite, pour les exports suivants :

```bash
godot --headless --path godot --export-debug "Android" build/PetitePlanete.apk
```

La première compilation télécharge Gradle, elle prend quelques minutes. Copie ensuite l'APK sur ton téléphone et installe-le (autoriser les sources inconnues).

### 🔔 Notifications

La simulation est déterministe : quand tu quittes le jeu, il sait déjà ce qui va se passer. Il calcule en avance les 3 prochains jours réels (864 jours de jeu), choisit les grands événements (guerre, épidémie, découverte, apocalypse, fin du monde…) et programme une notification à l'heure exacte où ils arriveront.

- Au plus 6 notifications à l'avance, espacées d'au moins 4 h, et à l'heure pile (alarmes exactes).
- Rien entre 22 h et 8 h : un événement de la nuit est annoncé à 8 h.
- Quand tu rouvres le jeu, les notifications en attente sont annulées.
- Le jeu demande l'autorisation d'envoyer des notifications au premier lancement (Android 13 et plus).

### 🪟 Widget

Appui long sur l'écran d'accueil → **Widgets** → **Petite Planète**. Il affiche le nom du monde, le jour (☀️ ou 🌙), la population et le dernier grand événement, grâce à la même prévision. Il se met à jour toutes les 30 min et à chaque notification. Le toucher ouvre le jeu.

Testé sur un téléphone virtuel Android 15 : autorisation des notifications, notification à l'heure prévue, widget à jour, et écran « Bon retour » avec l'événement annoncé.

### 🧪 Vérifier la prévision sur PC

```bash
godot --headless --path godot -s tests/phone_preview.gd
```

Le script simule un monde, affiche les notifications qui seraient programmées et vérifie que la prévision correspond exactement au vrai déroulement.

## 🎮 Comment jouer

- **Glisser** pour déplacer la caméra, **pincer** ou **molette** pour zoomer.
- **Toucher** un habitant, un village ou une case pour voir ses informations.
- **📜 Journal** : toute l'histoire du monde. Touche un événement pour y aller.
- **✨ Pouvoirs** : intervenir ponctuellement. Chaque action a des conséquences.

## 🗂️ Organisation du code (`godot/`)

| Dossier | Rôle |
|---|---|
| `scripts/sim/` | Simulation : monde, habitants, métiers, savoirs, maladies, civilisations, guerres, religions, catastrophes, journal, sauvegarde |
| `scripts/view/` | Rendu isométrique, habitants animés, villages, météo, jour et nuit, sons |
| `scripts/ui/` | Interface : fiches, journal, chronique, replay, écran de retour |
| `scripts/core/` | Démarrage, hasard à graine, prévision et lien avec le téléphone |
| `addons/petite_planete_android/` | Plugin Android : notifications, widget, et son code Java |
| `tests/` | Bancs d'essai de la simulation et vérification de la prévision |

La simulation est **déterministe** : tout le hasard passe par un générateur à graine, pour que le rattrapage hors ligne et les notifications soient fiables.

## 🛣️ La suite

La feuille de route est dans [ROADMAP.md](ROADMAP.md).
