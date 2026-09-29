export const ANCIENTS_NAME = 'les anciens';

export const DEFAULT_MODS = {
  happiness: 0, eat: 25, hungerEmpty: 5, wood: 1, buildCost: 6, buildChance: 0.1, capacity: 4,
  migrationRadius: 10, migrationChance: 1, crossWater: false, farm: 0, hunt: 1, fish: 0.5,
  outbreak: 1, care: 1, contagion: 1, defense: 1, research: 1, spread: 1, storm: true,
};

const tech = (name, label, de, emoji, requires, boostJob, mods, anyOf = []) => ({ name, label, de, emoji, requires, anyOf, boostJob, mods });
const METALS = ['cuivre', 'metallurgie', 'fer'];

export const TECHS = {
  feu: tech('Feu', 'le feu', 'du feu', '🔥', [], null, { eat: ['mul', 1.2], outbreak: ['mul', 0.8], happiness: ['add', 0.02] }),
  outils: tech('Outils', 'les outils', 'des outils', '🪨', [], 'bâtisseur', { wood: ['mul', 1.5], hunt: ['mul', 1.3], defense: ['mul', 1.2] }),
  peche: tech('Pêche', 'la pêche', 'de la pêche', '🎣', ['outils'], 'pêcheur', { fish: ['set', 1] }),
  radeau: tech('Radeau', 'le radeau', 'du radeau', '🪵', ['outils'], 'pêcheur', { fish: ['mul', 1.3], spread: ['mul', 1.2] }),
  plantes: tech('Plantes médicinales', 'les plantes médicinales', 'des plantes médicinales', '🌱', ['feu'], 'cueilleur', { care: ['mul', 0.85] }),
  agriculture: tech('Agriculture', 'l\'agriculture', 'de l\'agriculture', '🌾', ['outils'], 'cueilleur', { farm: ['set', 1] }),
  poterie: tech('Poterie', 'la poterie', 'de la poterie', '🏺', ['feu'], null, { hungerEmpty: ['set', 4], outbreak: ['mul', 0.8] }),
  cuivre: tech('Cuivre', 'le cuivre', 'du cuivre', '🟢', ['feu', 'outils'], 'forgeron', { defense: ['mul', 1.2], hunt: ['mul', 1.1], wood: ['mul', 1.1] }),
  metallurgie: tech('Bronze', 'le bronze', 'du bronze', '⚒️', ['cuivre'], 'forgeron', { defense: ['mul', 1.3], buildCost: ['add', -1], hunt: ['mul', 1.2] }),
  fer: tech('Fer', 'le fer', 'du fer', '⛓️', ['feu', 'outils'], 'forgeron', { defense: ['mul', 1.4], wood: ['mul', 1.3], buildCost: ['add', -1] }),
  epee: tech('Épée', 'l\'épée', 'de l\'épée', '🗡️', [], 'gardien', { defense: ['mul', 1.6], hunt: ['mul', 1.2] }, METALS),
  charrue: tech('Charrue', 'la charrue', 'de la charrue', '🌾', ['agriculture'], 'fermier', { farm: ['mul', 1.6] }, METALS),
  roue: tech('Roue', 'la roue', 'de la roue', '☸️', ['outils'], 'bâtisseur', { wood: ['mul', 1.3], farm: ['mul', 1.3], migrationRadius: ['max', 14], spread: ['mul', 1.5] }),
  navigation: tech('Navigation', 'la navigation', 'de la navigation', '⛵', ['radeau'], 'pêcheur', { crossWater: ['set', true], migrationRadius: ['max', 18], fish: ['mul', 1.5], spread: ['mul', 1.5] }),
  ecriture: tech('Écriture', 'l\'écriture', 'de l\'écriture', '📜', ['poterie'], null, { research: ['mul', 1.5], spread: ['mul', 2] }),
  medecine: tech('Médecine', 'la médecine', 'de la médecine', '⚕️', ['ecriture', 'plantes'], 'guérisseur', { outbreak: ['mul', 0.5], care: ['mul', 0.5], contagion: ['mul', 0.6] }),
  architecture: tech('Architecture', 'l\'architecture', 'de l\'architecture', '🏛️', ['ecriture'], 'bâtisseur', { capacity: ['set', 6], buildChance: ['mul', 1.3], storm: ['set', false] }, ['metallurgie', 'fer']),
  lois: tech('Lois', 'les lois', 'des lois', '⚖️', ['ecriture'], 'chef', { happiness: ['add', 0.05], migrationChance: ['mul', 0.5], contagion: ['mul', 0.9], defense: ['mul', 1.2] }),
  machines: tech('Machines', 'les machines', 'des machines', '⚙️', ['fer', 'architecture'], 'forgeron', { wood: ['mul', 2], farm: ['mul', 1.5], buildChance: ['mul', 1.5] }),
  electricite: tech('Électricité', 'l\'électricité', 'de l\'électricité', '💡', ['machines'], 'forgeron', { happiness: ['add', 0.1], outbreak: ['mul', 0.7], research: ['mul', 1.2] }),
  fusee: tech('Fusée', 'la fusée', 'de la fusée', '🚀', ['electricite'], 'forgeron', { research: ['mul', 1.2], happiness: ['add', 0.05] }),
  espace: tech('Voyage spatial', 'le voyage spatial', 'du voyage spatial', '🌌', ['fusee', 'lois'], null, {}),
};

export const TECH_ORDER = [
  'feu', 'outils', 'peche', 'radeau', 'plantes', 'agriculture', 'poterie', 'cuivre', 'metallurgie', 'fer', 'epee', 'charrue',
  'roue', 'navigation', 'ecriture', 'medecine', 'architecture', 'lois', 'machines', 'electricite', 'fusee', 'espace',
];

export function hasTech(s, key) {
  return !!s && Array.isArray(s.techs) && s.techs.includes(key);
}

export function prerequisitesMet(s, key) {
  const t = TECHS[key];
  if (!t || hasTech(s, key)) return false;
  if (!t.requires.every((r) => hasTech(s, r))) return false;
  return !t.anyOf.length || t.anyOf.some((r) => hasTech(s, r));
}

export function techMods(s) {
  const mods = { ...DEFAULT_MODS };
  if (!s || !Array.isArray(s.techs) || !s.techs.length) return mods;
  for (const key of TECH_ORDER) {
    if (s.techs.includes(key)) applyMods(mods, TECHS[key].mods);
  }
  return mods;
}

function applyMods(mods, changes) {
  for (const key in changes) {
    const [op, value] = changes[key];
    if (op === 'mul') mods[key] *= value;
    else if (op === 'add') mods[key] += value;
    else if (op === 'set') mods[key] = value;
    else if (op === 'max') mods[key] = Math.max(mods[key], value);
  }
}
