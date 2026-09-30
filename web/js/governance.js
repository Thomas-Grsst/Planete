import { logEvent, ofPlace } from './events.js';
import { ageOf } from './people.js';
import { hasTech } from './techTree.js';

const CHEF_MIN_POP = 25;
const CHEF_MIN_AGE_DAYS = 360;

const weightedPick = (rng, items, weightOf) => {
  let total = 0;
  for (const it of items) total += weightOf(it);
  let r = rng.next() * total;
  for (const it of items) { r -= weightOf(it); if (r <= 0) return it; }
  return items[items.length - 1];
};

const has = (p, trait) => p.traits.includes(trait);

const chefWeight = (p) => 1 + (has(p, 'sociable') ? 2 : 0) + (has(p, 'courageux') ? 1.5 : 0) + (has(p, 'travailleur') ? 0.5 : 0);

const councilWeight = (p) => 1 + (has(p, 'sociable') ? 2 : 0) + (has(p, 'prudent') ? 1 : 0) + (has(p, 'curieux') ? 1 : 0);

export function ensureGovernanceState(state) {
  for (const s of state.settlements) {
    s.chefId ??= null;
    s.chefSince ??= 0;
    s.chefVacantUntil ??= 0;
    s.council ??= [];
    s.councilFormedDay ??= null;
  }
}

export function governanceMods(s, chef, pop) {
  const council = (s.council || []).length >= 3;
  const mods = { happiness: 0, buildChance: 1, defense: 1, research: council ? 1.2 : 1, outbreak: council ? 0.9 : 1 };
  if (chef) {
    mods.happiness = 0.05 + (has(chef, 'sociable') ? 0.05 : 0) - (has(chef, 'agressif') ? 0.05 : 0);
    mods.buildChance = has(chef, 'travailleur') ? 1.6 : 1.3;
    mods.defense = has(chef, 'agressif') ? 1.3 : has(chef, 'courageux') ? 1.15 : 1;
  } else if (pop >= CHEF_MIN_POP) {
    mods.happiness = -0.03;
  }
  return mods;
}

export function chefOf(state, s) {
  if (s.chefId == null) return null;
  const p = state.people.find((q) => q.id === s.chefId);
  return p && p.alive && p.homeId === s.id ? p : null;
}

export function electChef(state, rng, s, entry) {
  const candidates = entry.people.filter((p) => p.alive && p.job !== 'enfant' && p.job !== 'chef' && ageOf(state, p) >= 20);
  if (!candidates.length) return null;
  const p = weightedPick(rng, candidates, chefWeight);
  p.job = 'chef';
  p.jobDay = state.day;
  s.chefId = p.id;
  s.chefSince = state.day;
  logEvent(state, 'chef', electionText(p, s), { x: s.x, y: s.y, personId: p.id });
  return p;
}

function electionText(p, s) {
  const female = p.sex === 'F';
  const title = female ? 'cheffe' : 'chef';
  if (has(p, 'sociable')) return `👑 ${p.name}, ${female ? 'aimée' : 'aimé'} de tous, devient ${title} ${ofPlace(s.name)}.`;
  if (has(p, 'courageux')) return `👑 ${p.name}, ${female ? 'la courageuse' : 'le courageux'}, devient ${title} ${ofPlace(s.name)}.`;
  if (has(p, 'agressif')) return `👑 ${p.name} prend le pouvoir à ${s.name}.`;
  return `👑 ${p.name} devient ${title} ${ofPlace(s.name)}.`;
}

export function stepGovernance(state, rng, census) {
  for (const entry of census.values()) {
    const s = entry.s;
    if (!s || s.abandoned || entry.pop <= 0) continue;
    const chef = entry.chef && entry.chef.alive && entry.chef.homeId === s.id ? entry.chef : null;
    if (s.chefId != null && !chef) loseChef(state, rng, s, entry.chef);
    if (s.chefId == null && entry.pop >= CHEF_MIN_POP && state.day - s.foundedDay >= CHEF_MIN_AGE_DAYS && (state.day >= s.chefVacantUntil || hasTech(s, 'lois'))) {
      const elected = electChef(state, rng, s, entry);
      if (elected) s.council = s.council.filter((id) => id !== elected.id);
    }
    stepCouncil(state, rng, s, entry);
  }
}

function loseChef(state, rng, s, known) {
  const p = known && known.id === s.chefId ? known : state.people.find((q) => q.id === s.chefId) || null;
  if (p && p.alive) {
    if (p.job === 'chef') { p.job = 'cueilleur'; p.jobDay = state.day; }
    logEvent(state, 'chef', `👑 ${p.name} quitte ${s.name} ; la colonie n'a plus de chef.`, { x: s.x, y: s.y, personId: p.id });
  } else {
    const title = p && p.sex === 'F' ? 'sa cheffe' : 'son chef';
    logEvent(state, 'chef', `👑 ${s.name} pleure ${title}${p ? ` ${p.name}` : ''}.`, { x: s.x, y: s.y });
  }
  s.chefId = null;
  s.chefVacantUntil = state.day + rng.int(10, 30);
}

function stepCouncil(state, rng, s, entry) {
  if (s.council.length) {
    const ids = new Set();
    for (const p of entry.people) if (p.alive) ids.add(p.id);
    s.council = s.council.filter((id) => ids.has(id));
  }
  if (entry.pop < 50) return;
  const seats = hasTech(s, 'lois') ? 5 : 3;
  if (s.council.length < seats && rng.chance(0.03)) {
    const candidates = entry.people.filter((p) => p.alive && p.id !== s.chefId && !s.council.includes(p.id) && ageOf(state, p) >= 25);
    if (candidates.length) s.council.push(weightedPick(rng, candidates, councilWeight).id);
  }
  if (s.council.length >= 3 && s.councilFormedDay === null) {
    s.councilFormedDay = state.day;
    logEvent(state, 'conseil', `🏛️ Un conseil de sages se forme à ${s.name} : ${councilNames(entry, s.council)}.`, { x: s.x, y: s.y });
  }
}

function councilNames(entry, ids) {
  const names = ids.map((id) => entry.people.find((p) => p.id === id)).filter(Boolean).map((p) => p.name);
  if (names.length <= 1) return names.join('');
  return `${names.slice(0, -1).join(', ')} et ${names[names.length - 1]}`;
}
