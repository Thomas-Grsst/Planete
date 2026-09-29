import { ensureTechnologyState } from './technology.js';
import { ensureJobsState } from './jobs.js';
import { ensureDiseaseState } from './disease.js';
import { ensureZombiesState } from './zombies.js';
import { ensureGovernanceState } from './governance.js';
import { settlementGeo } from './census.js';
import { ANCIENTS_NAME } from './techTree.js';
import { levelIndexOf } from './settlements.js';
import { compactDead } from './housekeeping.js';
import { ensureResources } from './resources.js';
import { ensureCivState } from './civs.js';

const SAVE_VERSION = 2;

const LEGACY_GRANTS = [
  { minDay: 60, keys: ['feu', 'outils'], needsWater: false },
  { minDay: 400, keys: ['peche'], needsWater: true },
  { minDay: 1500, keys: ['agriculture', 'plantes'], needsWater: false },
  { minDay: 2500, keys: ['poterie'], needsWater: false },
  { minDay: 4000, keys: ['roue'], needsWater: false },
];

function isLegacySave(state) {
  return state.version === undefined && state.day > 0;
}

export function migrateState(state) {
  const legacy = isLegacySave(state);
  ensureTechnologyState(state);
  ensureJobsState(state);
  ensureDiseaseState(state);
  ensureZombiesState(state);
  ensureGovernanceState(state);
  ensureSharedDefaults(state);
  ensureResources(state);
  ensureCivState(state);
  if (legacy) grantAncientKnowledge(state);
  compactDead(state);
  state.version = SAVE_VERSION;
  return state;
}

function ensureSharedDefaults(state) {
  state.powers ??= { rain: 0, sun: 0 };
  state.powers.rain ??= 0;
  state.powers.sun ??= 0;
  state.powers.zombie ??= 0;
  state.powers.zombieDay ??= -99999;
  state.journalSeq ??= state.journal.length;
  state.extinct ??= false;
  state.removedDead ??= 0;
  for (const s of state.settlements) {
    s.geo ??= settlementGeo(state.world, s.x, s.y);
    s.fallen ??= null;
    s.departed ??= null;
    s.followed ??= false;
    s.maxLevelIndex ??= levelIndexOf(s.level);
  }
}

function grantAncientKnowledge(state) {
  const origin = state.settlements.find((s) => !s.abandoned) || state.settlements[0];
  if (!origin) return;
  for (const s of state.settlements) {
    if (s.abandoned) continue;
    for (const grant of LEGACY_GRANTS) {
      if (state.day < grant.minDay) continue;
      if (grant.needsWater && s.geo.water < 1) continue;
      for (const key of grant.keys) grantAncientTech(state, s, key, origin);
    }
  }
}

function grantAncientTech(state, s, key, origin) {
  if (!s.techs.includes(key)) s.techs.push(key);
  s.rooted ??= [];
  if (!s.rooted.includes(key)) s.rooted.push(key);
  state.discoveries[key] ??= {
    day: 0, personId: null, personName: ANCIENTS_NAME, settlementId: origin.id, settlementName: origin.name,
  };
}
