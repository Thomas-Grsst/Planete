import { createRng, hashString } from './rng.js';
import { generateWorld, tileAt, SIZE } from './world.js';
import { createPerson, stepPeople, ageOf } from './people.js';
import { seedHerds, stepHerds } from './animals.js';
import { createSettlement, stepSettlements, findSettlementSpot, regrowFood } from './settlements.js';
import { logEvent, PRIORITY } from './events.js';
import { buildCensus } from './census.js';
import { stepWork } from './work.js';
import { stepEpidemics } from './epidemics.js';
import { stepZombies } from './zombies.js';
import { stepWolves } from './defense.js';
import { stepJobs } from './jobs.js';
import { stepGovernance } from './governance.js';
import { stepTechnology, stepExodus } from './technology.js';
import { migrateState } from './migrate.js';
import { stepHousekeeping } from './housekeeping.js';

export const MS_PER_DAY = 600000;
export const MAX_OFFLINE_DAYS = 4320;

const WEATHERS = ['sun', 'sun', 'cloud', 'rain', 'rain', 'storm', 'drought'];
export const WEATHER_ICON = { sun: '☀️', cloud: '☁️', rain: '🌧️', storm: '⛈️', drought: '🔥', snow: '❄️' };

export function withRng(state, fn) {
  const rng = createRng(state.seed);
  rng.state = state.rngState;
  fn(rng);
  state.rngState = rng.state;
}

export function createState(name, seedText) {
  const seed = hashString(seedText || `${name}-${Date.now()}`);
  const rng = createRng(seed);
  const state = {
    id: `${Date.now().toString(36)}${Math.floor(Math.random() * 1e6).toString(36)}`,
    name, seed, rngState: 0, day: 0, nextId: 1,
    world: generateWorld(seed),
    people: [], settlements: [], herds: [], journal: [],
    weather: 'sun', weatherDays: 5,
    pendingSummary: {}, pendingHighlights: [], lastSummaryDay: 0,
    followed: [], powers: { rain: 0, sun: 0, zombie: 0, zombieDay: -99999 },
    lastSimTime: Date.now(), accMs: 0,
  };
  const spot = findSettlementSpot(state, rng, SIZE / 2, SIZE / 2) || { x: SIZE / 2, y: SIZE / 2 };
  const s = createSettlement(state, rng, spot.x, spot.y);
  for (let i = 0; i < 20; i++) {
    const p = createPerson(state, rng, spot.x + rng.int(-1, 1), spot.y + rng.int(-1, 1), rng.int(16, 35), s.id);
    if (i % 2 === 1) p.sex = 'F'; else p.sex = 'M';
  }
  seedHerds(state, rng);
  logEvent(state, 'fondation', `${s.name} est fondé par 20 pionniers.`, { x: s.x, y: s.y });
  state.pendingSummary = {};
  state.pendingHighlights = [];
  state.rngState = rng.state;
  return migrateState(state);
}

export function tick(state) {
  withRng(state, (rng) => {
    state.day += 1;
    stepWeather(state, rng);
    regrowFood(state);
    const census = buildCensus(state);
    checkExtinction(state, census);
    stepWork(state, rng, census);
    stepPeople(state, rng, census);
    stepEpidemics(state, rng, census);
    stepZombies(state, rng, census);
    stepHerds(state, rng);
    stepSettlements(state, rng, census);
    stepWolves(state, rng, census);
    stepJobs(state, rng, census);
    stepGovernance(state, rng, census);
    stepTechnology(state, rng, census);
    stepDisasters(state, rng);
    stepExodus(state);
    stepHousekeeping(state);
  });
}

function checkExtinction(state, census) {
  if (state.extinct || (state.ended && state.ended.remaining === 0)) return;
  for (const entry of census.values()) if (entry.pop > 0) return;
  state.extinct = true;
  logEvent(state, 'extinction', `🪦 Plus personne ne respire sur ${state.name}. Le silence est total.`, {});
}

function stepWeather(state, rng) {
  if (state.powers.rain > 0) { state.powers.rain -= 1; state.weather = 'rain'; return; }
  if (state.powers.sun > 0) { state.powers.sun -= 1; state.weather = 'sun'; return; }
  state.weatherDays -= 1;
  if (state.weatherDays > 0) return;
  const season = Math.floor((state.day % 360) / 90);
  let next = rng.pick(WEATHERS);
  if (season === 3 && rng.chance(0.4)) next = 'snow';
  if (next === 'drought' && season !== 1) next = 'sun';
  state.weatherDays = rng.int(5, 18);
  if (next !== state.weather) {
    state.weather = next;
    const labels = { storm: 'Une tempête éclate.', drought: 'Une sécheresse frappe la région.', snow: 'La neige recouvre le monde.' };
    if (labels[next]) logEvent(state, 'meteo', labels[next], {});
  }
}

function stepDisasters(state, rng) {
  if (state.weather === 'drought' && rng.chance(0.03)) {
    const s = rng.pick(state.settlements.filter((x) => !x.abandoned));
    if (!s) return;
    let burnt = 0;
    for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) {
      const t = tileAt(state.world, s.x + dx, s.y + dy);
      if (t && t.trees > 0) { burnt += t.trees; t.trees = 0; t.food *= 0.3; }
    }
    if (burnt > 5) logEvent(state, 'catastrophe', `Un incendie ravage les forêts autour de ${s.name}.`, { x: s.x, y: s.y });
  }
  if (state.weather === 'storm' && rng.chance(0.02)) {
    const s = rng.pick(state.settlements.filter((x) => !x.abandoned && x.houses > 1 && !x.techs.includes('architecture')));
    if (s) { s.houses -= 1; s.stormDamageDay = state.day; logEvent(state, 'catastrophe', `La tempête détruit une maison à ${s.name}.`, { x: s.x, y: s.y }); }
  }
}

export function catchUp(state, nowMs) {
  const elapsed = Math.max(0, nowMs - state.lastSimTime);
  const total = (state.accMs || 0) + elapsed;
  const whole = Math.floor(total / MS_PER_DAY);
  const days = Math.min(MAX_OFFLINE_DAYS, whole);
  for (let i = 0; i < days; i++) tick(state);
  state.accMs = whole > MAX_OFFLINE_DAYS ? 0 : total - whole * MS_PER_DAY;
  state.lastSimTime = nowMs;
  return { elapsedMs: elapsed, days };
}

export function dayPhase(state) {
  return Math.max(0, Math.min(0.9999, (state.accMs || 0) / MS_PER_DAY));
}

export function advance(state, dtMs, speed) {
  if (speed <= 0) return 0;
  state.accMs += dtMs * speed;
  let ticks = 0;
  while (state.accMs >= MS_PER_DAY && ticks < 60) { state.accMs -= MS_PER_DAY; tick(state); ticks++; }
  return ticks;
}

const byPriority = (a, b) => (PRIORITY[b.type] || 10) - (PRIORITY[a.type] || 10) || b.day - a.day;

function followedDigest(state) {
  return state.followed
    .map((id) => state.people.find((p) => p.id === id))
    .filter(Boolean)
    .map((p) => ({
      id: p.id, name: p.name, sex: p.sex, alive: p.alive, departed: p.departed === true, age: ageOf(state, p), job: p.job,
      fresh: p.history.filter((h) => h.day > state.lastSummaryDay).length,
      last: p.history.length ? p.history[p.history.length - 1].text : '',
    }));
}

export function takeSummary(state) {
  const summary = {
    counts: state.pendingSummary,
    highlights: state.pendingHighlights.slice().sort(byPriority).slice(0, 4),
    followed: followedDigest(state),
    sinceDay: state.lastSummaryDay,
  };
  state.pendingSummary = {};
  state.pendingHighlights = [];
  state.lastSummaryDay = state.day;
  return summary;
}
