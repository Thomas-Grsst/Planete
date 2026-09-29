import { TECHS, TECH_ORDER } from './techTree.js';
import { logEvent, logPersonal } from './events.js';
import { ageOf } from './people.js';

const ROOT_KEEPERS = 8;
const ROOT_SHARE = 0.25;
const APPRENTICE_CHANCE = 0.008;
const MAX_APPRENTICE_CHANCE = 0.3;
const APPRENTICE_AGE = 10;

export function ensureLoreState(state) {
  for (const p of state.people) p.knows ??= [];
  for (const s of state.settlements) {
    s.techs ??= [];
    s.rooted ??= s.techs.slice();
    s.keeperName ??= {};
    s.loreReady ??= true;
  }
}

export function teach(p, key) {
  p.knows ??= [];
  if (!p.knows.includes(key)) p.knows.push(key);
}

export function rootIfWritten(s, key) {
  if (s.rooted.includes('ecriture') || key === 'ecriture') {
    if (!s.rooted.includes(key)) s.rooted.push(key);
    if (key === 'ecriture') for (const k of s.techs) if (!s.rooted.includes(k)) s.rooted.push(k);
  }
}

function keepersOf(residents) {
  const counts = {};
  const keeper = {};
  for (const p of residents) {
    for (const k of p.knows || []) {
      counts[k] = (counts[k] || 0) + 1;
      keeper[k] = p;
    }
  }
  return { counts, keeper };
}

function refreshTechs(state, s, counts, residentCount) {
  const writing = s.rooted.includes('ecriture');
  for (const k of Object.keys(counts)) {
    if (!s.rooted.includes(k) && (writing || counts[k] >= Math.max(ROOT_KEEPERS, residentCount * ROOT_SHARE))) s.rooted.push(k);
  }
  const next = TECH_ORDER.filter((k) => s.rooted.includes(k) || counts[k] > 0);
  const lost = s.techs.filter((k) => TECHS[k] && !next.includes(k));
  if (s.loreReady) for (const k of lost) announceLoss(state, s, k);
  for (const k of lost) delete s.techDays[k];
  s.techs = next;
  s.loreReady = true;
}

function announceLoss(state, s, key) {
  const t = TECHS[key];
  const who = s.keeperName[key];
  const since = who ? ` depuis que ${who} n'est plus là` : '';
  logEvent(state, 'savoir_perdu', `🕯️ Plus personne à ${s.name} ne connaît le secret ${t.de}${since}.`, { x: s.x, y: s.y });
  s.lostLoreDay = state.day;
}

function learnerFor(state, rng, residents, key, keeper) {
  const boostJob = TECHS[key].boostJob;
  const pool = residents.filter((p) => !(p.knows || []).includes(key) && ageOf(state, p) >= APPRENTICE_AGE);
  if (!pool.length) return null;
  const kin = pool.filter((p) => p.parents && p.parents.includes(keeper.id));
  const skilled = pool.filter((p) => boostJob && p.job === boostJob);
  if (kin.length && rng.chance(0.5)) return rng.pick(kin);
  if (skilled.length && rng.chance(0.5)) return rng.pick(skilled);
  return rng.pick(pool);
}

function apprentice(state, rng, s, residents, counts, keeper) {
  for (const k of Object.keys(counts)) {
    if (s.rooted.includes(k) || !TECHS[k]) continue;
    s.keeperName[k] = keeper[k].name;
    if (!rng.chance(Math.min(MAX_APPRENTICE_CHANCE, APPRENTICE_CHANCE * counts[k]))) continue;
    const learner = learnerFor(state, rng, residents, k, keeper[k]);
    if (!learner) continue;
    teach(learner, k);
    logPersonal(state, learner, 'apprentissage', `📖 ${learner.name} apprend le secret ${TECHS[k].de} auprès de ${keeper[k].name}.`, { x: s.x, y: s.y });
  }
}

export function stepLore(state, rng, census) {
  for (const entry of census.values()) {
    const s = entry.s;
    if (!s || s.abandoned || entry.pop <= 0) continue;
    s.rooted ??= [];
    s.keeperName ??= {};
    const residents = entry.people.filter((p) => p.alive && p.homeId === s.id);
    const { counts, keeper } = keepersOf(residents);
    refreshTechs(state, s, counts, residents.length);
    apprentice(state, rng, s, residents, counts, keeper);
  }
}
