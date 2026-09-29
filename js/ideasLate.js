const on = (when, spark, story) => ({ when: Array.isArray(when) ? when : [when], spark, story });
const need = (when, mul) => ({ when, mul });

export const IDEAS_LATE = {
  roue: {
    mean: 5000,
    triggers: [
      on('tech:poterie', 1, '☸️ En regardant son tour de potier tourner, {name} a une idée à {place} : la roue.'),
      on('stone', 0.4, '☸️ {name} voit un tronc dévaler la pente près de {place} : la roue.'),
      on('dream', 0.1, '☸️ {name} invente la roue à {place}.'),
    ],
    needs: [need('bigpop', 1.5)],
  },
  navigation: {
    mean: 5000,
    triggers: [
      on('coast', 1, '⛵ {name} dresse une voile sur un grand radeau à {place} : le premier bateau prend la mer.'),
      on('sea', 0.5, '🌊 De retour d\'une longue marche, {name} raconte à {place} la mer sans fin qu\'{il} a vue. On y descend avec un radeau à voile : la navigation est née.'),
    ],
    needs: [need('island', 3), need('crowded', 1.5)],
  },
  ecriture: {
    mean: 45000,
    triggers: [
      on(['lostLore', 'pop30'], 1, '📜 Après la perte d\'un savoir ancien, {name} invente des signes pour ne plus jamais oublier, à {place} : l\'écriture.'),
      on('pop30', 1, '📜 {name} grave des signes dans l\'argile à {place} pour que rien ne s\'oublie : l\'écriture.'),
    ],
    needs: [need('lostLore', 4), need('bigpop', 1.5)],
  },
  medecine: {
    mean: 24000,
    triggers: [
      on('sick', 1, '⚕️ Pendant l\'épidémie, {name} note les remèdes de chaque malade de {place} : la médecine est née.'),
      on('dream', 0.2, '⚕️ {name} fonde la médecine à {place}.'),
    ],
    needs: [],
  },
  architecture: {
    mean: 40000,
    triggers: [
      on('stormDamage', 1, '🏛️ Après que la tempête a détruit des maisons de {place}, {name} dessine des murs plus solides : l\'architecture.'),
      on('bigpop', 0.4, '🏛️ {name} dessine les premiers grands bâtiments de {place}.'),
      on('dream', 0.1, '🏛️ {name} invente l\'architecture à {place}.'),
    ],
    needs: [],
  },
  lois: {
    mean: 40000,
    triggers: [
      on('council', 1, '⚖️ Le conseil de {place} demande à {name} de graver les premières lois.'),
      on('chef', 0.6, '⚖️ {name} établit les premières lois de {place}.'),
    ],
    needs: [need('bigpop', 1.5), need('crowded', 1.3)],
  },
  machines: {
    mean: 50000,
    triggers: [
      on('charbon', 1, '⚙️ {name} fait bouillir de l\'eau sur un feu de charbon à {place} : la vapeur met en marche la première machine.'),
      on('trade:charbon', 0.5, '⚙️ Avec du charbon venu d\'ailleurs, {name} met en marche la première machine à {place}.'),
      on('forest', 0.2, '⚙️ {name} met en marche une machine à vapeur au bois à {place}.'),
    ],
    needs: [],
  },
  electricite: {
    mean: 40000,
    triggers: [
      on('storm', 1, '💡 Pendant l\'orage, {name} capture la foudre dans un fil de métal à {place} : l\'électricité. Les nuits s\'illuminent.'),
      on('dream', 0.3, '💡 {name} apprivoise l\'électricité à {place}. Les nuits s\'illuminent.'),
    ],
    needs: [],
  },
  fusee: {
    mean: 30000,
    triggers: [on('dream', 1, '🚀 {name} lève les yeux vers les étoiles et construit la première fusée à {place}. Tous les regards se tournent vers le ciel.')],
    needs: [need('crowded', 1.5)],
  },
  espace: {
    mean: 20000,
    triggers: [on('dream', 1, '🌌 {name} maîtrise le voyage spatial à {place}. Le grand départ est prévu dans 60 jours.')],
    needs: [],
  },
};
