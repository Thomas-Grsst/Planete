import { isWalkable } from './world.js';
import { killPerson, ageOf, MIGRANT_MIN_AGE } from './people.js';
import { logEvent, logPersonal, plural } from './events.js';
import { defenseStrength } from './defense.js';
import { sameLandmass } from './regions.js';

const MAX_HORDES = 12;
export const HORDE_CAP = 40;

const TARGET_RANGE = 15;
const FLEE_RANGE = 20;
const KILL_PER_DEFENSE = 0.2;
const MAX_KILL_SHARE = 0.4;
const BITE_PER_ZOMBIE = 0.12;
const DEFENSE_BITE_WEIGHT = 0.5;
const DEVOURED_CHANCE = 0.3;

const manhattan = (ax, ay, bx, by) => Math.abs(ax - bx) + Math.abs(ay - by);
const stochasticRound = (rng, x) => Math.floor(x) + (rng.chance(x - Math.floor(x)) ? 1 : 0);
const growHorde = (h) => { h.count = Math.min(HORDE_CAP, h.count + 1); };

export function spawnHorde(state, x, y, count) {
  const h = { id: state.nextId++, x, y, count, targetId: null, metIds: [] };
  state.zombies.hordes.push(h);
  return h;
}

function populatedTest(census) {
  return (s) => (census.get(s.id)?.pop ?? 0) > 0;
}

export function nearestTarget(state, census, h) {
  const populated = populatedTest(census);
  const canTarget = (s) => !s.abandoned && !s.fallen && populated(s)
    && manhattan(h.x, h.y, s.x, s.y) <= TARGET_RANGE && sameLandmass(state.world, h.x, h.y, s.x, s.y);
  const kept = h.targetId == null ? null : state.settlements.find((s) => s.id === h.targetId);
  if (kept && state.day % 5 !== 0 && canTarget(kept)) return kept;
  let best = null;
  let bestDist = Infinity;
  for (const s of state.settlements) {
    if (!canTarget(s)) continue;
    const d = manhattan(h.x, h.y, s.x, s.y);
    if (d < bestDist) { bestDist = d; best = s; }
  }
  h.targetId = best ? best.id : null;
  return best;
}

export function moveHorde(state, rng, h, target) {
  if (state.weather === 'snow' || (!target && !rng.chance(0.5))) return;
  const steps = target ? chaseSteps(h, target) : [[rng.int(-1, 1), rng.int(-1, 1)]];
  for (const [sx, sy] of steps) {
    if ((sx || sy) && isWalkable(state.world, h.x + sx, h.y + sy)) { h.x += sx; h.y += sy; return; }
  }
}

function chaseSteps(h, target) {
  const dx = Math.sign(target.x - h.x);
  const dy = Math.sign(target.y - h.y);
  return Math.abs(target.x - h.x) >= Math.abs(target.y - h.y) ? [[dx, 0], [0, dy], [dx, dy]] : [[0, dy], [dx, 0], [dx, dy]];
}

export function rotHorde(state, h) {
  h.count = Math.max(0, h.count - h.count * 0.015 - (state.weather === 'snow' ? 0.2 : 0.05));
}

function contactText(h, s, guards) {
  const n = Math.round(h.count);
  const who = n > 1 ? `Une horde de ${n} zombies attaque` : 'Un zombie attaque';
  const watch = guards > 0 ? `${plural(guards, 'gardien')} ${guards > 1 ? 'font' : 'fait'} face.` : 'Personne ne monte la garde.';
  return `🧟 ${who} ${s.name} ! ${watch}`;
}

export function attackSettlement(state, rng, h, s, entry, census) {
  const guards = entry.people.filter((p) => p.alive && p.job === 'gardien');
  if (!h.metIds.includes(s.id)) {
    h.metIds.push(s.id);
    logEvent(state, 'zombie', contactText(h, s, entry.jobs.gardien || 0), { x: s.x, y: s.y });
  }
  const defense = defenseStrength(state, s, entry);
  const bites = stochasticRound(rng, h.count * BITE_PER_ZOMBIE * h.count / (h.count + DEFENSE_BITE_WEIGHT * defense));
  for (let i = 0; i < bites; i++) {
    const victim = pickVictim(rng, entry.people, guards);
    if (victim) biteVictim(state, rng, victim, h);
  }
  const killed = stochasticRound(rng, Math.min(h.count * MAX_KILL_SHARE, defense * KILL_PER_DEFENSE));
  const before = h.count;
  h.count = Math.max(0, h.count - killed);
  if (before >= 1 && h.count < 1) return announceRepelled(state, rng, s, guards);
  if (defense < h.count / 2) fleeSettlement(state, rng, census, s, entry, h);
}

function announceRepelled(state, rng, s, guards) {
  const hero = guards.length ? rng.pick(guards) : null;
  const extra = hero ? { x: s.x, y: s.y, personId: hero.id } : { x: s.x, y: s.y };
  logEvent(state, 'zombie', `🛡️ ${s.name} repousse la horde.${hero ? ` ${hero.name} a abattu le dernier zombie.` : ''}`, extra);
}

function pickVictim(rng, people, guards) {
  for (let tries = 0; tries < 4; tries++) {
    const pool = guards.length && rng.chance(0.4) ? guards : people;
    if (!pool.length) return null;
    const v = rng.pick(pool);
    if (v.alive && v.bitten == null) return v;
  }
  return null;
}

function biteVictim(state, rng, v, h) {
  if (rng.chance(DEVOURED_CHANCE)) {
    killPerson(state, v, v.sex === 'F' ? 'dévorée par les zombies' : 'dévoré par les zombies');
    state.zombies.dead += 1;
    return growHorde(h);
  }
  v.bitten = state.day;
  logPersonal(state, v, 'zombie', `🧟 ${v.name} est ${v.sex === 'F' ? 'mordue' : 'mordu'} par un zombie.`, { x: v.x, y: v.y });
}

export function fleeSettlement(state, rng, census, s, entry, h) {
  const z = state.zombies;
  if (z.fled.includes(s.id)) return;
  const dest = fleeDestination(state, census, s);
  if (!dest) return;
  const movers = entry.people.filter((p) => p.alive && p.bitten == null && p.job !== 'gardien' && p.job !== 'chef'
    && ageOf(state, p) >= MIGRANT_MIN_AGE && rng.chance(0.3));
  if (movers.length < 2) return;
  const kidIds = new Set();
  for (const p of movers) { p.homeId = dest.id; for (const cid of p.children) kidIds.add(cid); }
  if (kidIds.size) for (const c of state.people) if (kidIds.has(c.id) && c.alive && ageOf(state, c) < MIGRANT_MIN_AGE) c.homeId = dest.id;
  z.fled.push(s.id);
  const leader = movers[0];
  logEvent(state, 'zombie', `🧭 ${leader.name} fuit ${s.name} avec ${plural(movers.length - 1, 'compagnon')} vers ${dest.name}.`, { x: s.x, y: s.y, personId: leader.id });
}

function fleeDestination(state, census, s) {
  const populated = populatedTest(census);
  let best = null;
  let bestDist = FLEE_RANGE + 1;
  for (const t of state.settlements) {
    if (t === s || t.abandoned || t.fallen) continue;
    const d = manhattan(s.x, s.y, t.x, t.y);
    if (d >= bestDist || !populated(t) || !sameLandmass(state.world, s.x, s.y, t.x, t.y)) continue;
    if (state.zombies.hordes.some((z) => manhattan(z.x, z.y, t.x, t.y) <= 3)) continue;
    bestDist = d;
    best = t;
  }
  return best;
}

export function biteWanderers(state, rng) {
  const hordes = state.zombies.hordes;
  if (!hordes.length) return;
  const homes = new Map(state.settlements.map((s) => [s.id, s]));
  for (const p of state.people) {
    if (!p.alive || p.bitten != null || p.departed === true) continue;
    const home = homes.get(p.homeId);
    if (home && manhattan(p.x, p.y, home.x, home.y) <= 2) continue;
    const h = hordes.find((z) => z.count >= 1 && manhattan(p.x, p.y, z.x, z.y) <= 1);
    if (h && rng.chance(0.3)) biteVictim(state, rng, p, h);
  }
}

export function turnIntoZombie(state, p) {
  if (state.zombies.timedOut) return;
  const hordes = state.zombies.hordes;
  let nearest = null;
  let nearestDist = Infinity;
  for (const h of hordes) {
    const d = manhattan(p.x, p.y, h.x, h.y);
    if (d < nearestDist) { nearestDist = d; nearest = h; }
  }
  if (nearest && nearestDist <= 2) return growHorde(nearest);
  if (hordes.length < MAX_HORDES) spawnHorde(state, p.x, p.y, 1);
  else if (nearest) growHorde(nearest);
}

export function mergeHordes(state) {
  const z = state.zombies;
  const byTile = new Map();
  const kept = [];
  for (const h of z.hordes) {
    if (h.count < 1) continue;
    const key = h.y * 1000 + h.x;
    const other = byTile.get(key);
    if (!other) { byTile.set(key, h); kept.push(h); continue; }
    other.count = Math.min(HORDE_CAP, other.count + h.count);
    for (const id of h.metIds) if (!other.metIds.includes(id)) other.metIds.push(id);
  }
  z.hordes = kept;
}
