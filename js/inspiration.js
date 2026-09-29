import { TECHS, TECH_ORDER, prerequisitesMet } from './techTree.js';
import { IDEAS_EARLY } from './ideasEarly.js';
import { IDEAS_LATE } from './ideasLate.js';
import { makeContext } from './context.js';
import { ageOf, ADULT_AGE } from './people.js';

export const IDEAS = { ...IDEAS_EARLY, ...IDEAS_LATE };

const MAX_DAILY_CHANCE = 0.5;
const ADULTS_REF = 15;
const MAX_CROWD_FACTOR = 2;
const NO_THINKER_FACTOR = 0.4;
const APOCALYPSE_FACTOR = 0.3;
const MAX_PEOPLE_FACTOR = 4;

function peopleFactor(state, entry) {
  const inventors = Math.min(6, entry.traits.inventif || 0);
  const curious = Math.min(8, entry.traits.curieux || 0);
  let f = Math.min(MAX_CROWD_FACTOR, 0.4 + 0.6 * Math.sqrt((entry.adults || 0) / ADULTS_REF));
  f *= 1 + 0.08 * inventors + 0.04 * curious;
  if (!inventors && !curious) f *= NO_THINKER_FACTOR;
  return Math.min(MAX_PEOPLE_FACTOR, f * (entry.mods ? entry.mods.research : 1));
}

function bestTrigger(idea, ctx) {
  let best = null;
  for (const trig of idea.triggers) {
    if (!trig.when.every((flag) => ctx.on(flag))) continue;
    if (!best || trig.spark > best.spark) best = trig;
  }
  return best;
}

function needFactor(idea, ctx) {
  let mul = 1;
  for (const n of idea.needs) if (ctx.on(n.when)) mul *= n.mul;
  return mul;
}

function thinkerWeight(p, boostJob) {
  return 1 + (p.traits.includes('inventif') ? 3 : 0) + (p.traits.includes('curieux') ? 2 : 0) + (boostJob && p.job === boostJob ? 1 : 0);
}

function pickThinker(state, rng, entry, boostJob) {
  const adults = entry.people.filter((p) => p.alive && ageOf(state, p) >= ADULT_AGE);
  if (!adults.length) return null;
  let total = 0;
  for (const p of adults) total += thinkerWeight(p, boostJob);
  let r = rng.next() * total;
  for (const p of adults) {
    r -= thinkerWeight(p, boostJob);
    if (r <= 0) return p;
  }
  return adults[adults.length - 1];
}

function discovererFor(state, rng, s, entry, key, trig, ctx) {
  const witnessId = ctx.witness(trig.when);
  const witness = witnessId != null ? entry.people.find((p) => p.id === witnessId && p.alive) : null;
  return witness || pickThinker(state, rng, entry, TECHS[key].boostJob);
}

export function tellStory(story, p, s) {
  const female = p.sex === 'F';
  return story
    .replace('{name}', () => p.name)
    .replace('{place}', () => s.name)
    .replace('{Il}', female ? 'Elle' : 'Il')
    .replace('{il}', female ? 'elle' : 'il');
}

export function stepInspiration(state, rng, census, grant) {
  let colonies = 0;
  for (const e of census.values()) if (e.s && !e.s.abandoned && e.pop >= 3) colonies += 1;
  const share = Math.max(1, colonies) ** -0.75;
  for (const entry of census.values()) {
    const s = entry.s;
    if (!s || s.abandoned || entry.pop < 3) continue;
    const ctx = makeContext(state, s, entry);
    const pf = peopleFactor(state, entry);
    const apocalypse = state.zombies && state.zombies.active;
    for (const key of TECH_ORDER) {
      if (!prerequisitesMet(s, key)) continue;
      const idea = IDEAS[key];
      const trig = bestTrigger(idea, ctx);
      if (!trig) continue;
      const factor = apocalypse && key !== 'epee' ? APOCALYPSE_FACTOR : 1;
      const chance = Math.min(MAX_DAILY_CHANCE, (trig.spark * needFactor(idea, ctx) * pf * factor * share) / idea.mean);
      if (!rng.chance(chance)) continue;
      const who = discovererFor(state, rng, s, entry, key, trig, ctx);
      if (!who) continue;
      grant(state, rng, s, key, who, null, tellStory(trig.story, who, s));
      break;
    }
  }
}
