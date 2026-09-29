import { tileAt, SIZE, isWalkable } from './world.js';
import { ageOf } from './people.js';
import { hasTech } from './techTree.js';
import { sameLandmass } from './regions.js';

const MEMORY_DAYS = 90;
const TRADE_MEMORY_DAYS = 360;
const TRADE_RANGE = 14;
const EXPEDITION_CHANCE = 0.02;
const EXPEDITION_RADIUS = 8;
const SCAN_MIN_AGE = 10;
const LOST_LORE_DAYS = 720;
const STORM_DAMAGE_DAYS = 360;
const ISLAND_RANGE = 12;
const WATER = new Set(['ocean', 'lake', 'river']);
const SEEN_FLAGS = new Set(['cuivre', 'etain', 'fer', 'charbon', 'obsidienne', 'argile', 'stone', 'forest', 'swamp', 'fertile', 'water', 'river', 'bone']);

const manhattan = (ax, ay, bx, by) => Math.abs(ax - bx) + Math.abs(ay - by);

export function ensureContextState(s) {
  s.seen ??= {};
  s.seenBy ??= {};
}

function note(state, s, flag, p) {
  s.seen[flag] = state.day;
  s.seenBy[flag] = p.id;
}

function touchTile(state, s, p, x, y) {
  const world = state.world;
  const t = tileAt(world, x, y);
  if (!t) return;
  if (t.ore) note(state, s, t.ore, p);
  if (t.biome === 'mountain' || t.stone > 0) note(state, s, 'stone', p);
  if (t.biome === 'forest') note(state, s, 'forest', p);
  if (t.biome === 'swamp') note(state, s, 'swamp', p);
  if (t.fertility >= 0.8 && manhattan(x, y, s.x, s.y) <= 3) note(state, s, 'fertile', p);
  for (let dy = -1; dy <= 1; dy++) {
    for (let dx = -1; dx <= 1; dx++) {
      const n = tileAt(world, x + dx, y + dy);
      if (!n || !WATER.has(n.biome)) continue;
      note(state, s, 'water', p);
      if (n.biome === 'river') note(state, s, 'river', p);
    }
  }
}

function expedition(state, rng, s, p) {
  const radius = EXPEDITION_RADIUS + (hasTech(s, 'roue') ? 4 : 0) + (hasTech(s, 'navigation') ? 8 : 0);
  const x = Math.max(0, Math.min(SIZE - 1, s.x + rng.int(-radius, radius)));
  const y = Math.max(0, Math.min(SIZE - 1, s.y + rng.int(-radius, radius)));
  if (!isWalkable(state.world, x, y)) return;
  if (!hasTech(s, 'navigation') && !sameLandmass(state.world, s.x, s.y, x, y)) return;
  touchTile(state, s, p, x, y);
}

export function scanContacts(state, rng, census) {
  for (const entry of census.values()) {
    const s = entry.s;
    if (!s || s.abandoned || entry.pop <= 0) continue;
    ensureContextState(s);
    let hunter = null;
    for (const p of entry.people) {
      if (!p.alive || ageOf(state, p) < SCAN_MIN_AGE) continue;
      touchTile(state, s, p, p.x, p.y);
      if (p.job === 'chasseur') hunter = p;
      const explorer = p.traits.includes('curieux') || p.traits.includes('aventurier');
      if (explorer && rng.chance(EXPEDITION_CHANCE)) expedition(state, rng, s, p);
    }
    if (hunter && entry.herdNear) note(state, s, 'bone', hunter);
  }
}

function islandNear(state, s) {
  if (s.islandNear !== undefined) return s.islandNear;
  s.islandNear = false;
  for (let dy = -ISLAND_RANGE; dy <= ISLAND_RANGE && !s.islandNear; dy++) {
    for (let dx = -ISLAND_RANGE; dx <= ISLAND_RANGE; dx++) {
      const x = s.x + dx;
      const y = s.y + dy;
      if (isWalkable(state.world, x, y) && !sameLandmass(state.world, s.x, s.y, x, y)) { s.islandNear = true; break; }
    }
  }
  return s.islandNear;
}

function tradeSeen(state, s, ore) {
  return state.settlements.some((o) => o !== s && !o.abandoned && o.seen && state.day - (o.seen[ore] ?? -99999) <= TRADE_MEMORY_DAYS
    && manhattan(o.x, o.y, s.x, s.y) <= TRADE_RANGE
    && (sameLandmass(state.world, o.x, o.y, s.x, s.y) || hasTech(o, 'navigation') || hasTech(s, 'navigation')));
}

const recent = (state, day, span) => state.day - (day ?? -99999) <= span;

function evaluate(state, s, entry, flag) {
  if (flag === 'dream') return true;
  if (flag.startsWith('tech:')) return hasTech(s, flag.slice(5));
  if (flag.startsWith('trade:')) return tradeSeen(state, s, flag.slice(6));
  if (SEEN_FLAGS.has(flag)) return recent(state, s.seen[flag], MEMORY_DAYS);
  const pop = entry.pop;
  switch (flag) {
    case 'lightning': return state.weather === 'storm' && recent(state, s.seen.forest, MEMORY_DAYS);
    case 'storm': return state.weather === 'storm';
    case 'drought': return state.weather === 'drought';
    case 'winter': return Math.floor((state.day % 360) / 90) === 3;
    case 'hunger': return entry.hungry >= Math.max(2, pop * 0.25);
    case 'sick': return !!s.outbreak || entry.sick > 0;
    case 'wolves': return entry.wolfNear;
    case 'zombies': return !!(state.zombies && state.zombies.active);
    case 'crowded': return pop > s.houses * (entry.mods ? entry.mods.capacity : 4);
    case 'bigpop': return pop >= 40;
    case 'pop30': return pop >= 30;
    case 'coast': return !!(s.geo && s.geo.coast);
    case 'island': return islandNear(state, s);
    case 'lostLore': return recent(state, s.lostLoreDay, LOST_LORE_DAYS);
    case 'stormDamage': return recent(state, s.stormDamageDay, STORM_DAMAGE_DAYS);
    case 'chef': return !!entry.chef;
    case 'council': return (s.council || []).length >= 3;
    default: return false;
  }
}

export function makeContext(state, s, entry) {
  const memo = new Map();
  return {
    on(flag) {
      if (!memo.has(flag)) memo.set(flag, evaluate(state, s, entry, flag));
      return memo.get(flag);
    },
    witness(flags) {
      for (const flag of flags) if (SEEN_FLAGS.has(flag) && s.seenBy[flag] != null) return s.seenBy[flag];
      return null;
    },
  };
}
