import { createRng } from './rng.js';

export const SIZE = 48;

export const BIOMES = {
  ocean: { name: 'Océan', color: '#2a6fb3', walkable: false, food: 0.2 },
  lake: { name: 'Lac', color: '#3a8fd0', walkable: false, food: 0.3 },
  river: { name: 'Rivière', color: '#4aa3e0', walkable: true, food: 0.9 },
  beach: { name: 'Plage', color: '#e5d59a', walkable: true, food: 0.3 },
  plain: { name: 'Plaine', color: '#8bc34a', walkable: true, food: 0.8 },
  forest: { name: 'Forêt', color: '#3e8e41', walkable: true, food: 0.6 },
  swamp: { name: 'Marais', color: '#6b8e5a', walkable: true, food: 0.3 },
  desert: { name: 'Désert', color: '#d9b96b', walkable: true, food: 0.05 },
  tundra: { name: 'Toundra', color: '#b9c9c9', walkable: true, food: 0.15 },
  mountain: { name: 'Montagne', color: '#8d8d8d', walkable: true, food: 0.05 },
};

function noiseGrid(rng, size, octaves) {
  const out = new Float32Array(size * size);
  let amp = 1;
  let total = 0;
  for (let o = 0; o < octaves; o++) {
    const step = Math.max(2, size >> o);
    const cells = Math.ceil(size / step) + 2;
    const grid = Array.from({ length: cells * cells }, () => rng.next());
    for (let y = 0; y < size; y++) {
      for (let x = 0; x < size; x++) {
        const gx = x / step;
        const gy = y / step;
        const x0 = Math.floor(gx);
        const y0 = Math.floor(gy);
        const fx = smooth(gx - x0);
        const fy = smooth(gy - y0);
        const v00 = grid[y0 * cells + x0];
        const v10 = grid[y0 * cells + x0 + 1];
        const v01 = grid[(y0 + 1) * cells + x0];
        const v11 = grid[(y0 + 1) * cells + x0 + 1];
        const v = lerp(lerp(v00, v10, fx), lerp(v01, v11, fx), fy);
        out[y * size + x] += v * amp;
      }
    }
    total += amp;
    amp *= 0.5;
  }
  for (let i = 0; i < out.length; i++) out[i] /= total;
  return out;
}

const smooth = (t) => t * t * (3 - 2 * t);
const lerp = (a, b, t) => a + (b - a) * t;

function pickBiome(h, m, y) {
  if (h < 0.38) return 'ocean';
  if (h < 0.41) return 'beach';
  if (h > 0.78) return 'mountain';
  const polar = Math.abs(y - SIZE / 2) / (SIZE / 2);
  if (polar > 0.82 && h < 0.7) return 'tundra';
  if (m < 0.3 && h < 0.6) return 'desert';
  if (m > 0.75 && h < 0.48) return 'swamp';
  if (m > 0.55) return 'forest';
  return 'plain';
}

function carveRivers(tiles, heights, rng) {
  const peaks = [];
  for (let i = 0; i < tiles.length; i++) if (heights[i] > 0.72) peaks.push(i);
  const count = Math.min(4, peaks.length);
  for (let r = 0; r < count; r++) {
    let i = rng.pick(peaks);
    for (let steps = 0; steps < SIZE * 2; steps++) {
      const t = tiles[i];
      if (t.biome === 'ocean' || t.biome === 'lake') break;
      if (t.biome !== 'mountain') t.biome = 'river';
      let best = -1;
      let bestH = heights[i];
      for (const j of neighbors(i)) {
        if (heights[j] < bestH) { bestH = heights[j]; best = j; }
      }
      if (best < 0) { if (t.biome !== 'mountain') t.biome = 'lake'; break; }
      i = best;
    }
  }
}

export function neighbors(i) {
  const x = i % SIZE;
  const y = Math.floor(i / SIZE);
  const out = [];
  if (x > 0) out.push(i - 1);
  if (x < SIZE - 1) out.push(i + 1);
  if (y > 0) out.push(i - SIZE);
  if (y < SIZE - 1) out.push(i + SIZE);
  return out;
}

export function generateWorld(seed) {
  const rng = createRng(seed);
  const heights = noiseGrid(rng, SIZE, 4);
  const moisture = noiseGrid(rng, SIZE, 3);
  const tiles = [];
  for (let i = 0; i < SIZE * SIZE; i++) {
    const x = i % SIZE;
    const y = Math.floor(i / SIZE);
    const edge = Math.min(x, y, SIZE - 1 - x, SIZE - 1 - y) / (SIZE / 2);
    const h = heights[i] * Math.min(1, edge * 2.2 + 0.35);
    heights[i] = h;
    const biome = pickBiome(h, moisture[i], y);
    tiles.push({
      biome,
      height: h,
      trees: biome === 'forest' ? rng.int(4, 9) : biome === 'plain' || biome === 'swamp' ? rng.int(0, 2) : 0,
      stone: biome === 'mountain' ? rng.int(5, 12) : 0,
      food: 0,
      fertility: BIOMES[biome].food,
    });
  }
  carveRivers(tiles, heights, rng);
  for (let i = 0; i < tiles.length; i++) {
    const t = tiles[i];
    t.fertility = BIOMES[t.biome].food;
    if (t.biome !== 'river') {
      for (const j of neighbors(i)) if (tiles[j].biome === 'river' && t.fertility > 0.1) t.fertility = Math.min(1, t.fertility + 0.3);
    }
    t.food = t.fertility * 10;
  }
  return { size: SIZE, tiles };
}

export function tileAt(world, x, y) {
  if (x < 0 || y < 0 || x >= SIZE || y >= SIZE) return null;
  return world.tiles[y * SIZE + x];
}

export function isWalkable(world, x, y) {
  const t = tileAt(world, x, y);
  return !!t && BIOMES[t.biome].walkable;
}
