import { ageOf, ADULT_AGE } from './people.js';
import { tileAt } from './world.js';
import { techMods } from './techTree.js';
import { governanceMods } from './governance.js';
import { faithMods } from './religions.js';

const HUNGRY_ABOVE = 30;
const MAX_DEFENSE_MULT = 1.8;
const WOLF_REACH = 4;
const HERD_REACH = 5;
const HERD_MIN_COUNT = 4;
const WATER_BIOMES = { ocean: true, lake: true, river: true };
const COAST_BIOMES = { ocean: true, lake: true };

const emptyTraits = () => ({ curieux: 0, courageux: 0, agressif: 0, sociable: 0, travailleur: 0, inventif: 0, prudent: 0, aventurier: 0 });

const clamp = (v, min, max) => Math.max(min, Math.min(max, v));

function emptyEntry(s, mods) {
  return {
    s, people: [], pop: 0, adults: 0, kids: 0, jobs: {}, traits: emptyTraits(),
    sick: 0, bitten: 0, hungry: 0, chef: null, wolfNear: false, herdNear: false, density: 1, mods,
  };
}

export function settlementGeo(world, x, y) {
  const geo = { water: 0, coast: false, swamp: 0, mountain: 0 };
  for (let dy = -5; dy <= 5; dy++) {
    for (let dx = -5; dx <= 5; dx++) {
      const t = tileAt(world, x + dx, y + dy);
      if (!t) continue;
      const cheb = Math.max(Math.abs(dx), Math.abs(dy));
      if (t.biome === 'mountain') geo.mountain += 1;
      if (cheb > 3) continue;
      if (t.biome === 'swamp') geo.swamp += 1;
      if (cheb > 2) continue;
      if (WATER_BIOMES[t.biome]) geo.water += 1;
      if (COAST_BIOMES[t.biome]) geo.coast = true;
    }
  }
  return geo;
}

export function buildCensus(state) {
  const census = new Map();
  for (const s of state.settlements) {
    if (!s.geo) s.geo = settlementGeo(state.world, s.x, s.y);
    census.set(s.id, emptyEntry(s, null));
  }
  countPeople(state, census);
  markAnimals(state, census);
  for (const e of census.values()) {
    e.mods = composeMods(state, e);
    e.density = clamp(e.pop / Math.max(1, e.s.houses * e.mods.capacity), 0.5, 3);
  }
  return census;
}

function countPeople(state, census) {
  for (const p of state.people) {
    if (!p.alive) continue;
    const e = census.get(p.homeId);
    if (!e) continue;
    e.people.push(p);
    e.pop += 1;
    if (ageOf(state, p) >= ADULT_AGE) {
      e.adults += 1;
      for (const t of p.traits) if (e.traits[t] !== undefined) e.traits[t] += 1;
    } else {
      e.kids += 1;
    }
    e.jobs[p.job] = (e.jobs[p.job] || 0) + 1;
    if (p.sick) e.sick += 1;
    if (p.bitten != null) e.bitten += 1;
    if (p.hunger > HUNGRY_ABOVE) e.hungry += 1;
    if (p.id === e.s.chefId) e.chef = p;
  }
}

function markAnimals(state, census) {
  for (const h of state.herds) {
    const wolf = h.species === 'wolf';
    if (!wolf && h.count < HERD_MIN_COUNT) continue;
    const reach = wolf ? WOLF_REACH : HERD_REACH;
    for (const e of census.values()) {
      if (Math.abs(h.x - e.s.x) + Math.abs(h.y - e.s.y) > reach) continue;
      if (wolf) e.wolfNear = true;
      else e.herdNear = true;
    }
  }
}

function composeMods(state, e) {
  const m = techMods(e.s);
  applyJobMods(m, e.jobs);
  const gm = governanceMods(e.s, e.chef, e.pop);
  const fm = faithMods(state, e.s);
  m.happiness += gm.happiness + fm.happiness;
  m.defense *= fm.defense;
  m.buildChance *= gm.buildChance;
  m.defense *= gm.defense;
  m.research *= gm.research;
  m.outbreak *= gm.outbreak;
  m.defense = Math.min(MAX_DEFENSE_MULT, m.defense);
  return m;
}

function applyJobMods(m, jobs) {
  if ((jobs.forgeron || 0) >= 1) {
    m.defense *= 1.2;
    m.hunt *= 1.2;
    m.buildCost = Math.max(4, m.buildCost - 1);
  }
  const healers = Math.min(3, jobs['guérisseur'] || 0);
  if (healers > 0) {
    m.care *= 1 - 0.1 * healers;
    m.contagion *= 1 - 0.1 * healers;
    m.outbreak *= 1 - 0.08 * healers;
  }
}
