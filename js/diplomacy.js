import { logEvent, plural, ofPlace } from './events.js';
import { hasTech, prerequisitesMet } from './techTree.js';
import { chefOf } from './governance.js';
import { ageOf, ADULT_AGE } from './people.js';
import { grantTech } from './technology.js';
import { aliveCivs, civSettlements, civTitle, civToTitle, relationOf, warBetween, civById } from './civs.js';

const DECAY = 0.998;
const CLOSE_BORDER = 10;
const BORDER = 16;
const TRADE_RANGE = 22;
const WAR_THRESHOLD = -50;
const WAR_CHANCE = 0.01;
const TRADE_THRESHOLD = 40;
const ALLIANCE_THRESHOLD = 70;
const PACT_CHANCE = 0.01;
const ALLIANCE_CHANCE = 0.005;
const BREAK_THRESHOLD = 10;
const TRUCE_DAYS = 1800;
const PEACE_MIN_DAYS = 120;
const TRADE_TECH_CHANCE = 0.003;

const manhattan = (ax, ay, bx, by) => Math.abs(ax - bx) + Math.abs(ay - by);
const clamp = (v) => Math.max(-100, Math.min(100, v));

function distance(state, a, b) {
  let best = Infinity;
  for (const s of civSettlements(state, a)) for (const o of civSettlements(state, b)) best = Math.min(best, manhattan(s.x, s.y, o.x, o.y));
  return best;
}

const capitalOf = (state, civ) => state.settlements.find((s) => s.id === civ.capitalId) || civSettlements(state, civ)[0];
const chefTrait = (state, civ, trait) => { const c = capitalOf(state, civ); const chef = c && chefOf(state, c); return !!chef && chef.traits.includes(trait); };
const trades = (state, civ) => civSettlements(state, civ).some((s) => hasTech(s, 'roue') || hasTech(s, 'navigation'));
const lawful = (state, civ) => civSettlements(state, civ).some((s) => hasTech(s, 'lois'));

function drift(state, rng, a, b, rel, d) {
  let delta = 0;
  if (d < CLOSE_BORDER) delta -= 0.12;
  else if (d < BORDER) delta -= 0.05;
  if (d < TRADE_RANGE && trades(state, a) && trades(state, b)) delta += 0.06;
  for (const c of [a, b]) {
    if (chefTrait(state, c, 'agressif')) delta -= 0.07;
    if (chefTrait(state, c, 'sociable')) delta += 0.04;
  }
  if (lawful(state, a) && lawful(state, b)) delta += 0.02;
  if (rel.pact) delta += 0.03;
  rel.score = clamp(rel.score * DECAY + delta + (rng.next() - 0.5) * 0.3);
}

function sentence(a, b) {
  return `${civTitle(a, true)} et ${civTitle(b)}`;
}

function declareWar(state, rng, a, b, d) {
  const [attacker, defender] = chefTrait(state, b, 'agressif') && !chefTrait(state, a, 'agressif') ? [b, a] : [a, b];
  const capital = capitalOf(state, attacker);
  const chef = capital && chefOf(state, capital);
  const why = chef && chef.traits.includes('agressif') ? `sous l'impulsion ${ofPlace(chef.name)}` : d < CLOSE_BORDER ? 'pour des terres frontalières' : 'après des années de méfiance';
  state.wars.push({ id: state.nextId++, a: attacker.id, b: defender.id, startDay: state.day, deaths: 0, battles: 0 });
  logEvent(state, 'guerre', `⚔️ ${civTitle(attacker, true)} déclare la guerre ${civToTitle(defender)}, ${why} !`, { x: capital ? capital.x : undefined, y: capital ? capital.y : undefined, civId: attacker.id });
}

function tryPeace(state, rng, war, rel) {
  const a = civById(state, war.a);
  const b = civById(state, war.b);
  const length = state.day - war.startDay;
  if (length < PEACE_MIN_DAYS) return;
  const chance = 0.003 + war.deaths * 0.0004 + (length > 720 ? 0.01 : 0);
  if (!rng.chance(chance)) return;
  state.wars = state.wars.filter((w) => w !== war);
  rel.score = -10;
  rel.truceUntil = state.day + TRUCE_DAYS;
  logEvent(state, 'paix', `🕊️ ${sentence(a, b)} signent la paix après ${plural(length, 'jour')} de guerre et ${plural(war.deaths, 'mort')}.`, { civId: a.id });
}

function updatePact(state, rng, a, b, rel) {
  if (rel.pact && rel.score < BREAK_THRESHOLD) {
    logEvent(state, 'rupture', `💔 ${rel.pact === 'alliance' ? 'L\'alliance' : 'La route commerciale'} entre ${civTitle(a)} et ${civTitle(b)} est rompue.`, { civId: a.id });
    rel.pact = null;
    return;
  }
  if (!rel.pact && rel.score > TRADE_THRESHOLD && trades(state, a) && trades(state, b) && rng.chance(PACT_CHANCE)) {
    rel.pact = 'commerce';
    logEvent(state, 'commerce', `🐪 ${sentence(a, b)} ouvrent une route commerciale.`, { civId: a.id });
  } else if (rel.pact === 'commerce' && rel.score > ALLIANCE_THRESHOLD && rng.chance(ALLIANCE_CHANCE)) {
    rel.pact = 'alliance';
    logEvent(state, 'alliance', `🤝 ${sentence(a, b)} scellent une alliance.`, { civId: a.id });
  }
}

function tradeKnowledge(state, rng, census, a, b) {
  if (!rng.chance(TRADE_TECH_CHANCE)) return;
  const [from, to] = rng.chance(0.5) ? [a, b] : [b, a];
  const source = capitalOf(state, from);
  const target = capitalOf(state, to);
  if (!source || !target) return;
  const pool = (source.techs || []).filter((k) => prerequisitesMet(target, k));
  const entry = census.get(target.id);
  if (!pool.length || !entry) return;
  const adults = entry.people.filter((p) => p.alive && ageOf(state, p) >= ADULT_AGE);
  grantTech(state, rng, target, rng.pick(pool), null, source, null, adults.length ? rng.pick(adults) : null);
}

export function stepDiplomacy(state, rng, census) {
  const civs = aliveCivs(state);
  for (let i = 0; i < civs.length; i++) {
    for (let j = i + 1; j < civs.length; j++) {
      const a = civs[i];
      const b = civs[j];
      const rel = relationOf(state, a, b);
      const d = distance(state, a, b);
      drift(state, rng, a, b, rel, d);
      const war = warBetween(state, a, b);
      if (war) { tryPeace(state, rng, war, rel); continue; }
      if (rel.score < WAR_THRESHOLD && state.day >= rel.truceUntil && d < BORDER + 6 && rng.chance(WAR_CHANCE)) {
        if (rel.pact) rel.pact = null;
        declareWar(state, rng, a, b, d);
        continue;
      }
      updatePact(state, rng, a, b, rel);
      if (rel.pact) tradeKnowledge(state, rng, census, a, b);
    }
  }
}

export function relationLabel(state, a, b) {
  if (warBetween(state, a, b)) return '⚔️ en guerre';
  const rel = relationOf(state, a, b);
  if (rel.pact === 'alliance') return '🤝 allié';
  if (rel.pact === 'commerce') return '🐪 partenaire commercial';
  if (rel.score <= -30) return '😠 hostile';
  if (rel.score >= 30) return '🙂 cordial';
  return '😐 neutre';
}
