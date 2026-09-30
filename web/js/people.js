import { personName, randomJob, TRAITS } from './names.js';
import { logEvent } from './events.js';
import { tileAt, isWalkable, SIZE } from './world.js';
import { DEFAULT_MODS } from './techTree.js';

const YEAR = 360;
export const ADULT_AGE = 14;
export const MIGRANT_MIN_AGE = 16;
const BIRTH_CHANCE = 0.0035;
const CHILD_MEAL = 0.5;
const WORLD_SOFT_CAP = 200;
const WORLD_HARD_CAP = 300;

export function createPerson(state, rng, x, y, ageYears, homeId, parents = null) {
  const p = {
    id: state.nextId++,
    name: personName(rng),
    sex: rng.chance(0.5) ? 'F' : 'M',
    birthDay: state.day - Math.round(ageYears * YEAR),
    x, y, homeId,
    partnerId: null,
    parents,
    children: [],
    traits: [rng.pick(TRAITS), rng.pick(TRAITS)].filter((t, i, a) => a.indexOf(t) === i),
    job: ageYears >= ADULT_AGE ? randomJob(rng) : 'enfant',
    health: 100,
    hunger: 0,
    happiness: rng.int(55, 85),
    alive: true,
    deathDay: null,
    history: [],
  };
  state.people.push(p);
  return p;
}

export const ageOf = (state, p) => Math.floor((state.day - p.birthDay) / YEAR);

export function settlementOf(state, p) {
  return state.settlements.find((s) => s.id === p.homeId) || null;
}

export function stepPeople(state, rng, census) {
  const world = state.world;
  const alive = state.people.filter((p) => p.alive);
  const byId = new Map(alive.map((p) => [p.id, p]));
  for (const p of alive) {
    const age = ageOf(state, p);
    const entry = census ? census.get(p.homeId) : null;
    const home = entry ? entry.s : settlementOf(state, p);
    const mods = entry ? entry.mods : DEFAULT_MODS;
    const unwell = p.sick || p.bitten != null;
    moveAndEat(state, rng, p, world, home, mods, byId);
    if (p.hunger > 40) p.health -= (p.hunger - 40) * 0.05;
    else if (p.health < 100 && !p.sick) p.health += 0.3;
    const mood = (p.hunger > 30 ? -0.4 : 0.15) + (state.weather === 'rain' ? -0.05 : 0) + mods.happiness + (unwell ? -0.3 : 0);
    p.happiness = Math.max(0, Math.min(100, p.happiness + mood));
    if (age > 55 && rng.chance((age - 55) * 0.00008)) { killPerson(state, p, 'de vieillesse'); continue; }
    if (p.health <= 0) { killPerson(state, p, 'de faim'); continue; }
    if (rng.chance(0.000025)) { killPerson(state, p, "d'un accident"); continue; }
    if (age >= 16 && !p.partnerId && rng.chance(p.traits.includes('sociable') ? 0.02 : 0.01)) findPartner(state, rng, p, entry);
    if (p.partnerId && p.sex === 'F' && age >= 17 && age <= 42 && p.children.length < 6 && rng.chance(birthChance(entry, alive.length))) giveBirth(state, rng, p);
  }
}

function moveAndEat(state, rng, p, world, home, mods, byId) {
  const dist = home ? Math.abs(p.x - home.x) + Math.abs(p.y - home.y) : 0;
  const wander = p.sick || p.bitten != null ? 0 : p.traits.includes('aventurier') ? 0.45 : 0.25;
  let dx = 0;
  let dy = 0;
  if (home && dist > 4) { dx = Math.sign(home.x - p.x); dy = Math.sign(home.y - p.y); }
  else if (rng.chance(wander)) { dx = rng.int(-1, 1); dy = rng.int(-1, 1); }
  if (p.hunger > 20) { const best = richestNeighbor(world, p.x, p.y); if (best) { dx = best.dx; dy = best.dy; } }
  if ((dx || dy) && isWalkable(world, p.x + dx, p.y + dy)) { p.x += dx; p.y += dy; }
  if (ageOf(state, p) < ADULT_AGE && isFedByParent(p, byId)) { feedChild(world, p, home, mods); return; }
  const tile = tileAt(world, p.x, p.y);
  if (tile && tile.food >= 1) { tile.food -= 1; p.hunger = Math.max(0, p.hunger - mods.eat - (p.job === 'cueilleur' ? 5 : 0)); }
  else p.hunger += mods.hungerEmpty;
}

function feedChild(world, p, home, mods) {
  const own = tileAt(world, p.x, p.y);
  const tile = own && own.food >= CHILD_MEAL ? own : home ? tileAt(world, home.x, home.y) : null;
  if (tile && tile.food >= CHILD_MEAL) { tile.food -= CHILD_MEAL; p.hunger = Math.max(0, p.hunger - 10); }
  else p.hunger += mods.hungerEmpty;
}

function birthChance(entry, worldPop) {
  const world = Math.max(0.05, Math.min(1, (WORLD_HARD_CAP - worldPop) / (WORLD_HARD_CAP - WORLD_SOFT_CAP)));
  if (!entry) return BIRTH_CHANCE * world;
  const hungry = entry.hungry > entry.pop / 4 ? 0.2 : 1;
  const crowded = entry.pop > entry.s.houses * entry.mods.capacity * 1.2 ? 0.3 : 1;
  return BIRTH_CHANCE * hungry * crowded * world;
}

function richestNeighbor(world, x, y) {
  let best = null;
  let bestFood = tileAt(world, x, y)?.food ?? 0;
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      const t = tileAt(world, x + dx, y + dy);
      if (t && isWalkable(world, x + dx, y + dy) && t.food > bestFood + 0.5) { bestFood = t.food; best = { dx, dy }; }
    }
  }
  return best;
}

function isFedByParent(p, byId) {
  if (!p.parents) return true;
  return p.parents.some((id) => { const q = byId.get(id); return q && q.alive && q.hunger < 60; });
}

export function killPerson(state, p, cause) {
  const age = ageOf(state, p);
  p.alive = false;
  p.deathDay = state.day;
  if (p.partnerId) { const q = state.people.find((x) => x.id === p.partnerId); if (q) q.partnerId = null; }
  const home = settlementOf(state, p);
  logEvent(state, 'deces', `${p.name} meurt ${cause} à ${age} ans${home ? ` à ${home.name}` : ''}.`, { x: p.x, y: p.y, personId: p.id });
}

function findPartner(state, rng, p, entry) {
  if (!entry) return;
  const candidates = entry.people.filter((q) => q.alive && q.id !== p.id && !q.partnerId && q.sex !== p.sex
    && q.homeId === p.homeId && ageOf(state, q) >= 16 && !areSiblings(p, q));
  if (!candidates.length) return;
  const q = rng.pick(candidates);
  p.partnerId = q.id;
  q.partnerId = p.id;
  p.happiness = Math.min(100, p.happiness + 15);
  q.happiness = Math.min(100, q.happiness + 15);
  logEvent(state, 'couple', `${p.name} et ${q.name} forment un couple.`, { x: p.x, y: p.y, personId: p.id });
  logEvent(state, 'couple_silent', `${q.name} et ${p.name} forment un couple.`, { personId: q.id });
}

const areSiblings = (a, b) => a.parents && b.parents && (a.parents[0] === b.parents[0] || a.parents[1] === b.parents[1]);

function giveBirth(state, rng, mother) {
  const father = state.people.find((x) => x.id === mother.partnerId);
  const child = createPerson(state, rng, mother.x, mother.y, 0, mother.homeId, [mother.id, father ? father.id : null]);
  mother.children.push(child.id);
  if (father) father.children.push(child.id);
  const home = settlementOf(state, mother);
  logEvent(state, 'naissance', `${child.name} naît${home ? ` à ${home.name}` : ''}, enfant de ${mother.name}${father ? ` et ${father.name}` : ''}.`, { x: child.x, y: child.y, personId: child.id });
  mother.history.push({ day: state.day, text: `Donne naissance à ${child.name}.` });
}

export function randomWalkableNear(world, rng, cx, cy, radius) {
  for (let tries = 0; tries < 30; tries++) {
    const x = Math.max(0, Math.min(SIZE - 1, cx + rng.int(-radius, radius)));
    const y = Math.max(0, Math.min(SIZE - 1, cy + rng.int(-radius, radius)));
    if (isWalkable(world, x, y)) return { x, y };
  }
  return { x: cx, y: cy };
}
