export const RARE = new Set(['catastrophe', 'fondation', 'grande_famine', 'disparition',
  'decouverte', 'epidemie', 'apocalypse', 'apocalypse_fin', 'extinction', 'chef', 'conseil', 'exode', 'savoir_perdu',
  'civilisation', 'guerre', 'conquete', 'paix', 'alliance', 'independance', 'chute', 'religion', 'schisme', 'miracle', 'religion_fin']);

export const PRIORITY = {
  exode: 100, extinction: 95, apocalypse: 90, apocalypse_fin: 85, chute: 80, guerre: 70, conquete: 65, civilisation: 62,
  decouverte: 60, paix: 55, independance: 55, alliance: 45, bataille: 42, epidemie: 50, epidemie_fin: 45,
  miracle: 64, religion: 58, schisme: 56, religion_etat: 50, religion_fin: 40,
  zombie: 40, savoir_perdu: 35, temple: 22, chef: 30, conseil: 30, disparition: 25, fondation: 20, catastrophe: 20, grande_famine: 20, croissance: 20,
};

const MAX_HIGHLIGHTS = 8;
const JOURNAL_CAP = 2000;
const HISTORY_CAP = 40;

const priorityOf = (entry) => PRIORITY[entry.type] || 10;

export const plural = (n, word) => `${n} ${word}${n > 1 ? 's' : ''}`;

export const ofPlace = (name) => (/^[AEIOUYÉÈÊÀÂÎÔÛ]/i.test(name) ? `d'${name}` : `de ${name}`);

function pushJournal(state, entry) {
  state.journalSeq = (state.journalSeq || 0) + 1;
  entry.seq = state.journalSeq;
  state.journal.push(entry);
  if (state.journal.length > JOURNAL_CAP) state.journal.splice(0, state.journal.length - JOURNAL_CAP);
}

function pushHistory(state, p, text) {
  p.history.push({ day: state.day, text });
  if (p.history.length > HISTORY_CAP) p.history.shift();
}

function pushHighlight(state, entry) {
  const list = state.pendingHighlights;
  list.push(entry);
  if (list.length <= MAX_HIGHLIGHTS) return;
  let weakest = 0;
  for (let i = 1; i < list.length; i++) if (priorityOf(list[i]) < priorityOf(list[weakest])) weakest = i;
  list.splice(weakest, 1);
}

function countOnly(state, type, n = 1) {
  state.pendingSummary[type] = (state.pendingSummary[type] || 0) + n;
}

export function logEvent(state, type, text, extra = {}) {
  const entry = { day: state.day, type, text, ...extra };
  pushJournal(state, entry);
  if (extra.personId) {
    const p = state.people.find((x) => x.id === extra.personId);
    if (p) pushHistory(state, p, text);
  }
  countOnly(state, type);
  if (RARE.has(type) || extra.highlight === true) pushHighlight(state, entry);
  return entry;
}

export function logPersonal(state, p, type, text, extra = {}) {
  pushHistory(state, p, text);
  countOnly(state, type);
  if (!state.followed.includes(p.id)) return null;
  const entry = { day: state.day, type, text, ...extra, personId: p.id };
  pushJournal(state, entry);
  return entry;
}

export function formatDay(day) {
  const year = Math.floor(day / 360) + 1;
  const d = (day % 360) + 1;
  return `An ${year}, jour ${d}`;
}

export const SUMMARY_LABELS = {
  naissance: ['👶', 'naissance', 'naissances'],
  deces: ['💀', 'décès', 'décès'],
  construction: ['🏠', 'bâtiment construit', 'bâtiments construits'],
  couple: ['💞', 'couple formé', 'couples formés'],
  migration: ['🧭', 'migration', 'migrations'],
  fondation: ['🏕️', 'colonie fondée', 'colonies fondées'],
  croissance: ['📈', 'colonie qui grandit', 'colonies qui grandissent'],
  catastrophe: ['🔥', 'catastrophe', 'catastrophes'],
  animaux: ['🐾', 'événement animal', 'événements animaux'],
  famine: ['🍽️', 'famine', 'famines'],
  meteo: ['🌦️', 'changement de temps', 'changements de temps'],
  disparition: ['🏚️', 'colonie abandonnée', 'colonies abandonnées'],
  decouverte: ['💡', 'découverte', 'découvertes'],
  decouverte_locale: ['🔁', 'redécouverte', 'redécouvertes'],
  diffusion: ['🧳', 'savoir transmis', 'savoirs transmis'],
  savoir_perdu: ['🕯️', 'savoir perdu', 'savoirs perdus'],
  apprentissage: ['📖', 'apprentissage', 'apprentissages'],
  metier: ['🔨', 'changement de métier', 'changements de métier'],
  chasse: ['🏹', 'alerte de chasse', 'alertes de chasse'],
  epidemie: ['🦠', 'épidémie déclarée', 'épidémies déclarées'],
  maladie: ['🤒', 'habitant tombé malade', 'habitants tombés malades'],
  guerison: ['🌿', 'guérison', 'guérisons'],
  epidemie_fin: ['🕯️', 'épidémie terminée', 'épidémies terminées'],
  apocalypse: ['🧟', 'apocalypse zombie', 'apocalypses zombies'],
  zombie: ['🧟', 'événement zombie', 'événements zombies'],
  apocalypse_fin: ['🕊️', 'apocalypse terminée', 'apocalypses terminées'],
  extinction: ['🪦', 'extinction', 'extinctions'],
  attaque: ['🐺', 'attaque de loups', 'attaques de loups'],
  chef: ['👑', 'chef', 'chefs'],
  conseil: ['🏛️', 'conseil formé', 'conseils formés'],
  exode: ['🚀', 'départ vers les étoiles', 'départs vers les étoiles'],
  civilisation: ['🏰', 'civilisation fondée', 'civilisations fondées'],
  ralliement: ['🏳️', 'colonie ralliée', 'colonies ralliées'],
  guerre: ['⚔️', 'guerre déclarée', 'guerres déclarées'],
  bataille: ['🗡️', 'bataille', 'batailles'],
  conquete: ['🏴', 'conquête', 'conquêtes'],
  paix: ['🕊️', 'paix signée', 'paix signées'],
  commerce: ['🐪', 'route commerciale', 'routes commerciales'],
  alliance: ['🤝', 'alliance', 'alliances'],
  rupture: ['💔', 'rupture', 'ruptures'],
  independance: ['✊', 'indépendance', 'indépendances'],
  chute: ['🏚️', 'civilisation disparue', 'civilisations disparues'],
  religion: ['🙏', 'religion fondée', 'religions fondées'],
  miracle: ['✨', 'prière exaucée', 'prières exaucées'],
  schisme: ['⚡', 'schisme', 'schismes'],
  religion_etat: ['👑', 'religion officielle', 'religions officielles'],
  religion_fin: ['🕯️', 'religion éteinte', 'religions éteintes'],
  conversion: ['🕯️', 'conversion', 'conversions'],
  temple: ['🛕', 'temple élevé', 'temples élevés'],
  priere: ['🙏', 'prière', 'prières'],
  legende: ['📖', 'légende', 'légendes'],
};
