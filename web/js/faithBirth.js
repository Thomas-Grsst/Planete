import { FAITH_SOURCES, tellFaith, ofName } from './faithData.js';
import { logEvent, ofPlace } from './events.js';
import { ageOf } from './people.js';
import { hasTech } from './techTree.js';
import { createReligion, aliveReligions, faithSettlements, legendById, adoptFaith } from './religions.js';

const MAX_RELIGIONS = 6;
const MAX_WITH_SCHISMS = 8;
const AWE_DAYS = 360;
const ANSWERED_CHANCE = 0.04;
const WITNESS_CHANCE = 0.0004;
const ECHO_FACTOR = 0.15;
const STORM_CHANCE = 0.0003;
const GRIEF_CHANCE = 0.002;
const GRIEF_DEATHS = 3;
const ANCESTORS_CHANCE = 0.0001;
const ANCESTORS_AGE_DAYS = 3600;
const BIRTH_MIN_POP = 10;
const NATURAL_MIN_POP = 20;
const PROPHET_MIN_AGE = 20;
const CONVERT_CHANCE = 0.03;
const JOIN_DEVOTION = 55;
const SCHISM_MIN_AGE_DAYS = 3600;
const SCHISM_RANGE = 16;
const SCHISM_CHANCE = 0.00008;
const SCHISM_MIN_POP = 20;
const SCHISM_MIN_DEVOTION = 30;
const SCHISM_FOLLOW_CHANCE = 0.5;

const prophetWeight = (p) => 1 + (p.traits.includes('sociable') ? 3 : 0) + (p.traits.includes('curieux') ? 2 : 0) + (p.traits.includes('prudent') ? 1 : 0);

function pickProphet(state, rng, entry) {
  const adults = entry.people.filter((p) => p.alive && p.prophetOf == null && ageOf(state, p) >= PROPHET_MIN_AGE);
  if (!adults.length) return null;
  let total = 0;
  for (const p of adults) total += prophetWeight(p);
  let r = rng.next() * total;
  for (const p of adults) {
    r -= prophetWeight(p);
    if (r <= 0) return p;
  }
  return adults[adults.length - 1];
}

function aweOrigin(state, s) {
  const awe = s.awe;
  if (!awe || state.day - awe.day > AWE_DAYS) return null;
  if (awe.answered) return { source: awe.kind, chance: ANSWERED_CHANCE };
  const echoed = aliveReligions(state).some((r) => r.legendIds.includes(awe.legendId));
  return { source: awe.kind, chance: WITNESS_CHANCE * (echoed ? ECHO_FACTOR : 1) };
}

function naturalOrigin(state, s, entry) {
  if (entry.pop < NATURAL_MIN_POP || !hasTech(s, 'feu')) return null;
  if (s.outbreak && s.outbreak.deaths >= GRIEF_DEATHS) return { source: 'ancestors', chance: GRIEF_CHANCE };
  if (state.weather === 'storm') return { source: 'storm', chance: STORM_CHANCE };
  if (state.day - s.foundedDay >= ANCESTORS_AGE_DAYS) return { source: 'ancestors', chance: ANCESTORS_CHANCE };
  return null;
}

function found(state, rng, s, entry, source, intro = '') {
  const prophet = pickProphet(state, rng, entry);
  if (!prophet) return null;
  const legend = s.awe ? legendById(state, s.awe.legendId) : null;
  const rel = createReligion(state, rng, s, prophet, source);
  const story = tellFaith(FAITH_SOURCES[source].founding, prophet, s, { religion: rel.name, deity: rel.deity, legend: legend ? legend.name : null });
  logEvent(state, 'religion', `${intro}${story}`, { x: s.x, y: s.y, personId: prophet.id });
  return rel;
}

function joinSibling(state, s, old) {
  const legendId = s.awe ? s.awe.legendId : null;
  const sibling = legendId == null ? null : aliveReligions(state).find((r) => r.originLegendId === legendId);
  if (!sibling) return false;
  const legend = legendById(state, legendId);
  adoptFaith(s, sibling, JOIN_DEVOTION);
  s.convertedDay = state.day;
  s.awe = null;
  const leaving = old ? `, abandonnant ${old.name}` : '';
  logEvent(state, 'conversion', `✨ Après ${legend ? legend.name : 'le miracle'}, ${s.name} rejoint ${sibling.name}${leaving}.`, { x: s.x, y: s.y });
  return true;
}

export function tryBirth(state, rng, s, entry) {
  if (entry.pop < BIRTH_MIN_POP) return;
  const origin = aweOrigin(state, s) || naturalOrigin(state, s, entry);
  if (!origin || !rng.chance(origin.chance)) return;
  if (s.awe && joinSibling(state, s, null)) return;
  if (aliveReligions(state).length < MAX_RELIGIONS) found(state, rng, s, entry, origin.source);
}

export function tryConversionByMiracle(state, rng, s, entry, rel) {
  const awe = s.awe;
  if (!awe || !awe.answered || state.day - awe.day > AWE_DAYS || !rng.chance(CONVERT_CHANCE)) return false;
  if (joinSibling(state, s, rel)) return true;
  if (aliveReligions(state).length >= MAX_WITH_SCHISMS) return false;
  return !!found(state, rng, s, entry, awe.kind, `✨ Après le miracle, ${s.name} abandonne ${rel.name}. `);
}

function isFarFromHoly(state, s, rel) {
  const holy = state.settlements.find((o) => o.id === rel.holyId);
  if (!holy) return true;
  if (s.civId != null && holy.civId !== s.civId) return true;
  return Math.abs(holy.x - s.x) + Math.abs(holy.y - s.y) > SCHISM_RANGE;
}

export function trySchism(state, rng, s, entry, rel) {
  if (s.id === rel.holyId || entry.pop < SCHISM_MIN_POP || s.devotion < SCHISM_MIN_DEVOTION) return;
  if (state.day - rel.foundedDay < SCHISM_MIN_AGE_DAYS || !rng.chance(SCHISM_CHANCE)) return;
  if (!isFarFromHoly(state, s, rel) || aliveReligions(state).length >= MAX_WITH_SCHISMS) return;
  const members = faithSettlements(state, rel);
  if (members.length < 3) return;
  const prophet = pickProphet(state, rng, entry);
  if (!prophet) return;
  const schism = createReligion(state, rng, s, prophet, rel.source, rel);
  const followers = members.filter((o) => o !== s && o.id !== rel.holyId && s.civId != null && o.civId === s.civId && rng.chance(SCHISM_FOLLOW_CHANCE));
  for (const o of followers) { adoptFaith(o, schism, o.devotion); o.convertedDay = state.day; }
  s.convertedDay = state.day;
  const also = followers.length ? ` ${followers.map((o) => o.name).join(', ')} ${followers.length > 1 ? 'suivent' : 'suit'} le mouvement.` : '';
  const text = `⚡ Schisme ! À ${s.name}, ${prophet.name} rejette l'autorité ${ofPlace(rel.holyName)} : ${schism.name} se séparent ${ofName(rel.name)}.${also}`;
  logEvent(state, 'schisme', text, { x: s.x, y: s.y, personId: prophet.id });
}
