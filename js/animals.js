import { logEvent } from './events.js';
import { tileAt, isWalkable, SIZE } from './world.js';
import { randomWalkableNear } from './people.js';

const PREY_RANGE = 8;
const WOLF_FLOOR = 4;
const PREY_REFUGE = 5;
const WOLF_RESPAWN_CHANCE = 0.003;
const WOLF_SETTLEMENT_DISTANCE = 8;

export const SPECIES = {
  deer: { name: 'Cerfs', emoji: '🦌', biomes: ['forest', 'plain'], growth: 0.004, cap: 40, prey: null },
  sheep: { name: 'Moutons', emoji: '🐑', biomes: ['plain', 'beach'], growth: 0.005, cap: 30, prey: null },
  wolf: { name: 'Loups', emoji: '🐺', biomes: ['forest', 'mountain', 'tundra'], growth: 0.002, cap: 14, prey: 'deer' },
};

export function seedHerds(state, rng) {
  const world = state.world;
  for (const [key, sp] of Object.entries(SPECIES)) {
    const count = key === 'wolf' ? 3 : 5;
    for (let n = 0; n < count; n++) {
      for (let tries = 0; tries < 60; tries++) {
        const x = rng.int(0, SIZE - 1);
        const y = rng.int(0, SIZE - 1);
        const t = tileAt(world, x, y);
        if (t && sp.biomes.includes(t.biome)) {
          state.herds.push({ id: state.nextId++, species: key, x, y, count: rng.int(6, 14), followed: false });
          break;
        }
      }
    }
  }
}

export function stepHerds(state, rng) {
  const world = state.world;
  for (const h of state.herds) {
    const sp = SPECIES[h.species];
    if (rng.chance(0.3)) {
      const to = randomWalkableNear(world, rng, h.x, h.y, 1);
      const t = tileAt(world, to.x, to.y);
      if (t && (sp.biomes.includes(t.biome) || rng.chance(0.2))) { h.x = to.x; h.y = to.y; }
    }
    const t = tileAt(world, h.x, h.y);
    const suitable = t && sp.biomes.includes(t.biome);
    let growth = sp.growth * (suitable ? 1 : -0.6) * (1 - h.count / sp.cap);
    if (sp.prey) growth = predatorGrowth(state, rng, h, sp, suitable);
    if (!sp.prey && t && t.food >= 1 && rng.chance(0.15)) t.food -= 0.5;
    h.count += h.count * growth;
    if (rng.chance(0.15) && suitable) h.count += 0.3;
    const sameSpecies = state.herds.filter((o) => o.species === h.species).length;
    if (h.count >= sp.cap * 1.05 && sameSpecies < 8 && rng.chance(0.01)) splitHerd(state, rng, h, sp);
    if (h.count > sp.cap * 1.2) h.count = sp.cap * 1.2;
  }
  state.herds = state.herds.filter((h) => h.count >= 1);
  if (rng.chance(WOLF_RESPAWN_CHANCE) && !state.herds.some((h) => h.species === 'wolf')) respawnWolves(state, rng);
}

function respawnWolves(state, rng) {
  const sp = SPECIES.wolf;
  for (let tries = 0; tries < 30; tries++) {
    const x = rng.int(0, SIZE - 1);
    const y = rng.int(0, SIZE - 1);
    const t = tileAt(state.world, x, y);
    if (!t || !sp.biomes.includes(t.biome)) continue;
    if (state.settlements.some((s) => !s.abandoned && Math.abs(s.x - x) + Math.abs(s.y - y) < WOLF_SETTLEMENT_DISTANCE)) continue;
    state.herds.push({ id: state.nextId++, species: 'wolf', x, y, count: rng.int(5, 9), followed: false });
    logEvent(state, 'animaux', '🐺 Une meute de loups descend des terres sauvages.', { x, y });
    return;
  }
}

function predatorGrowth(state, rng, wolf, sp, suitable) {
  const prey = state.herds.find((o) => o.species === sp.prey && Math.abs(o.x - wolf.x) + Math.abs(o.y - wolf.y) <= PREY_RANGE);
  if (!prey || prey.count <= PREY_REFUGE) return suitable && wolf.count <= WOLF_FLOOR ? 0 : -0.006;
  if (rng.chance(0.25)) {
    const eaten = Math.min(Math.max(0, prey.count - PREY_REFUGE), 1 + Math.floor(wolf.count / 5));
    prey.count -= eaten;
    if (prey.count < 1 && rng.chance(0.5)) logEvent(state, 'animaux', `Une meute de loups a décimé un troupeau de ${SPECIES[prey.species].name.toLowerCase()}.`, { x: wolf.x, y: wolf.y });
  }
  if (Math.abs(prey.x - wolf.x) + Math.abs(prey.y - wolf.y) > 1) chase(state.world, wolf, prey);
  return sp.growth * (1 - wolf.count / sp.cap) * 2;
}

function chase(world, wolf, prey) {
  const x = wolf.x + Math.sign(prey.x - wolf.x);
  const y = wolf.y + Math.sign(prey.y - wolf.y);
  if (isWalkable(world, x, y)) { wolf.x = x; wolf.y = y; }
}

function splitHerd(state, rng, h, sp) {
  const to = randomWalkableNear(state.world, rng, h.x, h.y, 4);
  if (!isWalkable(state.world, to.x, to.y)) return;
  const size = Math.floor(h.count / 2);
  h.count -= size;
  state.herds.push({ id: state.nextId++, species: h.species, x: to.x, y: to.y, count: size, followed: false });
  if (sp.prey) logEvent(state, 'animaux', `Une nouvelle meute de ${sp.name.toLowerCase()} se forme.`, { x: to.x, y: to.y });
}

export function animalPopulation(state, species) {
  return Math.round(state.herds.filter((h) => h.species === species).reduce((a, h) => a + h.count, 0));
}
