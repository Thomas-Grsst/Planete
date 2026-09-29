import { TECHS, prerequisitesMet, hasTech } from './techTree.js';
import { logEvent, plural, ofPlace } from './events.js';
import { ageOf, ADULT_AGE } from './people.js';
import { scanContacts } from './context.js';
import { stepInspiration } from './inspiration.js';
import { stepLore, teach, rootIfWritten, ensureLoreState } from './lore.js';

const MIN_RESEARCH_POP = 3;
const SPREAD_RANGE = 14;
const SPREAD_BASE_CHANCE = 0.004;
const SPREAD_MAX_CHANCE = 0.5;
const BOAT_SPREAD_BONUS = 1.5;
const EXODUS_DELAY = 60;
const HISTORY_CAP = 40;

const manhattan = (ax, ay, bx, by) => Math.abs(ax - bx) + Math.abs(ay - by);
const agree = (n, singular, pluralForm) => (n > 1 ? pluralForm : singular);

function ensureSettlementTech(s) {
  s.techs ??= [];
  s.research ??= {};
  s.techDays ??= {};
  s.departed ??= null;
}

export function ensureTechnologyState(state) {
  state.discoveries ??= {};
  state.exodus ??= null;
  state.ended ??= null;
  state.endingShown ??= false;
  for (const s of state.settlements) ensureSettlementTech(s);
  ensureLoreState(state);
}

const techsOf = (s) => (s && Array.isArray(s.techs) ? s.techs : []);

function activeNeighbours(state, census, s) {
  const out = [];
  for (const a of state.settlements) {
    if (a === s || a.abandoned || manhattan(a.x, a.y, s.x, s.y) > SPREAD_RANGE) continue;
    const ea = census.get(a.id);
    if (ea && ea.pop > 0) out.push(a);
  }
  return out;
}

function spreadFactor(census, a, s) {
  const ea = census.get(a.id);
  const spread = ea && ea.mods ? ea.mods.spread : 1;
  const byBoat = a.geo && a.geo.coast && s.geo && s.geo.coast && hasTech(a, 'navigation');
  return spread * (byBoat ? BOAT_SPREAD_BONUS : 1);
}

function stepSpread(state, rng, census, s, entry) {
  const neighbours = activeNeighbours(state, census, s);
  if (!neighbours.length) return;
  const pool = [];
  let best = 0;
  for (const a of neighbours) {
    for (const k of techsOf(a)) if (!pool.includes(k) && prerequisitesMet(s, k)) pool.push(k);
    best = Math.max(best, spreadFactor(census, a, s));
  }
  if (!pool.length || !rng.chance(Math.min(SPREAD_MAX_CHANCE, SPREAD_BASE_CHANCE * pool.length * best))) return;
  const key = rng.pick(pool);
  const source = neighbours.find((a) => hasTech(a, key));
  const adults = entry.people.filter((p) => p.alive && ageOf(state, p) >= ADULT_AGE);
  const learner = adults.length ? rng.pick(adults) : null;
  grantTech(state, rng, s, key, null, source, null, learner);
}

export function stepTechnology(state, rng, census) {
  stepLore(state, rng, census);
  scanContacts(state, rng, census);
  stepInspiration(state, rng, census, grantTech);
  const active = state.settlements.filter((s) => !s.abandoned && census.has(s.id) && census.get(s.id).pop >= MIN_RESEARCH_POP);
  for (const s of active) stepSpread(state, rng, census, s, census.get(s.id));
}

export function grantTech(state, rng, s, key, discoverer, source, story = null, learner = null) {
  if (s.techs.includes(key)) return;
  s.techs.push(key);
  s.techDays[key] = state.day;
  const keeper = discoverer || learner;
  if (keeper) teach(keeper, key);
  else if (!s.rooted.includes(key)) s.rooted.push(key);
  rootIfWritten(s, key);
  const t = TECHS[key];
  const first = !state.discoveries[key];
  const extra = { x: s.x, y: s.y };
  if (discoverer) {
    extra.personId = discoverer.id;
    if (first) state.discoveries[key] = { day: state.day, personId: discoverer.id, personName: discoverer.name, settlementId: s.id, settlementName: s.name };
    const text = story || `${t.emoji} ${discoverer.name} découvre ${t.label} à ${s.name}.`;
    logEvent(state, first ? 'decouverte' : 'decouverte_locale', first ? text : `🔁 ${text}`, extra);
  }
  if (source) {
    const who = learner ? ` à ${learner.name}` : '';
    logEvent(state, 'diffusion', `🧳 Un voyageur venu ${ofPlace(source.name)} enseigne le secret ${t.de}${who}, à ${s.name}.`, learner ? { ...extra, personId: learner.id } : extra);
  }
  if (key === 'espace' && !state.exodus) state.exodus = { settlementId: s.id, launchDay: state.day + EXODUS_DELAY, done: false };
}
function departureSentence(names, n) {
  if (n === 1) return `${names[0]} s'envole vers les étoiles.`;
  if (n === 2) return `${names[0]} et ${names[1]} s'envolent vers les étoiles.`;
  return `${names[0]}, ${names[1]} et ${plural(n - 2, 'autre')} s'envolent vers les étoiles.`;
}

function departPeople(state, departingIds, names) {
  const departedIds = new Set();
  let remaining = 0;
  for (const p of state.people) {
    if (!p.alive) continue;
    if (!departingIds.has(p.homeId)) { remaining += 1; continue; }
    p.alive = false;
    p.departed = true;
    p.deathDay = state.day;
    p.history.push({ day: state.day, text: 'S\'envole vers les étoiles.' });
    if (p.history.length > HISTORY_CAP) p.history.shift();
    if (names.length < 2) names.push(p.name);
    departedIds.add(p.id);
  }
  for (const p of state.people) if (p.alive && departedIds.has(p.partnerId)) p.partnerId = null;
  return { departed: departedIds.size, remaining };
}

export function stepExodus(state) {
  const exodus = state.exodus;
  if (!exodus || exodus.done || state.day < exodus.launchDay) return;
  const departing = state.settlements.filter((s) => !s.abandoned && hasTech(s, 'espace'));
  const names = [];
  const { departed, remaining } = departPeople(state, new Set(departing.map((s) => s.id)), names);
  if (!departed) { state.exodus = null; return; }
  for (const s of departing) { s.departed = state.day; s.abandoned = state.day; }
  const origin = departing.find((s) => s.id === exodus.settlementId) || departing[0];
  const launch = `🚀 Le grand départ : ${plural(departed, 'habitant')} ${agree(departed, 'quitte', 'quittent')} la planète depuis ${origin.name}.`;
  logEvent(state, 'exode', `${launch} ${departureSentence(names, departed)}`, { x: origin.x, y: origin.y });
  const after = remaining > 0
    ? `🌍 ${plural(remaining, 'habitant')} ${agree(remaining, 'reste', 'restent')} sur ${state.name} et ${agree(remaining, 'regarde', 'regardent')} le ciel.`
    : '🌍 La planète est désormais silencieuse.';
  logEvent(state, 'exode', after, {});
  state.ended = { day: state.day, departed, remaining };
  exodus.done = true;
}
