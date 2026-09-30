import { tick, withRng } from './simulation.js';
import { logEvent } from './events.js';
import { startApocalypse } from './zombies.js';
import { recordMiracle } from './miracles.js';

export const ZOMBIE_COOLDOWN = 1440;
const MIN_POP_TO_WAKE = 6;

function apocalypseRunning(state) {
  return !!(state.zombies && state.zombies.active);
}

function cooldownLeft(state) {
  const zombieDay = state.powers.zombieDay ?? -99999;
  return Math.max(0, ZOMBIE_COOLDOWN - (state.day - zombieDay));
}

export function zombiePowerState(state) {
  if (apocalypseRunning(state)) return { ready: false, label: '🧟 En cours…' };
  const left = cooldownLeft(state);
  if (left > 0) return { ready: false, label: `☣️ Disponible dans ${left} j` };
  return { ready: true, label: '☣️ Apocalypse zombie' };
}

function rain(state) {
  state.powers.rain = 10;
  state.weather = 'rain';
  logEvent(state, 'meteo', 'Une pluie providentielle tombe du ciel.', {});
  return '🌧️ Une pluie providentielle tombe du ciel.';
}

function sun(state) {
  state.powers.sun = 10;
  state.weather = 'sun';
  logEvent(state, 'meteo', 'Le ciel se dégage soudainement.', {});
  return '☀️ Le ciel se dégage.';
}

function grow(state) {
  for (const t of state.world.tiles) {
    if (t.fertility > 0.3) {
      t.food = Math.max(t.food, t.fertility * 12);
      if (t.biome === 'forest' && t.trees < 9) t.trees += 2;
    }
  }
  logEvent(state, 'meteo', 'La végétation explose partout dans le monde.', {});
  return '🌱 La végétation explose.';
}

function skip(state) {
  for (let i = 0; i < 30; i++) tick(state);
  return '⏩ 30 jours passent.';
}

function livingBySettlement(state) {
  const pops = new Map();
  for (const p of state.people) {
    if (!p.alive) continue;
    pops.set(p.homeId, (pops.get(p.homeId) || 0) + 1);
  }
  return pops;
}

function wakeableSettlements(state) {
  const pops = livingBySettlement(state);
  return state.settlements.filter((s) => !s.abandoned && (pops.get(s.id) || 0) >= MIN_POP_TO_WAKE);
}

function zombie(state) {
  if (apocalypseRunning(state)) return '🧟 Les morts marchent déjà.';
  const left = cooldownLeft(state);
  if (left > 0) return `🧟 La terre est encore fraîche… (dans ${left} j)`;
  let origin = null;
  withRng(state, (rng) => {
    const candidates = wakeableSettlements(state);
    if (!candidates.length) return;
    const s = rng.pick(candidates);
    if (startApocalypse(state, rng, s, 'pouvoir', null)) origin = s;
  });
  if (!origin) return '🧟 Personne à réveiller.';
  state.powers.zombieDay = state.day;
  state.powers.zombie += 1;
  return `☣️ Une brume verte descend sur ${origin.name}…`;
}

const POWERS = new Map([['rain', rain], ['sun', sun], ['grow', grow], ['skip', skip], ['zombie', zombie]]);

const MIRACLES = new Set(['rain', 'sun', 'grow', 'zombie']);

export function usePower(state, name) {
  const power = POWERS.get(name);
  if (!power) return null;
  const apocalypses = state.powers.zombie;
  const msg = power(state);
  if (!MIRACLES.has(name) || (name === 'zombie' && state.powers.zombie === apocalypses)) return msg;
  let echo = null;
  withRng(state, (rng) => { echo = recordMiracle(state, rng, name); });
  return echo ? `${msg} ${echo}` : msg;
}
