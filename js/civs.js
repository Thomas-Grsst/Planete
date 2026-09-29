import { logEvent, ofPlace } from './events.js';
import { TECH_ORDER } from './techTree.js';

export const CIV_COLORS = ['#e57373', '#64b5f6', '#ffd54f', '#81c784', '#ba68c8', '#4db6ac', '#ff8a65', '#f06292', '#aed581', '#90a4ae'];

const REGIMES = {
  agressif: ['Empire', 'l\''],
  courageux: ['Royaume', 'le'],
  sociable: ['Confédération', 'la'],
  travailleur: ['République', 'la'],
  inventif: ['Principauté', 'la'],
  prudent: ['Ligue', 'la'],
  curieux: ['Cité-État', 'la'],
  aventurier: ['Clan', 'le'],
};
const DEFAULT_REGIME = ['Royaume', 'le'];

const capitalize = (text) => text.charAt(0).toUpperCase() + text.slice(1);

export function ensureCivState(state) {
  state.civs ??= [];
  state.wars ??= [];
  state.relations ??= {};
  for (const s of state.settlements) {
    s.civId ??= null;
    s.conqueredDay ??= null;
  }
}

export const civById = (state, id) => (id == null ? null : state.civs.find((c) => c.id === id) || null);
export const civOf = (state, s) => (s ? civById(state, s.civId) : null);
export const aliveCivs = (state) => state.civs.filter((c) => c.alive);
export const civSettlements = (state, civ) => state.settlements.filter((s) => !s.abandoned && s.civId === civ.id);

export function civTitle(civ, start = false) {
  const article = civ.article === 'l\'' ? 'l\'' : `${civ.article} `;
  const text = `${article}${civ.regime} ${ofPlace(civ.name)}`;
  return start ? capitalize(text) : text;
}

export function civToTitle(civ) {
  if (civ.article === 'le') return `au ${civ.regime} ${ofPlace(civ.name)}`;
  return `à ${civTitle(civ)}`;
}

export function civOfTitle(civ) {
  if (civ.article === 'le') return `du ${civ.regime} ${ofPlace(civ.name)}`;
  return `de ${civTitle(civ)}`;
}

function regimeFor(chef) {
  for (const trait of chef ? chef.traits : []) if (REGIMES[trait]) return REGIMES[trait];
  return DEFAULT_REGIME;
}

export function createCiv(state, capital, chef) {
  const [regime, article] = regimeFor(chef);
  const civ = {
    id: state.nextId++, name: capital.name, regime, article, color: CIV_COLORS[state.civs.length % CIV_COLORS.length],
    capitalId: capital.id, foundedDay: state.day, founderId: chef ? chef.id : null, founderName: chef ? chef.name : null,
    culture: 0, alive: true, fallDay: null, conquests: 0,
  };
  state.civs.push(civ);
  capital.civId = civ.id;
  capital.conqueredDay = null;
  return civ;
}

export function joinCiv(state, s, civ, text) {
  s.civId = civ.id;
  logEvent(state, 'ralliement', text || `🏳️ ${s.name} rejoint ${civTitle(civ)}.`, { x: s.x, y: s.y, civId: civ.id });
}

export function relationKey(a, b) {
  return a.id < b.id ? `${a.id}-${b.id}` : `${b.id}-${a.id}`;
}

export function relationOf(state, a, b) {
  const key = relationKey(a, b);
  state.relations[key] ??= { score: 0, pact: null, truceUntil: 0 };
  return state.relations[key];
}

export const warBetween = (state, a, b) => state.wars.find((w) => (w.a === a.id && w.b === b.id) || (w.a === b.id && w.b === a.id)) || null;

export function civPopulation(state, civ) {
  const ids = new Set(civSettlements(state, civ).map((s) => s.id));
  let pop = 0;
  for (const p of state.people) if (p.alive && ids.has(p.homeId)) pop += 1;
  return pop;
}

export function civTechShare(state, civ) {
  const known = new Set();
  for (const s of civSettlements(state, civ)) for (const k of s.techs || []) known.add(k);
  return Math.round((known.size / TECH_ORDER.length) * 100);
}
