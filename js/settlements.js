import { placeName } from './names.js';
import { logEvent, plural } from './events.js';
import { tileAt, isWalkable, SIZE, BIOMES } from './world.js';
import { ageOf, MIGRANT_MIN_AGE } from './people.js';
import { sameLandmass, isCoastal } from './regions.js';

const WOOD_CAP_BASE = 40;
const WOOD_PER_HOUSE = 10;

export const LEVELS = [
  [0, 'Camp', 'un camp'], [8, 'Hameau', 'un hameau'], [20, 'Village', 'un village'],
  [50, 'Bourg', 'un bourg'], [120, 'Ville', 'une ville'], [300, 'Grande ville', 'une grande ville'],
];

const DEMOTE_RATIO = 0.8;
const GREAT_LEVEL = 4;
const MIGRATION_CROWD = 80;
const MIN_COLONISTS = 3;

export const levelIndexOf = (name) => Math.max(0, LEVELS.findIndex((l) => l[1] === name));

export function createSettlement(state, rng, x, y, parent = null) {
  const s = {
    id: state.nextId++, name: placeName(rng, new Set(state.settlements.map((o) => o.name))), x, y, houses: 1, wood: 5, foundedDay: state.day, level: 'Camp', followed: false,
    geo: null, techs: parent && Array.isArray(parent.techs) ? parent.techs.slice() : [], rooted: parent && Array.isArray(parent.rooted) ? parent.rooted.slice() : [], loreReady: false, keeperName: {}, seen: {}, seenBy: {}, research: {}, techDays: {}, departed: null, huntDry: 0, maxLevelIndex: 0,
    chefId: null, chefSince: 0, chefVacantUntil: 0, council: [], councilFormedDay: null,
    outbreak: null, lastOutbreakDay: -9999, fallen: null, civId: parent && parent.civId != null ? parent.civId : null, conqueredDay: null,
    faithId: parent ? parent.faithId ?? null : null, devotion: parent ? Math.round((parent.devotion || 0) * 0.8) : 0, temple: 0, prayer: null, awe: null,
  };
  state.settlements.push(s);
  return s;
}

export function residents(state, s) {
  return state.people.filter((p) => p.alive && p.homeId === s.id);
}

export function stepSettlements(state, rng, census) {
  const apocalypse = !!(state.zombies && state.zombies.active);
  for (const s of state.settlements) {
    const entry = census.get(s.id);
    if (!entry) continue;
    const pop = entry.people.filter((p) => p.alive);
    const m = entry.mods;
    if (!pop.length) {
      if (!s.abandoned) {
        s.abandoned = state.day;
        if (!s.fallen && !s.departed) logEvent(state, 'disparition', `${s.name} est abandonné.`, { x: s.x, y: s.y });
      }
      continue;
    }
    gatherWood(state, rng, s, (entry.jobs['bâtisseur'] || 0) + 1, m.wood);
    if (pop.length > s.houses * m.capacity && s.wood >= m.buildCost && rng.chance(m.buildChance)) {
      s.wood -= m.buildCost;
      s.houses += 1;
      logEvent(state, 'construction', `Une nouvelle maison est construite à ${s.name} (${s.houses} maisons).`, { x: s.x, y: s.y });
    }
    updateLevel(state, s, pop.length);
    const pressed = entry.hungry > entry.pop * 0.2 || pop.length > MIGRATION_CROWD || localFoodPressure(state, s) > 0.7;
    if (pop.length >= 10 && pressed && !apocalypse && rng.chance(0.01 * m.migrationChance)) migrate(state, rng, s, pop, m);
  }
}

function nextLevelIndex(current, pop) {
  let i = current;
  while (i + 1 < LEVELS.length && pop >= LEVELS[i + 1][0]) i += 1;
  while (i > 0 && pop < LEVELS[i][0] * DEMOTE_RATIO) i -= 1;
  return i;
}

function updateLevel(state, s, pop) {
  const i = nextLevelIndex(levelIndexOf(s.level), pop);
  s.level = LEVELS[i][1];
  if (i <= (s.maxLevelIndex ?? 0)) return;
  s.maxLevelIndex = i;
  logEvent(state, 'croissance', `${s.name} devient ${LEVELS[i][2]} !`, { x: s.x, y: s.y, highlight: i >= GREAT_LEVEL });
}

function gatherWood(state, rng, s, workers, woodMult) {
  s.wood = Math.min(s.wood, WOOD_CAP_BASE + s.houses * WOOD_PER_HOUSE);
  for (let dy = -2; dy <= 2; dy++) {
    for (let dx = -2; dx <= 2; dx++) {
      const t = tileAt(state.world, s.x + dx, s.y + dy);
      if (!t) continue;
      if (s.wood < WOOD_CAP_BASE + s.houses * WOOD_PER_HOUSE && t.trees > 0 && rng.chance(0.04 * workers * woodMult)) { t.trees -= 1; s.wood += 1; }
      if (t.trees < (t.biome === 'forest' ? 9 : 2) && t.fertility > 0.3 && rng.chance(0.015)) t.trees += 1;
    }
  }
}

export function regrowFood(state) {
  const rain = state.weather === 'rain' ? 1.5 : state.weather === 'drought' ? 0.3 : state.weather === 'snow' ? 0.4 : 1;
  for (const t of state.world.tiles) {
    if (t.food < t.fertility * 12) t.food = Math.min(t.fertility * 12, t.food + t.fertility * 0.7 * rain);
  }
}

export function localFoodPressure(state, s) {
  let food = 0;
  let max = 0;
  for (let dy = -3; dy <= 3; dy++) {
    for (let dx = -3; dx <= 3; dx++) {
      const t = tileAt(state.world, s.x + dx, s.y + dy);
      if (t) { food += t.food; max += t.fertility * 12; }
    }
  }
  return max ? 1 - food / max : 1;
}

function migrate(state, rng, from, pop, m) {
  const spot = findSettlementSpot(state, rng, from.x, from.y, m.migrationRadius, m.crossWater);
  if (!spot) return;
  const adults = pop.filter((p) => ageOf(state, p) >= MIGRANT_MIN_AGE && !p.traits.includes('prudent') && p.id !== from.chefId);
  if (adults.length < 4) return;
  const leader = rng.pick(adults);
  const group = adults.filter((p) => p === leader || p.partnerId === leader.id || rng.chance(0.25)).slice(0, 8);
  if (group.length < MIN_COLONISTS) return;
  const target = createSettlement(state, rng, spot.x, spot.y, from);
  const byBoat = !sameLandmass(state.world, from.x, from.y, spot.x, spot.y);
  const travellers = [];
  for (const p of group) {
    p.homeId = target.id;
    travellers.push(p);
    for (const cid of p.children) {
      const c = state.people.find((q) => q.id === cid);
      if (c && c.alive && ageOf(state, c) < MIGRANT_MIN_AGE) { c.homeId = target.id; travellers.push(c); }
    }
  }
  if (byBoat) for (const p of travellers) { p.x = spot.x; p.y = spot.y; }
  target.maxLevelIndex = nextLevelIndex(0, travellers.length);
  target.level = LEVELS[target.maxLevelIndex][1];
  const company = `avec ${plural(group.length - 1, 'compagnon')}`;
  const leaving = byBoat ? `⛵ ${leader.name} quitte ${from.name} en bateau ${company}.` : `${leader.name} quitte ${from.name} ${company}.`;
  const founding = byBoat ? `🏝️ ${target.name} est fondé au-delà des eaux par ${leader.name}.` : `${target.name} est fondé par ${leader.name}.`;
  logEvent(state, 'migration', leaving, { x: from.x, y: from.y, personId: leader.id });
  logEvent(state, 'fondation', founding, { x: target.x, y: target.y, personId: leader.id });
}

export function findSettlementSpot(state, rng, cx, cy, radius = 10, crossWater = false) {
  const world = state.world;
  const landLocked = !crossWater && isWalkable(world, cx, cy);
  let best = null;
  let bestScore = 0;
  for (let tries = 0; tries < 60; tries++) {
    const x = Math.max(1, Math.min(SIZE - 2, cx + rng.int(-radius, radius)));
    const y = Math.max(1, Math.min(SIZE - 2, cy + rng.int(-radius, radius)));
    const t = tileAt(world, x, y);
    if (!t || !BIOMES[t.biome].walkable || t.biome === 'river' || t.biome === 'mountain') continue;
    if (landLocked && !sameLandmass(world, cx, cy, x, y)) continue;
    const near = state.settlements.some((s) => Math.abs(s.x - x) + Math.abs(s.y - y) < 6);
    if (near) continue;
    const score = spotScore(world, x, y, crossWater);
    if (score > bestScore) { bestScore = score; best = { x, y }; }
  }
  return best;
}

const FISHING_WATERS = { ocean: true, lake: true };
const FISHING_VALUE = 0.55;
const COAST_BONUS = 3;
const SEAFARER_COAST_BONUS = 5;

function spotScore(world, x, y, crossWater) {
  let score = 0;
  for (let dy = -2; dy <= 2; dy++) {
    for (let dx = -2; dx <= 2; dx++) {
      const n = tileAt(world, x + dx, y + dy);
      if (!n) continue;
      score += FISHING_WATERS[n.biome] ? FISHING_VALUE : n.fertility + n.trees * 0.05;
    }
  }
  if (isCoastal(world, x, y)) score += crossWater ? SEAFARER_COAST_BONUS : COAST_BONUS;
  return score;
}
