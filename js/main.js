import { createState, catchUp, advance, takeSummary, tick, WEATHER_ICON } from './simulation.js';
import { saveWorld, loadWorld, currentWorldId, deleteWorld } from './save.js';
import { createCamera, attachControls, focusOn, updateCamera } from './camera.js';
import { render } from './render.js';
import { RARE } from './events.js';
import { migrateState } from './migrate.js';
import { usePower } from './powers.js';
import { goTo, onTap, refreshSelection } from './navigation.js';
import * as ui from './ui.js';
import * as panels from './panels.js';

const canvas = document.getElementById('world');
const ctx = canvas.getContext('2d');
const app = { state: null, cam: createCamera(canvas), selection: null, journalFilter: 'all' };
let speed = 1;
let lastFrame = performance.now();
let lastSave = Date.now();
let lastSeq = 0;
let saveWarned = false;
const ANNOUNCED_TYPES = ['migration', 'zombie', 'epidemie_fin', 'diffusion', 'attaque', 'bataille', 'commerce', 'ralliement', 'conversion', 'temple'];

function resize() {
  const dpr = Math.min(2, window.devicePixelRatio || 1);
  canvas.width = window.innerWidth * dpr;
  canvas.height = window.innerHeight * dpr;
  canvas.style.width = `${window.innerWidth}px`;
  canvas.style.height = `${window.innerHeight}px`;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  app.cam.dpr = dpr;
}
window.addEventListener('resize', resize);
resize();

function syncJournal() {
  lastSeq = app.state.journalSeq || 0;
}

function saveNow() {
  if (saveWorld(app.state) || saveWarned) return;
  saveWarned = true;
  ui.toast('💾 Sauvegarde impossible : mémoire pleine');
}

function welcomeBack() {
  const { elapsedMs, days } = catchUp(app.state, Date.now());
  if (days > 0) ui.showModal(ui.returnModal(app.state, takeSummary(app.state), elapsedMs, days));
  syncJournal();
}

function focusHome() {
  const home = app.state.settlements.find((s) => !s.abandoned) || app.state.settlements[0];
  focusOn(app.cam, home.x, home.y);
}

function boot() {
  const id = currentWorldId();
  const saved = id ? loadWorld(id) : null;
  if (saved) {
    app.state = migrateState(saved);
    welcomeBack();
  } else {
    app.state = createState('Noria');
    saveNow();
    ui.showModal(ui.menuModal(app.state));
  }
  syncJournal();
  focusHome();
  saveNow();
}

function switchWorld(next) {
  app.state = next;
  app.selection = null;
  syncJournal();
  focusHome();
  saveNow();
}

function action(act) {
  const state = app.state;
  const [kind, a, b] = act.split(':');
  if (kind === 'follow') {
    const id = Number(a);
    state.followed = state.followed.includes(id) ? state.followed.filter((x) => x !== id) : [...state.followed, id];
    refreshSelection(app);
  } else if (kind === 'goto') focusOn(app.cam, Number(a), Number(b));
  else if (kind === 'journal') { app.journalFilter = a; ui.showPanel(panels.journalPanel(state, app.journalFilter)); }
  else if (kind === 'power') runPower(a);
  else if (kind === 'close-modal') ui.hideModal();
  else if (kind === 'menu') ui.showModal(ui.menuModal(state));
  else if (kind === 'new-world') {
    const name = (document.getElementById('new-name').value || 'Monde').trim();
    saveNow();
    switchWorld(createState(name));
    ui.hideModal();
    ui.toast(`🌍 ${name} vient de naître : 20 pionniers s'installent.`);
  } else if (kind === 'load') {
    saveNow();
    const loaded = loadWorld(a);
    ui.hideModal();
    if (loaded) { switchWorld(migrateState(loaded)); welcomeBack(); }
  } else if (kind === 'delete') { deleteWorld(a); ui.showModal(ui.menuModal(state)); }
}

function runPower(name) {
  if (name === 'zombie') {
    ui.showModal(ui.confirmModal('Réveiller les morts ?', 'Des habitants mourront. Cela pourrait détruire ta planète.', 'power:zombie-go'));
    return;
  }
  if (name === 'zombie-go') ui.hideModal();
  const msg = usePower(app.state, name === 'zombie-go' ? 'zombie' : name);
  if (msg) ui.toast(msg);
  ui.showPanel(panels.powersPanel(app.state));
}

function announceNew() {
  const state = app.state;
  const count = Math.min((state.journalSeq || 0) - lastSeq, state.journal.length);
  const fresh = count > 0 ? state.journal.slice(-count).filter((e) => e.type !== 'couple_silent') : [];
  syncJournal();
  for (const e of fresh.slice(-2)) {
    const followed = state.followed.includes(e.personId) || (e.civId != null && state.followed.includes(e.civId));
    const important = RARE.has(e.type) || ANNOUNCED_TYPES.includes(e.type) || followed;
    if (important || Math.random() < 0.25) ui.toast(e.text, e.x !== undefined ? () => focusOn(app.cam, e.x, e.y) : null);
  }
}

function frame(now) {
  requestAnimationFrame(frame);
  const state = app.state;
  const dt = Math.min(200, now - lastFrame);
  lastFrame = now;
  const ticks = advance(state, dt, speed);
  if (ticks) { announceNew(); if (app.selection) refreshSelection(app); }
  if (state.ended && !state.endingShown) { state.endingShown = true; ui.showModal(ui.endingModal(state)); }
  updateCamera(app.cam);
  const living = render(ctx, app.cam, state, app.selection);
  ui.updateHud(state, WEATHER_ICON[state.weather] || '☀️', living);
  if (Date.now() - lastSave > 20000) { lastSave = Date.now(); saveNow(); }
}

document.body.addEventListener('click', (e) => {
  const el = e.target.closest('[data-goto], [data-action], [data-speed], .close');
  if (!el) return;
  if (el.dataset.goto) goTo(app, el.dataset.goto);
  else if (el.dataset.action) action(el.dataset.action);
  else if (el.dataset.speed !== undefined) { speed = Number(el.dataset.speed); ui.setSpeedButtons(speed); }
  else if (el.classList.contains('close')) { ui.hidePanel(); app.selection = null; }
});
document.getElementById('btn-journal').addEventListener('click', () => ui.showPanel(panels.journalPanel(app.state, app.journalFilter)));
document.getElementById('btn-stats').addEventListener('click', () => ui.showPanel(panels.statsPanel(app.state)));
document.getElementById('btn-powers').addEventListener('click', () => ui.showPanel(panels.powersPanel(app.state)));
document.getElementById('btn-menu').addEventListener('click', () => ui.showModal(ui.menuModal(app.state)));
document.addEventListener('visibilitychange', () => {
  if (document.hidden) { saveNow(); return; }
  welcomeBack();
  lastFrame = performance.now();
});
window.addEventListener('pagehide', saveNow);

attachControls(app.cam, (x, y) => onTap(app, x, y));
boot();
requestAnimationFrame(frame);
if ('serviceWorker' in navigator && location.protocol !== 'file:') navigator.serviceWorker.register('sw.js').catch(() => {});
if (location.search.includes('debug')) {
  window.__app = app;
  window.__simulate = (days) => {
    for (let i = 0; i < days; i++) tick(app.state);
    return { day: app.state.day, pop: app.state.people.filter((p) => p.alive).length, civs: app.state.civs.length, wars: app.state.wars.length };
  };
}
