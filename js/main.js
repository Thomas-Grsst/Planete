import { createState, catchUp, advance, takeSummary, tick, WEATHER_ICON } from './simulation.js';
import { saveWorld, loadWorld, currentWorldId, deleteWorld } from './save.js';
import { createCamera, attachControls, screenToTile, focusOn, updateCamera } from './camera.js';
import { render } from './render.js';
import { tileAt } from './world.js';
import { RARE } from './events.js';
import { migrateState } from './migrate.js';
import { usePower } from './powers.js';
import * as ui from './ui.js';
import * as panels from './panels.js';

const canvas = document.getElementById('world');
const ctx = canvas.getContext('2d');
const cam = createCamera(canvas);
let state = null;
let speed = 1;
let selection = null;
let journalFilter = 'all';
let lastFrame = performance.now();
let lastSave = Date.now();
let lastSeq = 0;
let saveWarned = false;
const ANNOUNCED_TYPES = ['migration', 'zombie', 'epidemie_fin', 'diffusion', 'attaque'];

function resize() {
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  canvas.width = window.innerWidth * dpr;
  canvas.height = window.innerHeight * dpr;
  canvas.style.width = `${window.innerWidth}px`;
  canvas.style.height = `${window.innerHeight}px`;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  cam.dpr = dpr;
}
window.addEventListener('resize', resize);
resize();

function syncJournal() {
  lastSeq = state.journalSeq || 0;
}

function saveNow() {
  if (saveWorld(state) || saveWarned) return;
  saveWarned = true;
  ui.toast('💾 Sauvegarde impossible : mémoire pleine');
}

function welcomeBack() {
  const { elapsedMs, days } = catchUp(state, Date.now());
  if (days > 0) ui.showModal(ui.returnModal(state, takeSummary(state), elapsedMs, days));
  syncJournal();
}

function boot() {
  const id = currentWorldId();
  const saved = id ? loadWorld(id) : null;
  if (saved) {
    state = migrateState(saved);
    welcomeBack();
  } else {
    state = createState('Noria');
    saveNow();
    ui.showModal(ui.menuModal(state));
  }
  syncJournal();
  const home = state.settlements[0];
  focusOn(cam, home.x, home.y);
  saveNow();
}

function goTo(ref) {
  const [kind, a, b] = ref.split(':');
  if (kind === 'person') {
    const p = state.people.find((q) => q.id === Number(a));
    if (!p) return;
    selection = { type: 'person', id: p.id };
    if (p.alive) focusOn(cam, p.x, p.y);
    ui.showPanel(panels.personPanel(state, p));
  } else if (kind === 'settlement') {
    const s = state.settlements.find((q) => q.id === Number(a));
    if (!s) return;
    selection = { type: 'settlement', id: s.id };
    focusOn(cam, s.x, s.y);
    ui.showPanel(panels.settlementPanel(state, s));
  } else if (kind === 'tile') {
    focusOn(cam, Number(a), Number(b));
    ui.hideModal();
  }
}

function onTap(cx, cy) {
  const dpr = cam.dpr || 1;
  const t = screenToTile(cam, cx * dpr, cy * dpr, state.world);
  if (!t) { selection = null; ui.hidePanel(); return; }
  const person = state.people.find((p) => p.alive && p.x === t.x && p.y === t.y);
  if (person) return goTo(`person:${person.id}`);
  const settlement = state.settlements.find((s) => Math.abs(s.x - t.x) <= 1 && Math.abs(s.y - t.y) <= 1);
  if (settlement) return goTo(`settlement:${settlement.id}`);
  selection = null;
  ui.showPanel(panels.tilePanel(state, t.x, t.y, tileAt(state.world, t.x, t.y)));
}

function action(act) {
  const [kind, a, b] = act.split(':');
  if (kind === 'follow') {
    const id = Number(a);
    state.followed = state.followed.includes(id) ? state.followed.filter((x) => x !== id) : [...state.followed, id];
    refreshSelection();
  } else if (kind === 'goto') focusOn(cam, Number(a), Number(b));
  else if (kind === 'journal') { journalFilter = a; ui.showPanel(panels.journalPanel(state, journalFilter)); }
  else if (kind === 'power') runPower(a);
  else if (kind === 'close-modal') ui.hideModal();
  else if (kind === 'menu') ui.showModal(ui.menuModal(state));
  else if (kind === 'new-world') {
    const name = (document.getElementById('new-name').value || 'Monde').trim();
    saveNow();
    state = createState(name);
    selection = null;
    syncJournal();
    focusOn(cam, state.settlements[0].x, state.settlements[0].y);
    saveNow();
    ui.hideModal();
    ui.toast(`🌍 ${name} vient de naître : 20 pionniers s'installent.`);
  } else if (kind === 'load') {
    saveNow();
    const loaded = loadWorld(a);
    ui.hideModal();
    if (loaded) { state = migrateState(loaded); selection = null; welcomeBack(); focusOn(cam, state.settlements[0].x, state.settlements[0].y); saveNow(); }
  } else if (kind === 'delete') { deleteWorld(a); ui.showModal(ui.menuModal(state)); }
}

function runPower(name) {
  if (name === 'zombie') {
    ui.showModal(ui.confirmModal('Réveiller les morts ?', 'Des habitants mourront. Cela pourrait détruire ta planète.', 'power:zombie-go'));
    return;
  }
  if (name === 'zombie-go') ui.hideModal();
  const msg = usePower(state, name === 'zombie-go' ? 'zombie' : name);
  if (msg) ui.toast(msg);
  ui.showPanel(panels.powersPanel(state));
}

function refreshSelection() {
  if (!selection) return;
  if (selection.type === 'person') { const p = state.people.find((q) => q.id === selection.id); if (p) ui.showPanel(panels.personPanel(state, p)); }
  if (selection.type === 'settlement') { const s = state.settlements.find((q) => q.id === selection.id); if (s) ui.showPanel(panels.settlementPanel(state, s)); }
}

function announceNew() {
  const count = Math.min((state.journalSeq || 0) - lastSeq, state.journal.length);
  const fresh = count > 0 ? state.journal.slice(-count).filter((e) => e.type !== 'couple_silent') : [];
  syncJournal();
  for (const e of fresh.slice(-2)) {
    const important = RARE.has(e.type) || ANNOUNCED_TYPES.includes(e.type) || state.followed.includes(e.personId);
    if (important || Math.random() < 0.25) ui.toast(e.text, e.x !== undefined ? () => focusOn(cam, e.x, e.y) : null);
  }
}

function frame(now) {
  requestAnimationFrame(frame);
  const dt = Math.min(200, now - lastFrame);
  lastFrame = now;
  const ticks = advance(state, dt, speed);
  if (ticks) { announceNew(); if (selection) refreshSelection(); }
  if (state.ended && !state.endingShown) { state.endingShown = true; ui.showModal(ui.endingModal(state)); }
  updateCamera(cam);
  const living = render(ctx, cam, state, selection);
  ui.updateHud(state, WEATHER_ICON[state.weather] || '☀️', living);
  if (Date.now() - lastSave > 20000) { lastSave = Date.now(); saveNow(); }
}

document.body.addEventListener('click', (e) => {
  const el = e.target.closest('[data-goto], [data-action], [data-speed], .close');
  if (!el) return;
  if (el.dataset.goto) goTo(el.dataset.goto);
  else if (el.dataset.action) action(el.dataset.action);
  else if (el.dataset.speed !== undefined) { speed = Number(el.dataset.speed); ui.setSpeedButtons(speed); }
  else if (el.classList.contains('close')) { ui.hidePanel(); selection = null; }
});
document.getElementById('btn-journal').addEventListener('click', () => ui.showPanel(panels.journalPanel(state, journalFilter)));
document.getElementById('btn-stats').addEventListener('click', () => ui.showPanel(panels.statsPanel(state)));
document.getElementById('btn-powers').addEventListener('click', () => ui.showPanel(panels.powersPanel(state)));
document.getElementById('btn-menu').addEventListener('click', () => ui.showModal(ui.menuModal(state)));
document.addEventListener('visibilitychange', () => {
  if (document.hidden) { saveNow(); return; }
  welcomeBack();
  lastFrame = performance.now();
});
window.addEventListener('pagehide', saveNow);

attachControls(cam, onTap);
boot();
requestAnimationFrame(frame);
if ('serviceWorker' in navigator && location.protocol !== 'file:') navigator.serviceWorker.register('sw.js').catch(() => {});
if (location.search.includes('debug')) {
  window.__simulate = (days) => {
    for (let i = 0; i < days; i++) tick(state);
    return { day: state.day, pop: state.people.filter((p) => p.alive).length, discoveries: state.discoveries, apocalypses: state.zombies.count };
  };
}
