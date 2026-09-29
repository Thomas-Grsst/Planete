import { SIZE, BIOMES } from './world.js';
import { levelIndexOf } from './settlements.js';

const REFRESH_DAYS = 10;
const BASE_RADIUS = 3;
const cache = new WeakMap();

const manhattan = (ax, ay, bx, by) => Math.abs(ax - bx) + Math.abs(ay - by);

function signature(state) {
  return state.settlements.map((s) => (s.abandoned ? 'x' : `${s.id}:${s.civId}:${s.level}`)).join('|');
}

function compute(state) {
  const map = new Int32Array(SIZE * SIZE).fill(-1);
  const claims = state.settlements
    .filter((s) => !s.abandoned && s.civId != null)
    .map((s) => ({ s, radius: BASE_RADIUS + levelIndexOf(s.level) }));
  if (!claims.length) return map;
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const t = state.world.tiles[y * SIZE + x];
      if (!BIOMES[t.biome].walkable) continue;
      let best = null;
      let bestD = Infinity;
      for (const c of claims) {
        const d = manhattan(x, y, c.s.x, c.s.y);
        if (d <= c.radius && d < bestD) { bestD = d; best = c.s; }
      }
      if (best) map[y * SIZE + x] = best.civId;
    }
  }
  return map;
}

export function territoryMap(state) {
  const sig = signature(state);
  const hit = cache.get(state);
  if (hit && hit.sig === sig && state.day - hit.day < REFRESH_DAYS) return hit.map;
  const map = compute(state);
  cache.set(state, { sig, day: state.day, map });
  return map;
}

export function territoryShare(state, civ) {
  const map = territoryMap(state);
  let land = 0;
  let owned = 0;
  for (let i = 0; i < map.length; i++) {
    if (!BIOMES[state.world.tiles[i].biome].walkable) continue;
    land += 1;
    if (map[i] === civ.id) owned += 1;
  }
  return land ? Math.round((owned / land) * 100) : 0;
}
