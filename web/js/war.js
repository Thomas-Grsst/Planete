import { logEvent, plural, ofPlace } from './events.js';
import { killPerson, ageOf, ADULT_AGE } from './people.js';
import { defenseStrength } from './defense.js';
import { sameLandmass } from './regions.js';
import { hasTech } from './techTree.js';
import { chefOf } from './governance.js';
import { civById, civSettlements, civTitle, civOfTitle } from './civs.js';

const BATTLE_CHANCE = 0.02;
const FRONT_RANGE = 25;
const HOME_ADVANTAGE = 1.2;
const MAX_LOSER_DEATHS = 6;
const LOSER_SHARE = 0.2;
const CONQUEST_RATIO = 1.5;
const CONQUEST_CHANCE = 0.35;
const HOLD_DAYS = 720;

const manhattan = (ax, ay, bx, by) => Math.abs(ax - bx) + Math.abs(ay - by);

function front(state, attacker, defender) {
  let best = null;
  for (const s of civSettlements(state, attacker)) {
    for (const o of civSettlements(state, defender)) {
      const d = manhattan(s.x, s.y, o.x, o.y);
      if (d > FRONT_RANGE) continue;
      if (!sameLandmass(state.world, s.x, s.y, o.x, o.y) && !hasTech(s, 'navigation')) continue;
      if (!best || d < best.d) best = { from: s, to: o, d };
    }
  }
  return best;
}

function power(state, rng, s, entry, home) {
  const chef = chefOf(state, s);
  const fierce = chef && chef.traits.includes('agressif') ? 1.2 : 1;
  const base = Math.max(0.5, defenseStrength(state, s, entry));
  return base * fierce * (home ? HOME_ADVANTAGE : 1) * (0.7 + rng.next() * 0.6);
}

function fighters(state, entry) {
  const adults = entry.people.filter((p) => p.alive && ageOf(state, p) >= ADULT_AGE);
  const rank = (p) => (p.job === 'gardien' ? 3 : 0) + (p.traits.includes('courageux') ? 2 : 0) + (p.traits.includes('agressif') ? 1 : 0);
  return adults.sort((a, b) => rank(b) - rank(a));
}

function casualties(state, rng, entry, count) {
  const pool = fighters(state, entry).slice(0, Math.max(count * 3, 6));
  let dead = 0;
  while (dead < count && pool.length) {
    const victim = pool.splice(rng.int(0, pool.length - 1), 1)[0];
    killPerson(state, victim, 'au combat');
    dead += 1;
  }
  return dead;
}

function conquer(state, war, winnerCiv, loserCiv, s) {
  s.civId = winnerCiv.id;
  s.conqueredDay = state.day;
  winnerCiv.conquests += 1;
  const capital = s.id === loserCiv.capitalId ? ' Sa capitale est tombée !' : '';
  logEvent(state, 'conquete', `🏴 ${s.name} passe sous la bannière ${civOfTitle(winnerCiv)}.${capital}`, { x: s.x, y: s.y, civId: winnerCiv.id });
  if (!civSettlements(state, loserCiv).length) state.wars = state.wars.filter((w) => w !== war);
}

function battle(state, rng, census, war, attacker, defender) {
  const f = front(state, attacker, defender);
  if (!f) return;
  const ea = census.get(f.from.id);
  const ed = census.get(f.to.id);
  if (!ea || !ed || ea.pop < 3 || ed.pop < 1) return;
  const pa = power(state, rng, f.from, ea, false);
  const pd = power(state, rng, f.to, ed, true);
  const attackerWins = pa > pd;
  const [winEntry, loseEntry] = attackerWins ? [ea, ed] : [ed, ea];
  const ratio = Math.max(pa, pd) / Math.max(0.1, Math.min(pa, pd));
  const loserAdults = fighters(state, loseEntry).length;
  const loserDeaths = Math.min(MAX_LOSER_DEATHS, Math.max(1, Math.round(1 + ratio)), Math.ceil(loserAdults * LOSER_SHARE));
  const hero = fighters(state, winEntry)[0];
  const dead = casualties(state, rng, loseEntry, loserDeaths) + casualties(state, rng, winEntry, rng.chance(0.5) ? 1 : 0);
  war.deaths += dead;
  war.battles += 1;
  const winner = attackerWins ? attacker : defender;
  const verb = attackerWins ? `les troupes ${civOfTitle(attacker)} l'emportent` : `${f.to.name} repousse l'assaut ${civOfTitle(attacker)}`;
  const lead = hero ? `, menées par ${hero.name}` : '';
  logEvent(state, 'bataille', `⚔️ Bataille ${ofPlace(f.to.name)} : ${verb}${attackerWins ? lead : ''}. ${plural(dead, 'mort')}.`, { x: f.to.x, y: f.to.y, civId: winner.id, personId: hero ? hero.id : undefined });
  const held = f.to.conqueredDay != null && state.day - f.to.conqueredDay < HOLD_DAYS;
  if (attackerWins && !held && ratio >= CONQUEST_RATIO && ed.pop - dead < ea.pop && rng.chance(CONQUEST_CHANCE)) conquer(state, war, attacker, defender, f.to);
}

export function stepWars(state, rng, census) {
  for (const war of state.wars.slice()) {
    const a = civById(state, war.a);
    const b = civById(state, war.b);
    if (!a || !b || !a.alive || !b.alive) { state.wars = state.wars.filter((w) => w !== war); continue; }
    if (!rng.chance(BATTLE_CHANCE)) continue;
    const [attacker, defender] = rng.chance(0.6) ? [a, b] : [b, a];
    battle(state, rng, census, war, attacker, defender);
  }
}

export function warLine(state, war) {
  const a = civById(state, war.a);
  const b = civById(state, war.b);
  if (!a || !b) return '';
  return `⚔️ ${civTitle(a, true)} contre ${civTitle(b)} · ${plural(state.day - war.startDay, 'jour')} · ${plural(war.battles, 'bataille')} · ${plural(war.deaths, 'mort')}`;
}
