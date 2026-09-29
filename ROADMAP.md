# Petite Planète — Feuille de route

État actuel : **V3 livrée** : civilisations, territoires, diplomatie et guerres, en plus des métiers, des 22 savoirs découverts par causes, des maladies, de l'apocalypse zombie et du cycle jour/nuit de 10 min.

---

## ⏱️ Rythme du temps (à faire en premier)

- [x] 1 jour de jeu = **10 min réelles** (5 min de jour + 5 min de nuit) → ~146 ans de jeu par an réel.
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

- [ ] La **Navigation** se déclenche rarement : les colonies s'installent peu sur les côtes (dépend de la carte).
- [x] L'écran « Bon retour » affiche toujours les naissances et les décès (jusqu'à 10 catégories).

## 📱 Widget et notifications

- [ ] Impossible en PWA. Voie réaliste : **app Android via Capacitor** (APK installé sans Play Store).
  - Nécessite Node.js + Android Studio sur la machine.
  - Bonus : vraies notifications (« Aster a découvert le bronze »).
- [ ] iPhone : nécessite Mac + Xcode + compte développeur Apple (compliqué hors App Store).

---

## 🌟 Idées pour les versions suivantes

### 🌍 Monde vivant
- [ ] Saisons visibles (neige, arbres roux, rivières gelées).
- [ ] Catastrophes qui changent la carte : volcans, séismes, inondations, météorites.
- [ ] Changement climatique causé par une civilisation industrielle (montée des eaux).

### 👤 Attachement aux habitants
- [ ] Arbre généalogique interactif.
- [ ] Personnages célèbres (inventeur, conquérant, prophète) avec statue.
- [ ] Dynasties au pouvoir sur plusieurs générations.
- [ ] Rivalités et amitiés (duels, alliances, trahisons).

### 🎭 Culture
- [ ] Religions inventées, prophètes, schismes — **tes pouvoirs vus comme des miracles** (un culte envers toi).
- [ ] Langues inventées qui dérivent entre colonies isolées.
- [ ] Monuments visibles de loin (pyramides, temples, observatoires).
- [ ] Légendes qui racontent tes interventions (« Le Grand Déluge de l'An 12 »).

### ⚔️ Après la V3
- [ ] Routes commerciales et caravanes visibles, ports, bateaux marchands.
- [ ] Révolutions contre les chefs impopulaires.
- [ ] Espions, pirates, barbares des terres sauvages.

### 🚀 Fin de partie spatiale
- [ ] Suivre le vaisseau après l'exode et fonder une **nouvelle planète**.
- [ ] Contact extraterrestre (ultra-rare).
- [ ] Archéologie : une civilisation découvre les ruines de la précédente.

### 🧟 Autres fléaux
- [ ] Animaux mutants, nouvelles espèces.
- [ ] IA rebelle chez une civilisation avancée.

### 🎮 Pour le joueur
- [ ] Replay accéléré (1 000 ans en 30 secondes).
- [ ] **Chronique automatique** : « Le Livre de Noria ».
- [ ] Partage de graine de monde entre amis.
- [ ] Succès (« Atteindre l'espace », « Survivre à 3 apocalypses »…).

**Coups de cœur** (renforcent le « qu'est-ce qui s'est passé pendant mon absence ? ») : découvertes par causes, religions liées à tes pouvoirs, personnages célèbres, chronique automatique.
