import { createRng } from './rng.js';
import { SIZE, tileAt } from './world.js';

export const ORES = {
  cuivre: { name: 'Cuivre', label: 'une pierre verte', emoji: '🟢', color: '#3fbf8f', biomes: ['mountain'], veins: [1, 4] },
  etain: { name: 'Étain', label: 'un métal gris et mou', emoji: '⚪', color: '#d5d8e0', biomes: ['mountain', 'tundra'], veins: [0, 3] },
  fer: { name: 'Fer', label: 'une roche rouge et lourde', emoji: '🟤', color: '#b5562c', biomes: ['mountain', 'swamp'], veins: [1, 3] },
  charbon: { name: 'Charbon', label: 'une pierre noire qui brûle', emoji: '⚫', color: '#222222', biomes: ['mountain', 'forest'], veins: [0, 3] },
  obsidienne: { name: 'Obsidienne', label: 'un verre noir tranchant', emoji: '🔷', color: '#5b4a8b', biomes: ['mountain', 'desert'], veins: [0, 2] },
  argile: { name: 'Argile', label: 'une terre grasse', emoji: '🟠', color: '#c77a45', biomes: ['river', 'swamp', 'lake'], veins: [2, 6] },
};

const WATER = new Set(['ocean', 'lake', 'river']);
const VEIN_RADIUS = 2;
const VEIN_TRIES = 200;
const HIGH_GROUND = 0.6;

function matches(world, x, y, biomes, loose = false) {
  const t = tileAt(world, x, y);
  if (!t || t.ore || WATER.has(t.biome) && t.biome !== 'river') return false;
  if (loose) return !WATER.has(t.biome) && t.height > HIGH_GROUND;
  if (biomes.includes(t.biome)) return true;
  if (!biomes.some((b) => WATER.has(b))) return false;
  for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
    const n = tileAt(world, x + dx, y + dy);
    if (n && biomes.includes(n.biome)) return true;
  }
  return false;
}

function placeVein(world, rng, key, ore) {
  for (let tries = 0; tries < VEIN_TRIES * 2; tries++) {
    const loose = tries >= VEIN_TRIES && !ore.biomes.includes('river');
    const cx = rng.int(0, SIZE - 1);
    const cy = rng.int(0, SIZE - 1);
    if (!matches(world, cx, cy, ore.biomes, loose)) continue;
    for (let dy = -VEIN_RADIUS; dy <= VEIN_RADIUS; dy++) {
      for (let dx = -VEIN_RADIUS; dx <= VEIN_RADIUS; dx++) {
        if (Math.abs(dx) + Math.abs(dy) > VEIN_RADIUS || !rng.chance(0.55)) continue;
        const t = tileAt(world, cx + dx, cy + dy);
        if (t && t.biome !== 'river' && !WATER.has(t.biome) && matches(world, cx + dx, cy + dy, ore.biomes, loose)) t.ore = key;
      }
    }
    return;
  }
}

export function ensureResources(state) {
  const world = state.world;
  if (world.oresPlaced) return;
  const rng = createRng((state.seed ^ 0x5eed0e5) >>> 0);
  for (const t of world.tiles) t.ore ??= null;
  for (const [key, ore] of Object.entries(ORES)) {
    const veins = rng.int(ore.veins[0], ore.veins[1]);
    for (let v = 0; v < veins; v++) placeVein(world, rng, key, ore);
  }
  world.oresPlaced = true;
}

export function oreCounts(world) {
  const counts = {};
  for (const t of world.tiles) if (t.ore) counts[t.ore] = (counts[t.ore] || 0) + 1;
  return counts;
}
