const on = (when, spark, story) => ({ when: Array.isArray(when) ? when : [when], spark, story });
const need = (when, mul) => ({ when, mul });

export const IDEAS_EARLY = {
  feu: {
    mean: 10,
    triggers: [
      on('lightning', 1, '⚡ La foudre frappe un arbre près de {place}. {name} ose approcher des flammes et rapporte une braise : le feu est à eux.'),
      on('drought', 0.6, '🔥 Un feu de brousse gronde près de {place}. {name} garde une branche enflammée : le feu ne s\'éteindra plus.'),
      on('stone', 0.08, '🪨 En frappant deux pierres, {name} fait jaillir une étincelle à {place}. Le feu est né.'),
      on('dream', 0.03, '🪵 À force de frotter deux bâtons, {name} fait naître une flamme à {place}.'),
    ],
    needs: [need('winter', 2)],
  },
  outils: {
    mean: 60,
    triggers: [
      on('obsidienne', 1.5, '🔷 {name} trouve un verre noir tranchant près de {place} : les premières lames d\'obsidienne.'),
      on('stone', 1, '🪨 {name} taille un silex contre un rocher près de {place} : les premiers outils.'),
      on('bone', 0.5, '🦴 Après une chasse, {name} façonne des outils avec les os du gibier à {place}.'),
      on('dream', 0.05, '🪨 {name} apprend à tailler la pierre à {place}.'),
    ],
    needs: [],
  },
  peche: {
    mean: 120,
    triggers: [on('water', 1, '🎣 {name} observe les poissons près de {place} et tresse le premier filet.')],
    needs: [need('hunger', 2)],
  },
  radeau: {
    mean: 400,
    triggers: [
      on('river', 1, '🪵 {name} voit un tronc flotter sur la rivière près de {place}. Quelques troncs liés plus tard, le premier radeau glisse sur l\'eau.'),
      on('water', 0.4, '🪵 {name} assemble le premier radeau à {place}.'),
    ],
    needs: [need('island', 2), need('hunger', 1.3)],
  },
  plantes: {
    mean: 400,
    triggers: [
      on(['sick', 'forest'], 1, '🌱 Pendant l\'épidémie, {name} remarque que certaines feuilles apaisent les malades de {place}.'),
      on(['sick', 'swamp'], 1, '🌱 Pendant l\'épidémie, {name} soigne les malades de {place} avec des herbes du marais.'),
      on('swamp', 0.2, '🌱 {name} découvre les herbes qui soignent dans le marais près de {place}.'),
      on('forest', 0.15, '🌱 {name} découvre les plantes qui soignent dans la forêt près de {place}.'),
    ],
    needs: [],
  },
  agriculture: {
    mean: 1200,
    triggers: [
      on('fertile', 1, '🌾 {name} remarque que des graines tombées près du camp de {place} ont germé. {Il} en sème d\'autres : l\'agriculture est née.'),
      on('river', 0.7, '🌾 Sur les berges fertiles près de {place}, {name} plante les premières graines : l\'agriculture est née.'),
      on('dream', 0.2, '🌾 {name} invente l\'agriculture à {place}.'),
    ],
    needs: [need('hunger', 3), need('bigpop', 1.5)],
  },
  poterie: {
    mean: 600,
    triggers: [
      on('argile', 1, '🏺 {name} façonne la terre grasse près de {place} et la cuit dans le feu : les premières poteries.'),
      on('dream', 0.05, '🏺 {name} façonne les premières poteries à {place}.'),
    ],
    needs: [need('tech:agriculture', 2)],
  },
  cuivre: {
    mean: 150,
    triggers: [
      on('cuivre', 1, '🟢 {name} ramasse une pierre verte dans la montagne près de {place}. Chauffée dans le feu, elle suinte un métal rouge : le cuivre.'),
      on('trade:cuivre', 0.3, '🟢 Des voyageurs montrent à {name} une pierre verte qui fond au feu : le cuivre arrive à {place}.'),
    ],
    needs: [],
  },
  metallurgie: {
    mean: 1000,
    triggers: [
      on('etain', 1, '⚒️ {name} mêle le cuivre à un métal gris et mou trouvé près de {place} : le bronze, plus dur que tout.'),
      on('trade:etain', 0.4, '⚒️ Grâce à un métal gris venu d\'ailleurs, {name} invente le bronze à {place}.'),
    ],
    needs: [need('wolves', 1.5), need('zombies', 2)],
  },
  fer: {
    mean: 3000,
    triggers: [
      on('fer', 1, '⛓️ {name} chauffe une roche rouge et lourde plus fort que jamais à {place} : le fer.'),
      on('trade:fer', 0.3, '⛓️ Avec une roche rouge rapportée par des voyageurs, {name} obtient le fer à {place}.'),
      on('dream', 0.03, '☄️ Une pierre tombe du ciel près de {place}. {name} en tire un métal inconnu : le fer.'),
    ],
    needs: [need('tech:metallurgie', 3), need('charbon', 1.5)],
  },
  epee: {
    mean: 200,
    triggers: [
      on('zombies', 2, '🗡️ Face aux morts qui marchent, {name} forge la première épée à {place}.'),
      on('wolves', 1, '🗡️ Après une attaque de loups, {name} forge la première lame à {place}.'),
      on('dream', 0.05, '🗡️ {name} forge la première épée à {place}.'),
    ],
    needs: [],
  },
  charrue: {
    mean: 800,
    triggers: [
      on('hunger', 1, '🌾 La faim pousse {name} à fixer du métal à un soc de bois : la première charrue retourne la terre de {place}.'),
      on('bigpop', 0.5, '🌾 Pour nourrir tout {place}, {name} invente la charrue.'),
      on('dream', 0.1, '🌾 {name} invente la charrue à {place}.'),
    ],
    needs: [],
  },
};
