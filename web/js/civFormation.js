import { logEvent } from './events.js';
import { levelIndexOf } from './settlements.js';
import { sameLandmass } from './regions.js';
import { hasTech } from './techTree.js';
import { createCiv, joinCiv, civById, civTitle, civOfTitle, aliveCivs, civSettlements } from './civs.js';

const CIV_MIN_POP = 30;
const CIV_MIN_LEVEL = 2;
const FOUND_CHANCE = 0.01;
const JOIN_RANGE = 12;
const JOIN_CHANCE = 0.004;
const SECESSION_RANGE = 16;
const SECESSION_CHANCE = 0.0004;
const CONQUERED_UNREST = 3;
const CONQUERED_MEMORY_DAYS = 3600;
const CULTURE_BASE = 0.0008;

const manhattan = (ax, ay, bx, by) => Math.abs(ax - bx) + Math.abs(ay - by);

function reachable(state, a, b) {
  return sameLandmass(state.world, a.x, a.y, b.x, b.y) || hasTech(a, 'navigation') || hasTech(b, 'navigation');
}

function canFound(s, entry) {
  return entry.pop >= CIV_MIN_POP && !!entry.chef && levelIndexOf(s.level) >= CIV_MIN_LEVEL;
}

function proclaim(state, s, entry) {
  const civ = createCiv(state, s, entry.chef);
  const who = entry.chef ? `Sous la conduite de ${entry.chef.name}, ` : '';
  const text = `🏰 ${who}${who ? civTitle(civ) : civTitle(civ, true)} est proclamé${civ.article === 'la' ? 'e' : ''} à ${s.name}.`;
  logEvent(state, 'civilisation', text, { x: s.x, y: s.y, civId: civ.id, personId: entry.chef ? entry.chef.id : undefined });
  return civ;
}

function nearestCivSettlement(state, s) {
  let best = null;
  let bestD = JOIN_RANGE + 1;
  for (const o of state.settlements) {
    if (o === s || o.abandoned || o.civId == null) continue;
    const d = manhattan(o.x, o.y, s.x, s.y);
    if (d < bestD && reachable(state, o, s)) { bestD = d; best = o; }
  }
  return best;
}

function stepUnaffiliated(state, rng, s, entry) {
  if (canFound(s, entry) && rng.chance(FOUND_CHANCE)) { proclaim(state, s, entry); return; }
  const near = nearestCivSettlement(state, s);
  if (!near) return;
  const small = entry.pop < CIV_MIN_POP ? 2 : 1;
  if (rng.chance(JOIN_CHANCE * small)) joinCiv(state, s, civById(state, near.civId));
}

function stepMember(state, rng, s, entry, civ) {
  const capital = state.settlements.find((c) => c.id === civ.capitalId);
  if (!capital || capital === s || !canFound(s, entry)) return;
  const far = manhattan(capital.x, capital.y, s.x, s.y) > SECESSION_RANGE || !reachable(state, capital, s);
  const conquered = s.conqueredDay != null && state.day - s.conqueredDay < CONQUERED_MEMORY_DAYS;
  const unrest = (far ? 1 : 0) + (conquered ? CONQUERED_UNREST : 0) + (entry.chef && entry.chef.traits.includes('agressif') ? 1 : 0);
  if (!unrest || !rng.chance(SECESSION_CHANCE * unrest)) return;
  const newCiv = createCiv(state, s, entry.chef);
  const cause = conquered ? `${s.name} refuse le joug` : `${s.name}, trop loin de sa capitale, se détache`;
  logEvent(state, 'independance', `✊ ${cause} ${civOfTitle(civ)} et proclame son indépendance : naissance ${civOfTitle(newCiv)}.`, { x: s.x, y: s.y, civId: newCiv.id });
}

function stepCivLife(state, civ, census) {
  const members = civSettlements(state, civ);
  if (!members.length) {
    civ.alive = false;
    civ.fallDay = state.day;
    logEvent(state, 'chute', `🏚️ ${civTitle(civ, true)} disparaît de l'histoire, ${Math.floor((state.day - civ.foundedDay) / 360)} ans après sa fondation.`, { civId: civ.id });
    state.wars = state.wars.filter((w) => w.a !== civ.id && w.b !== civ.id);
    return;
  }
  if (!members.some((s) => s.id === civ.capitalId)) {
    const next = members.reduce((best, s) => ((census.get(s.id)?.pop || 0) > (census.get(best.id)?.pop || 0) ? s : best), members[0]);
    civ.capitalId = next.id;
    logEvent(state, 'civilisation', `🏰 ${next.name} devient la nouvelle capitale ${civOfTitle(civ)}.`, { x: next.x, y: next.y, civId: civ.id });
  }
  let pop = 0;
  let learned = 1;
  for (const s of members) {
    pop += census.get(s.id)?.pop || 0;
    if (hasTech(s, 'ecriture')) learned = Math.max(learned, 2);
    if (hasTech(s, 'architecture')) learned = Math.max(learned, 3);
  }
  civ.culture = Math.min(100, civ.culture + CULTURE_BASE * learned * Math.sqrt(pop) / Math.max(1, civ.culture / 20));
}

export function stepCivs(state, rng, census) {
  for (const entry of census.values()) {
    const s = entry.s;
    if (!s || s.abandoned || entry.pop <= 0) continue;
    const civ = civById(state, s.civId);
    if (civ && !civ.alive) s.civId = null;
    if (s.civId == null) stepUnaffiliated(state, rng, s, entry);
    else stepMember(state, rng, s, entry, civ);
  }
  for (const civ of aliveCivs(state)) stepCivLife(state, civ, census);
}
