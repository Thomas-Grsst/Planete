import { toName } from './faithData.js';
import { logEvent, ofPlace } from './events.js';
import { ageOf, ADULT_AGE } from './people.js';
import { hasTech } from './techTree.js';
import { sameLandmass } from './regions.js';
import { civById } from './civs.js';
import { religionOf, adoptFaith } from './religions.js';

const SPREAD_CHANCE = 0.004;
const MIN_POP = 8;
const MIN_DEVOTION = 25;
const LAND_RANGE = 14;
const SEA_RANGE = 22;
const CONVERT_DEVOTION = 30;
const BASE_ODDS = 0.6;
const TEMPLE_RESIST = 1.5;
const STATE_FAITH_BONUS = 2;
const FOREIGN_FACTOR = 0.5;
const MAX_ODDS = 0.95;
const HOLY_RESIST = 0.25;
const RECENT_CONVERT_DAYS = 720;
const RECENT_CONVERT_RESIST = 0.3;

const manhattan = (a, b) => Math.abs(a.x - b.x) + Math.abs(a.y - b.y);

function pickTarget(state, rng, s, rel) {
  const sailors = hasTech(s, 'navigation');
  const range = sailors ? SEA_RANGE : LAND_RANGE;
  const options = state.settlements.filter((o) => o !== s && !o.abandoned && o.faithId !== rel.id && manhattan(s, o) <= range
    && (sailors || sameLandmass(state.world, s.x, s.y, o.x, o.y)));
  return options.length ? rng.pick(options) : null;
}

function missionaryOf(state, rng, entry) {
  const adults = entry.people.filter((p) => p.alive && ageOf(state, p) >= ADULT_AGE);
  const eager = adults.filter((p) => p.traits.includes('sociable') || p.traits.includes('aventurier'));
  if (eager.length) return rng.pick(eager);
  return adults.length ? rng.pick(adults) : null;
}

function persuades(state, rng, s, target, rel) {
  let odds = BASE_ODDS;
  const old = religionOf(state, target);
  if (old) odds *= s.devotion / (s.devotion + target.devotion * (target.temple ? TEMPLE_RESIST : 1));
  if (old && old.holyId === target.id) odds *= HOLY_RESIST;
  if (state.day - (target.convertedDay ?? -99999) < RECENT_CONVERT_DAYS) odds *= RECENT_CONVERT_RESIST;
  const civ = civById(state, target.civId);
  if (civ && civ.religionId === rel.id) odds *= STATE_FAITH_BONUS;
  else if (civ && civ.religionId != null) odds *= FOREIGN_FACTOR;
  if (s.civId == null || s.civId !== target.civId) odds *= FOREIGN_FACTOR;
  return rng.chance(Math.min(MAX_ODDS, odds));
}

export function spreadFaith(state, rng, s, entry, rel) {
  if (entry.pop < MIN_POP || s.devotion < MIN_DEVOTION) return;
  if (!rng.chance(SPREAD_CHANCE * (s.devotion / 100) * (1 + 0.5 * (s.temple || 0)))) return;
  const target = pickTarget(state, rng, s, rel);
  if (!target || !persuades(state, rng, s, target, rel)) return;
  const missionary = missionaryOf(state, rng, entry);
  const old = religionOf(state, target);
  adoptFaith(target, rel, CONVERT_DEVOTION);
  target.convertedDay = state.day;
  const who = missionary
    ? `${missionary.sex === 'F' ? 'Venue' : 'Venu'} ${ofPlace(s.name)}, ${missionary.name} convertit ${target.name}`
    : `Des pèlerins ${ofPlace(s.name)} convertissent ${target.name}`;
  logEvent(state, 'conversion', `🕯️ ${who} ${toName(rel.name)}${old ? `, qui abandonne ${old.name}` : ''}.`, { x: target.x, y: target.y, personId: missionary ? missionary.id : undefined });
}
