import { DISEASES } from './diseaseTable.js';
import { logPersonal } from './events.js';
import { ageOf, killPerson } from './people.js';

export function ensureDiseaseState(state) {
  for (const p of state.people) {
    if (!p.alive) continue;
    p.sick ??= null;
    p.immune ??= [];
  }
  for (const s of state.settlements) {
    s.outbreak ??= null;
    s.lastOutbreakDay ??= -9999;
  }
}

export const isImmune = (p, key) => (p.immune || []).includes(key);

export function infect(state, rng, p, key, s) {
  const d = DISEASES[key];
  p.sick = { key, since: state.day, duration: rng.int(d.duration[0], d.duration[1]) };
  logPersonal(state, p, 'maladie', `${d.emoji} ${p.name} tombe malade : ${d.label}.`, { x: p.x, y: p.y });
}

export function stepSick(state, rng, s, entry) {
  const m = entry.mods;
  const result = { sick: 0, deaths: 0, recovered: 0, infected: 0 };
  const sickToday = entry.people.filter((p) => p.alive && p.sick);
  for (const p of sickToday) {
    if (!p.alive) continue;
    const d = DISEASES[p.sick.key];
    if (!d) { p.sick = null; continue; }
    const age = ageOf(state, p);
    const frail = age > 55 || age < 5 ? 1.8 : 1;
    p.health -= d.dmg * m.care;
    if (p.health <= 0 || rng.chance(d.lethal * m.care * frail)) {
      killPerson(state, p, d.de);
      p.sick = null;
      result.deaths += 1;
      continue;
    }
    if (state.day - p.sick.since >= p.sick.duration) {
      recover(state, p, d);
      result.recovered += 1;
      continue;
    }
    result.sick += 1;
    if (!rng.chance(d.contagion * m.contagion * Math.min(2, entry.density))) continue;
    const q = rng.pick(entry.people);
    if (!q || !q.alive || q.sick || q.bitten != null || isImmune(q, p.sick.key)) continue;
    infect(state, rng, q, p.sick.key, s);
    result.infected += 1;
    result.sick += 1;
  }
  return result;
}

function recover(state, p, d) {
  const key = p.sick.key;
  p.sick = null;
  p.immune ??= [];
  if (!p.immune.includes(key)) p.immune.push(key);
  p.health = Math.max(p.health, 20);
  logPersonal(state, p, 'guerison', `🌿 ${p.name} guérit ${d.de}.`, { x: p.x, y: p.y });
}

export function diseaseLabel(state, p) {
  if (!p.sick) return '';
  const d = DISEASES[p.sick.key];
  if (!d) return '';
  return `${d.emoji} ${d.name} (depuis ${state.day - p.sick.since} j)`;
}

export function immuneLabel(p) {
  return (p.immune || [])
    .map((k) => (k === 'morsure' ? 'Morsure de zombie' : DISEASES[k] ? DISEASES[k].name : k))
    .join(', ');
}
