import { logEvent, logPersonal } from './events.js';
import { ageOf, ADULT_AGE } from './people.js';
import { TECHS, hasTech } from './techTree.js';

export const JOBS = {
  enfant: { emoji: '🧒', label: 'enfant', fem: 'enfant', tech: null, water: false, traits: [], locked: true },
  cueilleur: { emoji: '🌿', label: 'cueilleur', fem: 'cueilleuse', tech: null, water: false, traits: ['prudent'], locked: false },
  fermier: { emoji: '🌾', label: 'fermier', fem: 'fermière', tech: 'agriculture', water: false, traits: ['travailleur', 'prudent'], locked: false },
  chasseur: { emoji: '🏹', label: 'chasseur', fem: 'chasseuse', tech: null, water: false, traits: ['courageux', 'aventurier'], locked: false },
  'pêcheur': { emoji: '🎣', label: 'pêcheur', fem: 'pêcheuse', tech: null, water: true, traits: ['aventurier', 'prudent'], locked: false },
  'bâtisseur': { emoji: '🪵', label: 'bâtisseur', fem: 'bâtisseuse', tech: null, water: false, traits: ['travailleur', 'inventif'], locked: false },
  'guérisseur': { emoji: '🌱', label: 'guérisseur', fem: 'guérisseuse', tech: 'plantes', water: false, traits: ['sociable', 'prudent', 'curieux'], locked: false },
  forgeron: { emoji: '⚒️', label: 'forgeron', fem: 'forgeronne', tech: 'cuivre', water: false, traits: ['inventif', 'travailleur'], locked: false },
  gardien: { emoji: '🛡️', label: 'gardien', fem: 'gardienne', tech: null, water: false, traits: ['courageux', 'agressif'], locked: false },
  chef: { emoji: '👑', label: 'chef', fem: 'cheffe', tech: null, water: false, traits: [], locked: true },
};

const WORK_JOBS = Object.keys(JOBS).filter((job) => !JOBS[job].locked);
const MIN_DAYS_IN_JOB = 120;
const GAME_MEMORY_DAYS = 180;
const MAX_CHANGES_PER_PASS = 3;
const INHERIT_CHANCE = 0.4;
const NEW_TECH_DAYS = 360;

export function jobName(job, sex) {
  const entry = JOBS[job];
  if (!entry) return job;
  return sex === 'F' ? entry.fem : entry.label;
}

export function jobEmoji(job) {
  return JOBS[job] ? JOBS[job].emoji : '🔨';
}

export function jobLabel(job, sex) {
  return `${jobEmoji(job)} ${jobName(job, sex)}`;
}

export function isEligible(s, job) {
  const entry = JOBS[job];
  if (!entry || entry.locked) return false;
  if (entry.tech && !hasTech(s, entry.tech) && !(entry.tech === 'cuivre' && (hasTech(s, 'fer') || hasTech(s, 'metallurgie')))) return false;
  return !entry.water || hasWater(s);
}

const hasWater = (s) => !!s.geo && s.geo.water >= 1;
const isCrowded = (s, entry) => entry.pop > s.houses * (entry.mods ? entry.mods.capacity : 4);
const apocalypseOn = (state) => !!state.zombies && !!state.zombies.active;
const prefers = (p, job) => JOBS[job].traits.some((t) => p.traits.includes(t));
const workforce = (entry) => Math.max(0, entry.adults - (entry.chef ? 1 : 0));

function deficit(desired, current, job) {
  const want = desired[job] || 0;
  return (want - (current[job] || 0)) / Math.max(1, want);
}

export function desiredJobs(state, s, entry) {
  const pop = entry.pop;
  const A = workforce(entry);
  const d = {};
  d.gardien = apocalypseOn(state) ? Math.ceil(A / 6) : entry.wolfNear ? Math.ceil(A / 12) : pop >= 8 ? Math.max(1, Math.ceil(A / 25)) : 0;
  d['guérisseur'] = hasTech(s, 'plantes') ? Math.ceil(pop / 20) + (s.outbreak ? 1 : 0) : 0;
  d.forgeron = isEligible(s, 'forgeron') ? Math.max(1, Math.floor(A / 25)) : 0;
  d['bâtisseur'] = 1 + Math.floor(A / 10) + (isCrowded(s, entry) ? 1 : 0);
  const F = Math.max(0, A - d.gardien - d['guérisseur'] - d.forgeron - d['bâtisseur']);
  d.fermier = hasTech(s, 'agriculture') ? Math.round(F * 0.5) : 0;
  d['pêcheur'] = hasWater(s) ? Math.round(F * (hasTech(s, 'peche') || hasTech(s, 'navigation') ? 0.3 : 0.15)) : 0;
  if (entry.herdNear) s.herdSeenDay = state.day;
  const game = state.day - (s.herdSeenDay ?? -99999) < GAME_MEMORY_DAYS;
  d.chasseur = game ? Math.max(F >= 4 ? 1 : 0, Math.round(F * 0.15)) : 0;
  d.cueilleur = Math.max(0, F - d.fermier - d['pêcheur'] - d.chasseur);
  return d;
}

export function assignJob(state, p, s, job, reason, viaJournal = false) {
  p.job = job;
  p.jobDay = state.day;
  const text = `🔨 ${p.name} devient ${jobName(job, p.sex)} à ${s.name}${reason ? ` (${reason})` : ''}.`;
  if (viaJournal) logEvent(state, 'metier', text, { x: p.x, y: p.y, personId: p.id });
  else logPersonal(state, p, 'metier', text, { x: p.x, y: p.y });
}

export function stepJobs(state, rng, census) {
  for (const entry of census.values()) {
    const s = entry.s;
    if (!s || s.abandoned || entry.pop === 0) continue;
    const desired = desiredJobs(state, s, entry);
    const current = { ...entry.jobs };
    comeOfAge(state, rng, s, entry, desired, current);
    if (state.day % 5 === s.id % 5 && workforce(entry) >= 3) rebalance(state, rng, s, entry, desired, current);
  }
}

function comeOfAge(state, rng, s, entry, desired, current) {
  let byId = null;
  for (const p of entry.people) {
    if (!p.alive || p.job !== 'enfant') continue;
    const age = ageOf(state, p);
    if (age < ADULT_AGE) continue;
    if (!byId) byId = new Map(entry.people.map((q) => [q.id, q]));
    const parent = inheritedParent(rng, s, p, byId);
    const job = parent ? parent.job : neededJob(rng, s, p, desired, current);
    p.job = job;
    p.jobDay = state.day;
    current[job] = (current[job] || 0) + 1;
    const lineage = parent ? `, comme ${parent.sex === 'F' ? 'sa mère' : 'son père'}` : '';
    const text = `🧒 ${p.name} a ${age} ans et devient ${jobName(job, p.sex)}${lineage}.`;
    logPersonal(state, p, 'metier', text, { x: p.x, y: p.y });
  }
}

function inheritedParent(rng, s, p, byId) {
  const parents = (p.parents || []).map((id) => byId.get(id)).filter((q) => q && q.alive && isEligible(s, q.job));
  if (!parents.length || !rng.chance(INHERIT_CHANCE)) return null;
  return parents.length === 1 ? parents[0] : rng.pick(parents);
}

function neededJob(rng, s, p, desired, current) {
  let best = [];
  let bestScore = -Infinity;
  for (const job of WORK_JOBS) {
    if (!isEligible(s, job)) continue;
    const score = deficit(desired, current, job);
    if (score > bestScore) { bestScore = score; best = [job]; }
    else if (score === bestScore) best.push(job);
  }
  if (!best.length) return 'cueilleur';
  const liked = best.filter((job) => prefers(p, job));
  const pool = liked.length ? liked : best;
  return pool.length === 1 ? pool[0] : rng.pick(pool);
}

function rebalance(state, rng, s, entry, desired, current) {
  const apo = apocalypseOn(state);
  const crowded = isCrowded(s, entry);
  for (let n = 0; n < MAX_CHANGES_PER_PASS; n++) {
    const ranked = WORK_JOBS.filter((job) => isEligible(s, job) && deficit(desired, current, job) > 0)
      .sort((a, b) => deficit(desired, current, b) - deficit(desired, current, a));
    let moved = false;
    for (const job of ranked) {
      const urgent = job === 'gardien' && (entry.wolfNear || apo);
      const p = bestCandidate(state, rng, s, entry, desired, current, job, urgent);
      if (!p) continue;
      const from = p.job;
      assignJob(state, p, s, job, reasonFor(state, s, entry, job, from, crowded, apo));
      current[from] = (current[from] || 0) - 1;
      current[job] = (current[job] || 0) + 1;
      moved = true;
      break;
    }
    if (!moved) return;
  }
}

function bestCandidate(state, rng, s, entry, desired, current, job, urgent) {
  let best = null;
  let bestScore = -Infinity;
  for (const p of entry.people) {
    if (!p.alive || !canLeaveJob(state, s, p, desired, current, urgent)) continue;
    const score = (prefers(p, job) ? 2 : 0) + (p.job === 'cueilleur' ? 1 : 0) + rng.next();
    if (score > bestScore) { bestScore = score; best = p; }
  }
  return best;
}

function canLeaveJob(state, s, p, desired, current, urgent) {
  const entry = JOBS[p.job];
  if (entry && entry.locked) return false;
  if (!urgent && state.day - (p.jobDay || 0) < MIN_DAYS_IN_JOB) return false;
  if (entry && !isEligible(s, p.job)) return true;
  return (current[p.job] || 0) > (desired[p.job] || 0);
}

function reasonFor(state, s, entry, job, from, crowded, apo) {
  if (job === 'gardien' && apo) return 'les morts marchent';
  if (job === 'gardien' && entry.wolfNear) return 'les loups rôdent';
  if (job === 'bâtisseur' && crowded) return 'la colonie s\'agrandit';
  if (job === 'guérisseur' && s.outbreak) return 'l\'épidémie fait rage';
  const tech = JOBS[job].tech;
  if (tech && hasTech(s, tech) && state.day - (s.techDays[tech] ?? -99999) < NEW_TECH_DAYS) return `nouveau savoir : ${TECHS[tech] ? TECHS[tech].name : tech}`;
  if (job === 'chasseur') return 'le gibier est proche';
  if (job === 'cueilleur' && from === 'chasseur' && state.day - (s.herdSeenDay ?? -99999) >= GAME_MEMORY_DAYS) return 'le gibier se fait rare';
  return '';
}

export function ensureJobsState(state) {
  for (const p of state.people) if (p.alive) p.jobDay ??= 0;
  for (const s of state.settlements) s.huntDry ??= 0;
}
