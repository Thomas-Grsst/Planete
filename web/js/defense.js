import { logEvent, ofPlace } from './events.js';
import { killPerson } from './people.js';
import { isWalkable } from './world.js';

const WOLF_REACH = 2;
const WOLF_ATTACK_CHANCE = 0.05;
const REPEL_THRESHOLD = 2;
const REPEL_DISTANCE = 4;
const WOLF_WOUND = 40;
const WOLF_LETHALITY = 0.3;

const manhattan = (ax, ay, bx, by) => Math.abs(ax - bx) + Math.abs(ay - by);

export function defenseStrength(state, s, entry) {
  const guards = entry.jobs.gardien || 0;
  const brave = entry.traits.courageux || 0;
  const adults = entry.adults || 0;
  return (guards * 1 + brave * 0.4 + adults * 0.08) * entry.mods.defense;
}

export function stepWolves(state, rng, census) {
  for (const herd of state.herds) {
    if (herd.species !== 'wolf' || herd.count < 1) continue;
    const target = settlementInReach(state, census, herd);
    if (!target || !rng.chance(WOLF_ATTACK_CHANCE)) continue;
    wolfAttack(state, rng, herd, target.s, target.entry);
  }
}

function settlementInReach(state, census, herd) {
  for (const s of state.settlements) {
    if (s.abandoned) continue;
    if (manhattan(herd.x, herd.y, s.x, s.y) > WOLF_REACH) continue;
    const entry = census.get(s.id);
    if (entry && entry.pop > 0) return { s, entry };
  }
  return null;
}

function pushPackAway(state, herd, s) {
  const dx = Math.sign(herd.x - s.x) || 1;
  const dy = Math.sign(herd.y - s.y);
  for (let step = REPEL_DISTANCE; step > 0; step--) {
    const x = herd.x + dx * step;
    const y = herd.y + dy * step;
    if (isWalkable(state.world, x, y)) { herd.x = x; herd.y = y; return; }
  }
}

function wolfAttack(state, rng, herd, s, entry) {
  if (defenseStrength(state, s, entry) >= REPEL_THRESHOLD) {
    pushPackAway(state, herd, s);
    const who = entry.jobs.gardien ? 'Les gardiens' : 'Les habitants';
    logEvent(state, 'attaque', `🐺 ${who} ${ofPlace(s.name)} repoussent une meute de loups.`, { x: s.x, y: s.y });
    return;
  }
  const living = entry.people.filter((p) => p.alive);
  if (!living.length) return;
  const victim = rng.pick(living);
  victim.health -= WOLF_WOUND;
  const female = victim.sex === 'F';
  if (rng.chance(WOLF_LETHALITY) || victim.health <= 0) {
    killPerson(state, victim, female ? 'dévorée par les loups' : 'dévoré par les loups');
    return;
  }
  logEvent(state, 'attaque', `🐺 Une meute de loups attaque ${s.name} : ${victim.name} est ${female ? 'blessée' : 'blessé'}.`, { x: s.x, y: s.y, personId: victim.id });
}
