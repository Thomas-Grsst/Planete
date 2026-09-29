import { spawnHorde, nearestTarget, moveHorde, rotHorde, attackSettlement, biteWanderers, turnIntoZombie, mergeHordes, HORDE_CAP } from './hordes.js';
import { logEvent, logPersonal, plural } from './events.js';
import { killPerson, randomWalkableNear } from './people.js';
import { sameLandmass } from './regions.js';
import { DISEASES } from './diseaseTable.js';

const TIMEOUT_DAYS = 400;
const BITE_INCUBATION_DAYS = 3;
const BITE_DAMAGE = 20;
const TURN_CHANCE = 0.25;
const CURE_CHANCE = 0.3;
const POWER_HORDE_MIN = 10;
const POWER_HORDE_SHARE = 0.35;
const MUTATION_HORDE_BASE = 6;
const SPAWN_MIN_DISTANCE = 6;
const SPAWN_MAX_DISTANCE = 10;
const SPAWN_TRIES = 30;

const manhattan = (ax, ay, bx, by) => Math.abs(ax - bx) + Math.abs(ay - by);

export function defaultZombies() {
  return { active: false, startDay: null, hordes: [], dead: 0, fallen: [], fled: [], lastEndDay: -99999, count: 0, timedOut: false };
}

export function ensureZombiesState(state) {
  const defaults = defaultZombies();
  state.zombies ??= {};
  for (const key of Object.keys(defaults)) state.zombies[key] ??= defaults[key];
  for (const h of state.zombies.hordes) { h.targetId ??= null; h.metIds ??= []; }
  state.apocalypseRequest ??= null;
  for (const p of state.people) if (p.alive) p.bitten ??= null;
  for (const s of state.settlements) s.fallen ??= null;
}

function hordeSpawnSpot(state, rng, s) {
  for (let tries = 0; tries < SPAWN_TRIES; tries++) {
    const spot = randomWalkableNear(state.world, rng, s.x, s.y, SPAWN_MAX_DISTANCE);
    const d = manhattan(spot.x, spot.y, s.x, s.y);
    if (d >= SPAWN_MIN_DISTANCE && sameLandmass(state.world, s.x, s.y, spot.x, spot.y)) return spot;
  }
  return randomWalkableNear(state.world, rng, s.x, s.y, SPAWN_MIN_DISTANCE);
}

export function startApocalypse(state, rng, s, cause, diseaseKey) {
  const z = state.zombies;
  if (z.active || !s) return false;
  const residents = state.people.filter((p) => p.alive && p.homeId === s.id);
  if (!residents.length) return false;
  const p0 = rng.pick(residents);
  const outbreakDeaths = s.outbreak ? s.outbreak.deaths : 0;
  const hordeSize = cause === 'mutation'
    ? Math.min(HORDE_CAP, MUTATION_HORDE_BASE + outbreakDeaths)
    : Math.max(POWER_HORDE_MIN, Math.round(POWER_HORDE_SHARE * residents.length));
  Object.assign(z, defaultZombies(), { active: true, startDay: state.day, dead: 1, lastEndDay: z.lastEndDay, count: z.count });
  killPerson(state, p0, 'et se relève d\'entre les morts');
  const spot = hordeSpawnSpot(state, rng, s);
  spawnHorde(state, spot.x, spot.y, hordeSize);
  const disease = cause === 'mutation' && diseaseKey ? DISEASES[diseaseKey] : null;
  const text = disease
    ? `🧟 À ${s.name}, les morts ${disease.de} se relèvent. L'apocalypse zombie commence.`
    : `🧟 Un frisson parcourt ${s.name} : ${p0.name} se relève d'entre les morts. L'apocalypse zombie commence.`;
  logEvent(state, 'apocalypse', text, { x: s.x, y: s.y });
  return true;
}

export function stepZombies(state, rng, census) {
  consumeRequest(state, rng);
  const z = state.zombies;
  if (!z.active) return;
  stepBitten(state, rng, census, z);
  stepHordes(state, rng, census, z);
  biteWanderers(state, rng);
  mergeHordes(state);
  markFallen(state, census, z);
  if (state.day - z.startDay >= TIMEOUT_DAYS && z.hordes.length) {
    z.hordes = [];
    if (!z.timedOut) logEvent(state, 'zombie', '🧟 Les derniers zombies s\'effondrent, rongés par le temps.', {});
    z.timedOut = true;
  }
  if (z.hordes.length) return;
  const { survivors, bitten } = countLiving(state);
  if (!bitten) endApocalypse(state, z, survivors);
}

function consumeRequest(state, rng) {
  const req = state.apocalypseRequest;
  if (!req) return;
  state.apocalypseRequest = null;
  const s = state.settlements.find((x) => x.id === req.settlementId);
  if (s) startApocalypse(state, rng, s, req.cause || 'mutation', req.diseaseKey);
}

function stepBitten(state, rng, census, z) {
  for (const p of state.people) {
    if (!p.alive || p.bitten == null) continue;
    const entry = census.get(p.homeId);
    const home = entry ? entry.s : null;
    const cared = !!home && Array.isArray(home.techs) && home.techs.includes('medecine') && (entry.jobs['guérisseur'] || 0) > 0;
    if (state.day - p.bitten >= BITE_INCUBATION_DAYS && cared && rng.chance(CURE_CHANCE)) { surviveBite(state, p); continue; }
    p.health -= BITE_DAMAGE;
    if (p.health <= 0 || rng.chance(TURN_CHANCE)) {
      killPerson(state, p, 'des suites d\'une morsure');
      z.dead += 1;
      turnIntoZombie(state, p);
    }
  }
}

function surviveBite(state, p) {
  p.bitten = null;
  p.immune ??= [];
  if (!p.immune.includes('morsure')) p.immune.push('morsure');
  logPersonal(state, p, 'guerison', `🌿 ${p.name} survit à sa morsure.`, { x: p.x, y: p.y });
}

function stepHordes(state, rng, census, z) {
  for (const h of z.hordes.slice()) {
    const target = nearestTarget(state, census, h);
    moveHorde(state, rng, h, target);
    rotHorde(state, h);
    if (!target || manhattan(h.x, h.y, target.x, target.y) > 1) continue;
    const entry = census.get(target.id);
    if (entry) attackSettlement(state, rng, h, target, entry, census);
  }
}

function markFallen(state, census, z) {
  for (const s of state.settlements) {
    if (s.fallen || s.abandoned) continue;
    const entry = census.get(s.id);
    if (!entry || entry.pop === 0 || entry.people.some((p) => p.alive)) continue;
    s.fallen = state.day;
    z.fallen.push(s.name);
    logEvent(state, 'zombie', `🏚️ ${s.name} est tombé. Il n'y a plus personne.`, { x: s.x, y: s.y, highlight: true });
  }
}

function countLiving(state) {
  let survivors = 0;
  let bitten = 0;
  for (const p of state.people) {
    if (!p.alive) continue;
    survivors += 1;
    if (p.bitten != null) bitten += 1;
  }
  return { survivors, bitten };
}

function endApocalypse(state, z, survivors) {
  z.active = false;
  z.lastEndDay = state.day;
  z.count += 1;
  const lost = z.fallen.length ? `, ${z.fallen.join(', ')} perdu${z.fallen.length > 1 ? 's' : ''}` : '';
  const days = state.day - z.startDay;
  const duration = days > 0 ? plural(days, 'jour') : 'moins d\'un jour';
  logEvent(state, 'apocalypse_fin', `🕊️ L'apocalypse zombie prend fin après ${duration} : ${plural(survivors, 'survivant')}, ${plural(z.dead, 'mort')}${lost}.`, {});
}
