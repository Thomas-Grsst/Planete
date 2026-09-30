const YEAR = 360;
export const DEAD_KEEP_DAYS = 30 * YEAR;
const COMPACT_HISTORY = 3;

function protectedIds(state) {
  const ids = new Set(state.followed);
  for (const d of Object.values(state.discoveries || {})) if (d && d.personId != null) ids.add(d.personId);
  return ids;
}

function referencedIds(state) {
  const ids = new Set();
  for (const p of state.people) {
    if (!p.alive) continue;
    if (p.partnerId != null) ids.add(p.partnerId);
    for (const id of p.parents || []) if (id != null) ids.add(id);
  }
  return ids;
}

const compactRecord = (p) => ({
  id: p.id, name: p.name, sex: p.sex, birthDay: p.birthDay, deathDay: p.deathDay, alive: false, departed: p.departed,
  homeId: p.homeId, parents: p.parents, children: p.children, traits: p.traits, job: p.job, partnerId: null,
  history: p.history.slice(-COMPACT_HISTORY),
});

export function compactDead(state, minDeadDays = DEAD_KEEP_DAYS) {
  const keep = protectedIds(state);
  const referenced = referencedIds(state);
  const kept = [];
  let removed = 0;
  for (const p of state.people) {
    if (p.alive || keep.has(p.id) || state.day - (p.deathDay ?? state.day) < minDeadDays) { kept.push(p); continue; }
    if (referenced.has(p.id)) kept.push(compactRecord(p));
    else if (p.departed !== true) removed += 1;
  }
  state.people = kept;
  state.removedDead = (state.removedDead || 0) + removed;
  return removed;
}

export function stepHousekeeping(state) {
  if (state.day % YEAR === 0) compactDead(state);
}
