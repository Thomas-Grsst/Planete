import { DISEASES, DISEASE_ORDER } from './diseaseTable.js';
import { infect, stepSick, isImmune } from './disease.js';
import { logEvent, plural, ofPlace } from './events.js';
import { hasTech } from './techTree.js';

const BASE_OUTBREAK_CHANCE = 0.0004;
const OUTBREAK_COOLDOWN_DAYS = 180;
const MIN_OUTBREAK_POP = 8;
const MAX_PATIENT_DRAWS = 6;
const SPREAD_CHANCE = 0.004;
const SPREAD_RANGE = 10;
const RECENT_DEATH_WINDOW = 15;
const DEATH_MILESTONES = [5, 10, 20, 50];
const HIGHLIGHT_DEATHS = 5;
const MUTATION = { minDay: 14400, restAfterApocalypse: 7200, minDeaths: 12, minRecentDeaths: 5, minPop: 40, chance: 0.05 };
const SUMMER = 1;
const WINTER = 3;

const capitalize = (text) => text.charAt(0).toUpperCase() + text.slice(1);
const manhattan = (ax, ay, bx, by) => Math.abs(ax - bx) + Math.abs(ay - by);
const seasonOf = (state) => Math.floor((state.day % 360) / 90);
const lastOutbreakOf = (s) => s.lastOutbreakDay ?? -9999;
const swampOf = (s) => (s.geo && s.geo.swamp) || 0;
const knowsFire = (s) => (s.techs || []).includes('feu');

const WEIGHT_FACTORS = {
  toux_rouge: (state, s) => (seasonOf(state) === WINTER || state.weather === 'snow' ? 3 : 1) * (knowsFire(s) ? 0.7 : 1),
  fievre_marais: (state, s) => (swampOf(s) > 0 ? 1 + 0.5 * Math.min(4, swampOf(s)) : 0.3) * (seasonOf(state) === SUMMER ? 2 : 1),
  mal_des_ventres: (state, s, entry) => (state.weather === 'drought' ? 3 : 1) * (entry.hungry > entry.pop / 3 ? 2 : 1),
  peste_grise: (state, s, entry) => entry.density * entry.density,
};

function weightedPick(rng, items, weightOf) {
  const weights = items.map(weightOf);
  const total = weights.reduce((sum, w) => sum + w, 0);
  if (total <= 0) return null;
  let r = rng.next() * total;
  for (let i = 0; i < items.length; i++) {
    if (r < weights[i]) return items[i];
    r -= weights[i];
  }
  return items[items.length - 1];
}

const newOutbreak = (state, key) => ({ key, since: state.day, deaths: 0, recovered: 0, recentDeaths: [], mutationRolled: false });

export function outbreakChance(state, s, entry) {
  if (s.outbreak || s.abandoned || entry.pop < MIN_OUTBREAK_POP) return 0;
  if (state.day - lastOutbreakOf(s) <= OUTBREAK_COOLDOWN_DAYS) return 0;
  return BASE_OUTBREAK_CHANCE * Math.sqrt(entry.pop / 20) * entry.density * entry.mods.outbreak;
}

export function diseaseWeight(state, key, s, entry) {
  const d = DISEASES[key];
  if (!d || entry.pop < d.minPop) return 0;
  const factor = WEIGHT_FACTORS[key];
  return d.weight * (factor ? factor(state, s, entry) : 1);
}

export function startOutbreak(state, rng, s, entry, key, sourceName) {
  const d = DISEASES[key];
  const wanted = 1 + rng.int(0, 2);
  const patients = [];
  for (let draws = 0; draws < MAX_PATIENT_DRAWS && patients.length < wanted; draws++) {
    const p = rng.pick(entry.people);
    if (!p || !p.alive || p.sick || p.bitten != null || isImmune(p, key)) continue;
    infect(state, rng, p, key, s);
    patients.push(p);
  }
  if (!patients.length) return;
  const p0 = patients[0];
  s.outbreak = newOutbreak(state, key);
  const text = sourceName
    ? `${d.emoji} ${capitalize(d.label)} atteint ${s.name} par un voyageur ${ofPlace(sourceName)}.`
    : `${d.emoji} ${capitalize(d.label)} se déclare à ${s.name}. ${p0.name} est ${p0.sex === 'F' ? 'la première touchée' : 'le premier touché'}.`;
  logEvent(state, 'epidemie', text, { x: s.x, y: s.y, personId: p0.id });
}

export function stepEpidemics(state, rng, census) {
  for (const s of state.settlements) {
    if (s.abandoned) { s.outbreak = null; continue; }
    const entry = census.get(s.id);
    if (!entry) continue;
    tryOutbreak(state, rng, s, entry);
    if (!s.outbreak && entry.sick > 0) declareImportedOutbreak(state, s, entry);
    if (s.outbreak) progressOutbreak(state, rng, s, entry, census);
  }
}

function tryOutbreak(state, rng, s, entry) {
  const chance = outbreakChance(state, s, entry);
  if (chance <= 0 || !rng.chance(chance)) return;
  const key = weightedPick(rng, DISEASE_ORDER, (k) => diseaseWeight(state, k, s, entry));
  if (key) startOutbreak(state, rng, s, entry, key, null);
}

function declareImportedOutbreak(state, s, entry) {
  const carrier = entry.people.find((p) => p.alive && p.sick);
  const d = carrier && DISEASES[carrier.sick.key];
  if (!d) return;
  s.outbreak = newOutbreak(state, carrier.sick.key);
  logEvent(state, 'epidemie', `${d.emoji} ${capitalize(d.label)} arrive à ${s.name} avec un voyageur.`, { x: s.x, y: s.y });
}

function progressOutbreak(state, rng, s, entry, census) {
  const o = s.outbreak;
  const d = DISEASES[o.key];
  if (!d) { s.outbreak = null; return; }
  const r = stepSick(state, rng, s, entry);
  const deathsBefore = o.deaths;
  o.deaths += r.deaths;
  o.recovered += r.recovered;
  trackRecentDeaths(state, o, r.deaths);
  if (DEATH_MILESTONES.some((m) => deathsBefore < m && o.deaths >= m)) {
    logEvent(state, 'maladie', `💀 ${capitalize(d.label)} a déjà emporté ${plural(o.deaths, 'habitant')} ${ofPlace(s.name)}.`, { x: s.x, y: s.y });
  }
  if (rng.chance(SPREAD_CHANCE * entry.mods.spread)) spreadFrom(state, rng, s, o.key, census);
  if (canMutate(state, s, entry, o, d)) {
    o.mutationRolled = true;
    if (rng.chance(MUTATION.chance)) state.apocalypseRequest = { settlementId: s.id, cause: 'mutation', diseaseKey: o.key };
  }
  if (r.sick === 0) endOutbreak(state, s, o, d);
}

function trackRecentDeaths(state, o, deaths) {
  for (let i = 0; i < deaths; i++) o.recentDeaths.push(state.day);
  const oldest = state.day - RECENT_DEATH_WINDOW;
  if (o.recentDeaths.length && o.recentDeaths[0] <= oldest) o.recentDeaths = o.recentDeaths.filter((day) => day > oldest);
}

function spreadFrom(state, rng, from, key, census) {
  for (const t of state.settlements) {
    if (t === from || t.abandoned || t.outbreak) continue;
    if (manhattan(from.x, from.y, t.x, t.y) > SPREAD_RANGE) continue;
    if (state.day - lastOutbreakOf(t) <= OUTBREAK_COOLDOWN_DAYS) continue;
    const target = census.get(t.id);
    if (!target || target.pop < MIN_OUTBREAK_POP) continue;
    startOutbreak(state, rng, t, target, key, from.name);
    return;
  }
}

function canMutate(state, s, entry, o, d) {
  const zombies = state.zombies;
  return d.mutates && !o.mutationRolled && !zombies.active && !state.apocalypseRequest && state.day >= MUTATION.minDay
    && state.day - zombies.lastEndDay > MUTATION.restAfterApocalypse && entry.pop >= MUTATION.minPop && !hasTech(s, 'medecine')
    && o.deaths >= MUTATION.minDeaths && o.recentDeaths.length >= MUTATION.minRecentDeaths;
}

function endOutbreak(state, s, o, d) {
  s.lastOutbreakDay = state.day;
  const days = state.day - o.since;
  const text = `🕯️ ${capitalize(d.label)} s'éteint à ${s.name} après ${plural(days, 'jour')} : ${plural(o.deaths, 'mort')}, ${plural(o.recovered, 'guéri')}.`;
  logEvent(state, 'epidemie_fin', text, { x: s.x, y: s.y, highlight: o.deaths >= HIGHLIGHT_DEATHS });
  s.outbreak = null;
}
