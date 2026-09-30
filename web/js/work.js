import { tileAt, isWalkable } from './world.js';
import { logEvent, ofPlace } from './events.js';

const FARM_RADIUS = 2;
const HUNT_RADIUS = 5;
const FOOD_TILE_CAP = 40;

const FIELD_CAP_PER_FERTILITY = 18;
const MIN_FIELD_FERTILITY = 0.2;
const FARM_YIELD_PER_FARMER = 0.08;
const MAX_EFFECTIVE_FARMERS = 10;
const FARM_WEATHER = { drought: 0.3, rain: 1.3, snow: 0.5 };
const HUNT_TAKE_PER_HUNTER = 0.08;
const FOOD_PER_ANIMAL = 8;
const HUNTABLE_HERD_MIN = 10;
const HERD_BREEDING_STOCK = 8;
const HUNT_DRY_ALERT_DAYS = 20;
const HUNT_ALERT_REST_DAYS = 360;
const FISH_PER_FISHER = 0.6;
const DROP_OFFSETS = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]];

const manhattan = (ax, ay, bx, by) => Math.abs(ax - bx) + Math.abs(ay - by);

export function stepWork(state, rng, census) {
  for (const entry of census.values()) {
    const s = entry.s;
    if (!s || s.abandoned || entry.pop <= 0) continue;
    const jobs = entry.jobs || {};
    const mods = entry.mods || {};
    farmFields(state, s, jobs.fermier || 0, mods.farm ?? 0);
    huntHerds(state, s, jobs.chasseur || 0, mods.hunt ?? 1);
    fishWaters(state, s, jobs['pêcheur'] || 0, mods.fish ?? 0.5);
  }
}

function farmFields(state, s, farmers, farmMod) {
  if (farmers <= 0 || farmMod <= 0) return;
  const weather = FARM_WEATHER[state.weather] ?? 1;
  const gain = FARM_YIELD_PER_FARMER * Math.min(farmers, MAX_EFFECTIVE_FARMERS) * farmMod * weather;
  for (let dy = -FARM_RADIUS; dy <= FARM_RADIUS; dy++) {
    for (let dx = -FARM_RADIUS; dx <= FARM_RADIUS; dx++) {
      const x = s.x + dx;
      const y = s.y + dy;
      if (!isWalkable(state.world, x, y)) continue;
      const t = tileAt(state.world, x, y);
      if (t.fertility < MIN_FIELD_FERTILITY) continue;
      const cap = t.fertility * FIELD_CAP_PER_FERTILITY;
      if (t.food < cap) t.food = Math.min(cap, t.food + t.fertility * gain);
    }
  }
}

function huntHerds(state, s, hunters, huntMod) {
  if (hunters <= 0) return;
  const herd = nearestHuntableHerd(state, s);
  if (!herd) {
    s.huntDry = (s.huntDry || 0) + 1;
    if (s.huntDry === HUNT_DRY_ALERT_DAYS && state.day - (s.huntAlertDay ?? -99999) > HUNT_ALERT_REST_DAYS) {
      s.huntAlertDay = state.day;
      logEvent(state, 'chasse', `🏹 Le gibier se fait rare autour ${ofPlace(s.name)}.`, { x: s.x, y: s.y });
    }
    return;
  }
  const take = Math.min(herd.count - HERD_BREEDING_STOCK, hunters * HUNT_TAKE_PER_HUNTER * huntMod);
  herd.count -= take;
  depositFood(state, s, take * FOOD_PER_ANIMAL);
  s.huntDry = 0;
}

function nearestHuntableHerd(state, s) {
  let best = null;
  let bestDist = HUNT_RADIUS + 1;
  for (const h of state.herds) {
    if (h.species === 'wolf' || h.count < HUNTABLE_HERD_MIN) continue;
    const d = manhattan(h.x, h.y, s.x, s.y);
    if (d < bestDist) { bestDist = d; best = h; }
  }
  return best;
}

function fishWaters(state, s, fishers, fishMod) {
  if (fishers <= 0 || !s.geo || s.geo.water < 1) return;
  depositFood(state, s, fishers * FISH_PER_FISHER * fishMod);
}

function depositFood(state, s, amount) {
  if (amount <= 0) return;
  const tiles = [];
  for (const [dx, dy] of DROP_OFFSETS) {
    if (isWalkable(state.world, s.x + dx, s.y + dy)) tiles.push(tileAt(state.world, s.x + dx, s.y + dy));
  }
  if (!tiles.length) return;
  const part = amount / tiles.length;
  for (const t of tiles) {
    if (t.food < FOOD_TILE_CAP) t.food = Math.min(FOOD_TILE_CAP, t.food + part);
  }
}
