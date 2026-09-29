import { FAITH_SOURCES, PRAYERS, ofName, capitalize } from './faithData.js';
import { logEvent } from './events.js';
import { religionOf, isPlayerFaith, rememberLegend, aliveReligions } from './religions.js';

const ANSWERED_DEVOTION = 40;
const WITNESS_DEVOTION = 12;
const MATCHING_DEVOTION = 10;
const WRATH_DEVOTION = 20;
const DOUBT_DEVOTION = 15;

const yearOf = (day) => Math.floor(day / 360) + 1;

function legendName(state, rng, kind) {
  const year = yearOf(state.day);
  const taken = new Set(state.legends.map((l) => l.name));
  const names = FAITH_SOURCES[kind].legends.map((n) => `${n} de l'An ${year}`);
  const free = names.filter((n) => !taken.has(n));
  return free.length ? rng.pick(free) : `${rng.pick(names)} (bis)`;
}

const listNames = (names) => (names.length > 3 ? `${names.slice(0, 2).join(', ')} et ${names.length - 2} autres colonies` : names.length > 1 ? `${names.slice(0, -1).join(', ')} et ${names[names.length - 1]}` : names[0]);

function answerPrayer(state, s, rel, kind, legend, groups) {
  const need = s.prayer.need;
  s.prayer = null;
  s.answeredDay = state.day;
  const faithful = isPlayerFaith(rel);
  if (faithful) s.devotion = Math.min(100, s.devotion + ANSWERED_DEVOTION);
  else s.awe = { kind, day: state.day, legendId: legend.id, answered: true };
  if (rel && !faithful) s.devotion = Math.max(0, s.devotion - DOUBT_DEVOTION);
  const key = `${rel ? rel.id : 'ciel'}|${need}`;
  if (!groups.has(key)) groups.set(key, { rel, need, places: [] });
  groups.get(key).places.push(s);
}

function tellAnswers(state, kind, legend, groups) {
  const sign = FAITH_SOURCES[kind].sign;
  for (const { rel, need, places } of groups.values()) {
    const names = listNames(places.map((s) => s.name));
    const plural = places.length > 1;
    const wish = PRAYERS[need].wish;
    const prayed = plural ? 'priaient' : 'priait';
    let text = `✨ ${names} ${plural ? 'imploraient' : 'implorait'} le ciel pour ${wish}, et ${sign}. Personne n'oubliera ${legend.name}.`;
    if (isPlayerFaith(rel)) text = `✨ ${names} ${prayed} ${rel.deity} pour ${wish}, et ${sign} ! Les fidèles crient au miracle.`;
    else if (rel) text = `✨ ${names} ${prayed} ${rel.deity} pour ${wish}, et ${sign}… mais qui a répondu ? Le doute gagne les fidèles ${ofName(rel.name)}.`;
    logEvent(state, 'miracle', text, { x: places[0].x, y: places[0].y, highlight: true });
  }
}

function witness(state, s, rel, kind, legend) {
  if (isPlayerFaith(rel)) {
    const boost = kind === 'zombie' ? WRATH_DEVOTION : WITNESS_DEVOTION + (rel.source === kind ? MATCHING_DEVOTION : 0);
    s.devotion = Math.min(100, s.devotion + boost);
    return;
  }
  if (!rel && !(s.awe && s.awe.answered)) s.awe = { kind, day: state.day, legendId: legend.id, answered: false };
}

function tellWrath(state, legend) {
  for (const rel of aliveReligions(state)) {
    if (!isPlayerFaith(rel) || rel.source === 'zombie') continue;
    logEvent(state, 'legende', `💀 Les fidèles ${ofName(rel.name)} voient dans ${legend.name} la colère ${ofName(rel.deity)}.`, {});
  }
}

export function recordMiracle(state, rng, kind) {
  if (!FAITH_SOURCES[kind] || !FAITH_SOURCES[kind].player) return null;
  const legend = { id: state.nextId++, kind, day: state.day, name: legendName(state, rng, kind), answered: [] };
  rememberLegend(state, legend);
  const groups = new Map();
  for (const s of state.settlements) {
    if (s.abandoned) continue;
    const rel = religionOf(state, s);
    const prayed = !!s.prayer && PRAYERS[s.prayer.need] && PRAYERS[s.prayer.need].answers.includes(kind);
    if (prayed) { answerPrayer(state, s, rel, kind, legend, groups); legend.answered.push(s.name); }
    else witness(state, s, rel, kind, legend);
  }
  tellAnswers(state, kind, legend, groups);
  const verb = legend.name.startsWith('les ') ? 'entrent' : 'entre';
  logEvent(state, 'legende', `📖 ${capitalize(legend.name)} ${verb} dans les récits des anciens.`, {});
  if (kind === 'zombie') tellWrath(state, legend);
  const names = legend.answered;
  if (!names.length) return null;
  return `✨ ${listNames(names)} ${names.length > 1 ? 'crient' : 'crie'} au miracle !`;
}
