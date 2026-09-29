import { compactDead } from './housekeeping.js';

const KEY = 'petite-planete-save';
const INDEX_KEY = 'petite-planete-worlds';

export function listWorlds() {
  try { return JSON.parse(localStorage.getItem(INDEX_KEY) || '[]'); } catch { return []; }
}

function writeWorld(state) {
  try {
    localStorage.setItem(`${KEY}-${state.id}`, JSON.stringify(state));
    return true;
  } catch {
    return false;
  }
}

export function saveWorld(state) {
  state.lastSimTime = Date.now();
  let saved = writeWorld(state);
  if (!saved) { compactDead(state, 0); saved = writeWorld(state); }
  if (!saved) return false;
  let alive = 0;
  for (const p of state.people) if (p.alive) alive += 1;
  const worlds = listWorlds().filter((w) => w.id !== state.id);
  worlds.unshift({ id: state.id, name: state.name, day: state.day, pop: alive });
  try {
    localStorage.setItem(INDEX_KEY, JSON.stringify(worlds));
    localStorage.setItem(`${KEY}-current`, state.id);
  } catch {
    return false;
  }
  return true;
}

export function loadWorld(id) {
  try {
    const raw = localStorage.getItem(`${KEY}-${id}`);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

export function currentWorldId() {
  try { return localStorage.getItem(`${KEY}-current`); } catch { return null; }
}

export function deleteWorld(id) {
  try {
    localStorage.removeItem(`${KEY}-${id}`);
    localStorage.setItem(INDEX_KEY, JSON.stringify(listWorlds().filter((w) => w.id !== id)));
  } catch {
    return;
  }
}
