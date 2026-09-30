import { FAITH_SOURCES, SCHISM_NAMES, FAITH_COLORS } from './faithData.js';
import { ofPlace } from './events.js';

const LEGEND_CAP = 60;
const RELIGION_LEGEND_CAP = 20;
const FOUNDING_DEVOTION = 60;

export function ensureFaithState(state) {
  state.religions ??= [];
  state.legends ??= [];
  for (const s of state.settlements) {
    s.faithId ??= null;
    s.devotion ??= 0;
    s.temple ??= 0;
    s.prayer ??= null;
    s.awe ??= null;
  }
  for (const civ of state.civs || []) civ.religionId ??= null;
}

export const religionById = (state, id) => (id == null ? null : (state.religions || []).find((r) => r.id === id) || null);
export const aliveReligions = (state) => (state.religions || []).filter((r) => r.alive);
export const isPlayerFaith = (rel) => !!rel && !!FAITH_SOURCES[rel.source] && FAITH_SOURCES[rel.source].player;
export const legendById = (state, id) => (state.legends || []).find((l) => l.id === id) || null;

export function religionOf(state, s) {
  const rel = s ? religionById(state, s.faithId) : null;
  return rel && rel.alive ? rel : null;
}

export function faithSettlements(state, rel) {
  return state.settlements.filter((s) => !s.abandoned && s.faithId === rel.id);
}

export function religionPopulation(state, rel) {
  const ids = new Set(faithSettlements(state, rel).map((s) => s.id));
  let pop = 0;
  for (const p of state.people) if (p.alive && ids.has(p.homeId)) pop += 1;
  return pop;
}

function pickName(state, rng, source, s, parent) {
  if (parent) return `${rng.pick(SCHISM_NAMES)} ${ofPlace(s.name)}`;
  const used = new Set(state.religions.map((r) => r.name));
  const free = FAITH_SOURCES[source].names.filter((n) => !used.has(n));
  return free.length ? rng.pick(free) : `${FAITH_SOURCES[source].names[0]} ${ofPlace(s.name)}`;
}

export function createReligion(state, rng, s, prophet, source, parent = null) {
  const def = FAITH_SOURCES[source];
  const rel = {
    id: state.nextId++, name: pickName(state, rng, source, s, parent), source, emoji: def.emoji,
    deity: parent ? parent.deity : def.deity,
    color: parent ? FAITH_COLORS[state.religions.length % FAITH_COLORS.length] : def.color,
    holyId: s.id, holyName: s.name, founderId: prophet.id, founderName: prophet.name, foundedDay: state.day,
    parentId: parent ? parent.id : null, alive: true, fallDay: null, prophetGone: null,
    legendIds: parent ? parent.legendIds.slice() : [], originLegendId: null,
  };
  if (!parent && def.player && s.awe && s.awe.legendId != null) {
    rel.legendIds.push(s.awe.legendId);
    rel.originLegendId = s.awe.legendId;
  }
  state.religions.push(rel);
  adoptFaith(s, rel, FOUNDING_DEVOTION);
  prophet.prophetOf = rel.id;
  s.awe = null;
  return rel;
}

export function adoptFaith(s, rel, devotion) {
  s.faithId = rel.id;
  s.devotion = devotion;
}

export function leaveFaith(s) {
  s.faithId = null;
  s.devotion = 0;
}

export function rememberLegend(state, legend) {
  state.legends.push(legend);
  if (state.legends.length > LEGEND_CAP) state.legends.splice(0, state.legends.length - LEGEND_CAP);
  for (const rel of aliveReligions(state)) {
    if (!isPlayerFaith(rel)) continue;
    rel.legendIds.push(legend.id);
    if (rel.legendIds.length > RELIGION_LEGEND_CAP) rel.legendIds.shift();
  }
}

export function faithMods(state, s) {
  const rel = religionOf(state, s);
  if (!rel) return { happiness: 0, defense: 1 };
  const fervor = Math.max(0, Math.min(100, s.devotion)) / 100;
  if (rel.source === 'zombie') return { happiness: -0.01, defense: 1 + 0.15 * fervor };
  return { happiness: 0.03 * fervor, defense: 1 };
}
