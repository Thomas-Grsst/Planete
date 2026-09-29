export const DISEASES = {
  toux_rouge:      { name: 'Toux rouge',        label: 'la toux rouge',        de: 'de la toux rouge',        emoji: '🤧', contagion: 0.30, lethal: 0.006, dmg: 3, duration: [8, 14],  weight: 1,    minPop: 0,  mutates: false },
  fievre_marais:   { name: 'Fièvre des marais', label: 'la fièvre des marais', de: 'de la fièvre des marais', emoji: '🦟', contagion: 0.22, lethal: 0.012, dmg: 4, duration: [12, 20], weight: 1,    minPop: 0,  mutates: false },
  mal_des_ventres: { name: 'Mal des ventres',   label: 'le mal des ventres',   de: 'du mal des ventres',      emoji: '🤢', contagion: 0.20, lethal: 0.005, dmg: 3, duration: [6, 10],  weight: 1,    minPop: 0,  mutates: false },
  peste_grise:     { name: 'Peste grise',       label: 'la peste grise',       de: 'de la peste grise',       emoji: '🐀', contagion: 0.45, lethal: 0.03,  dmg: 7, duration: [10, 16], weight: 0.35, minPop: 30, mutates: true },
};

export const DISEASE_ORDER = ['toux_rouge', 'fievre_marais', 'mal_des_ventres', 'peste_grise'];
