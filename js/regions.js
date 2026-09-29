import { SIZE, tileAt, isWalkable } from './world.js';

const NO_REGION = -1;
const STEPS = [[-1, 0], [1, 0], [0, -1], [0, 1]];
const regionCache = new WeakMap();

export function regionsOf(world) {
  let regions = regionCache.get(world);
  if (!regions) {
    regions = computeRegions(world);
    regionCache.set(world, regions);
  }
  return regions;
}

export function regionAt(world, x, y) {
  if (x < 0 || y < 0 || x >= SIZE || y >= SIZE) return NO_REGION;
  return regionsOf(world)[y * SIZE + x];
}

export function sameLandmass(world, ax, ay, bx, by) {
  const a = regionAt(world, ax, ay);
  return a >= 0 && a === regionAt(world, bx, by);
}

export function isCoastal(world, x, y) {
  for (let dy = -2; dy <= 2; dy++) {
    for (let dx = -2; dx <= 2; dx++) {
      const t = tileAt(world, x + dx, y + dy);
      if (t && (t.biome === 'ocean' || t.biome === 'lake')) return true;
    }
  }
  return false;
}

function computeRegions(world) {
  const regions = new Int16Array(SIZE * SIZE).fill(NO_REGION);
  const stack = new Int32Array(SIZE * SIZE);
  let nextRegion = 0;
  for (let start = 0; start < regions.length; start++) {
    if (regions[start] !== NO_REGION) continue;
    if (!isWalkable(world, start % SIZE, Math.floor(start / SIZE))) continue;
    fillFrom(world, regions, stack, start, nextRegion);
    nextRegion += 1;
  }
  return regions;
}

function fillFrom(world, regions, stack, start, region) {
  let top = 0;
  stack[top++] = start;
  regions[start] = region;
  while (top > 0) {
    const i = stack[--top];
    const x = i % SIZE;
    const y = (i - x) / SIZE;
    for (const [dx, dy] of STEPS) {
      const nx = x + dx;
      const ny = y + dy;
      if (!isWalkable(world, nx, ny)) continue;
      const j = ny * SIZE + nx;
      if (regions[j] !== NO_REGION) continue;
      regions[j] = region;
      stack[top++] = j;
    }
  }
}
