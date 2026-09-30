import { PRAYERS, ofName, toName } from './faithData.js';
import { logEvent, plural } from './events.js';
import { hasTech } from './techTree.js';
import { aliveCivs, civTitle } from './civs.js';
import { ensureFaithState, religionOf, aliveReligions, faithSettlements, isPlayerFaith, leaveFaith } from './religions.js';
import { tryBirth, tryConversionByMiracle, trySchism } from './faithBirth.js';
import { spreadFaith } from './faithSpread.js';

const DEVOTION_PULL = 0.001;
const BASE_DEVOTION = 35;
const TEMPLE_DEVOTION = 15;
const HOLY_DEVOTION = 10;
const PROPHET_DEVOTION = 10;
const DOUBT_AFTER_DAYS = 60;
const DOUBT_RATE = 0.05;
const APOSTASY_BELOW = 5;
const PRAYER_LOG_GAP = 120;
const TEMPLE_POP = 25;
const TEMPLE_MIN_DEVOTION = 45;
const TEMPLE_WOOD = 25;
const TEMPLE_CHANCE = 0.01;
const GREAT_TEMPLE_POP = 60;
const GREAT_TEMPLE_WOOD = 40;
const GREAT_TEMPLE_CHANCE = 0.005;

function currentNeed(state, s, entry) {
  if (state.zombies && state.zombies.active && entry.bitten > 0) return 'zombies';
  if (state.weather === 'drought') return 'drought';
  if (entry.hungry >= Math.max(2, entry.pop * 0.25)) return 'hunger';
  if (s.outbreak) return 'sick';
  if (state.weather === 'storm') return 'storm';
  if (state.weather === 'snow') return 'cold';
  return null;
}

function updatePrayer(state, s, entry, rel) {
  const need = currentNeed(state, s, entry);
  if (!need) { s.prayer = null; return; }
  if (s.prayer && s.prayer.need === need) return;
  s.prayer = { need, since: state.day };
  if (!rel || entry.pop < 5 || state.day - (s.prayerLogDay ?? -99999) < PRAYER_LOG_GAP) return;
  s.prayerLogDay = state.day;
  logEvent(state, 'priere', `🙏 À ${s.name}, on prie ${rel.deity} pour ${PRAYERS[need].wish}.`, { x: s.x, y: s.y });
}

function tendDevotion(state, s, entry, rel) {
  const prophet = entry.people.some((p) => p.prophetOf === rel.id);
  const target = BASE_DEVOTION + TEMPLE_DEVOTION * (s.temple || 0) + (s.id === rel.holyId ? HOLY_DEVOTION : 0) + (prophet ? PROPHET_DEVOTION : 0);
  s.devotion += (target - s.devotion) * DEVOTION_PULL;
  if (s.prayer && state.day - s.prayer.since > DOUBT_AFTER_DAYS) s.devotion -= DOUBT_RATE;
  if (s.devotion >= APOSTASY_BELOW) return;
  logEvent(state, 'conversion', `🕯️ À ${s.name}, on a trop prié en vain : la colonie se détourne ${ofName(rel.name)}.`, { x: s.x, y: s.y });
  leaveFaith(s);
}

function buildTemple(state, rng, s, entry, rel) {
  if (!s.temple) {
    if (entry.pop < TEMPLE_POP || s.devotion < TEMPLE_MIN_DEVOTION || s.wood < TEMPLE_WOOD || !rng.chance(TEMPLE_CHANCE)) return;
    s.temple = 1;
    s.wood -= TEMPLE_WOOD;
    logEvent(state, 'temple', `🛕 ${s.name} élève un temple ${toName(rel.deity)}.`, { x: s.x, y: s.y });
    return;
  }
  if (s.temple > 1 || s.id !== rel.holyId || !hasTech(s, 'architecture') || entry.pop < GREAT_TEMPLE_POP || s.wood < GREAT_TEMPLE_WOOD) return;
  if (!rng.chance(GREAT_TEMPLE_CHANCE)) return;
  s.temple = 2;
  s.wood -= GREAT_TEMPLE_WOOD;
  logEvent(state, 'temple', `🛕 Un grand temple dédié ${toName(rel.deity)} domine désormais ${s.name}, ville sainte ${ofName(rel.name)}.`, { x: s.x, y: s.y, highlight: true });
}

function mostPopulous(members, census) {
  return members.reduce((best, s) => ((census.get(s.id)?.pop || 0) > (census.get(best.id)?.pop || 0) ? s : best), members[0]);
}

function mournProphet(state, rel) {
  const p = state.people.find((q) => q.id === rel.founderId);
  if (p && p.alive) return;
  rel.prophetGone = state.day;
  const title = p && p.sex === 'F' ? 'la prophétesse' : 'le prophète';
  logEvent(state, 'religion_vie', `🕯️ ${rel.founderName}, ${title} ${ofName(rel.name)}, s'éteint. Ses paroles lui survivent.`, { personId: p ? p.id : undefined });
}

function stepReligionLife(state, census) {
  for (const rel of aliveReligions(state)) {
    const members = faithSettlements(state, rel);
    if (!members.length) {
      rel.alive = false;
      rel.fallDay = state.day;
      const years = Math.floor((state.day - rel.foundedDay) / 360);
      logEvent(state, 'religion_fin', `🕯️ Plus aucune colonie ne suit ${rel.name}, ${years ? plural(years, 'an') : 'moins d\'un an'} après sa fondation.`, {});
      continue;
    }
    if (!members.some((s) => s.id === rel.holyId)) {
      const next = mostPopulous(members, census);
      rel.holyId = next.id;
      rel.holyName = next.name;
      logEvent(state, 'religion_vie', `🛕 ${next.name} devient la ville sainte ${ofName(rel.name)}.`, { x: next.x, y: next.y });
    }
    if (rel.prophetGone == null) mournProphet(state, rel);
  }
}

function stepStateReligions(state) {
  for (const civ of aliveCivs(state)) {
    const capital = state.settlements.find((s) => s.id === civ.capitalId);
    const rel = capital ? religionOf(state, capital) : null;
    const id = rel ? rel.id : null;
    if (civ.religionId === id) continue;
    civ.religionId = id;
    if (rel) logEvent(state, 'religion_etat', `👑 ${civTitle(civ, true)} fait ${ofName(rel.name)} sa religion officielle.`, { x: capital.x, y: capital.y, civId: civ.id, highlight: true });
  }
}

export function stepFaith(state, rng, census) {
  ensureFaithState(state);
  for (const entry of census.values()) {
    const s = entry.s;
    if (!s || s.abandoned || entry.pop <= 0) continue;
    const rel = religionOf(state, s);
    if (!rel && s.faithId != null) leaveFaith(s);
    updatePrayer(state, s, entry, rel);
    if (!rel) { tryBirth(state, rng, s, entry); continue; }
    if (!isPlayerFaith(rel) && tryConversionByMiracle(state, rng, s, entry, rel)) continue;
    tendDevotion(state, s, entry, rel);
    if (s.faithId == null) continue;
    buildTemple(state, rng, s, entry, rel);
    spreadFaith(state, rng, s, entry, rel);
    trySchism(state, rng, s, entry, rel);
  }
  stepReligionLife(state, census);
  stepStateReligions(state);
}
