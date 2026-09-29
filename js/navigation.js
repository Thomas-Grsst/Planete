import { screenToTile, focusOn } from './camera.js';
import { tileAt } from './world.js';
import { civById } from './civs.js';
import * as ui from './ui.js';
import * as panels from './panels.js';

function capitalOf(state, civ) {
  return state.settlements.find((s) => s.id === civ.capitalId) || null;
}

export function goTo(app, ref) {
  const { state, cam } = app;
  const [kind, a, b] = ref.split(':');
  if (kind === 'person') {
    const p = state.people.find((q) => q.id === Number(a));
    if (!p) return;
    app.selection = { type: 'person', id: p.id };
    if (p.alive) focusOn(cam, p.x, p.y);
    ui.showPanel(panels.personPanel(state, p));
  } else if (kind === 'settlement') {
    const s = state.settlements.find((q) => q.id === Number(a));
    if (!s) return;
    app.selection = { type: 'settlement', id: s.id };
    focusOn(cam, s.x, s.y);
    ui.showPanel(panels.settlementPanel(state, s));
  } else if (kind === 'civ') {
    const civ = civById(state, Number(a));
    if (!civ) return;
    app.selection = { type: 'civ', id: civ.id };
    const capital = capitalOf(state, civ);
    if (capital) focusOn(cam, capital.x, capital.y);
    ui.hideModal();
    ui.showPanel(panels.civPanel(state, civ));
  } else if (kind === 'tile') {
    focusOn(cam, Number(a), Number(b));
    ui.hideModal();
  }
}

export function onTap(app, cx, cy) {
  const { state, cam } = app;
  const dpr = cam.dpr || 1;
  const t = screenToTile(cam, cx * dpr, cy * dpr, state.world);
  if (!t) { app.selection = null; ui.hidePanel(); return; }
  const person = state.people.find((p) => p.alive && p.x === t.x && p.y === t.y);
  if (person) { goTo(app, `person:${person.id}`); return; }
  const settlement = state.settlements.find((s) => Math.abs(s.x - t.x) <= 1 && Math.abs(s.y - t.y) <= 1);
  if (settlement) { goTo(app, `settlement:${settlement.id}`); return; }
  app.selection = null;
  ui.showPanel(panels.tilePanel(state, t.x, t.y, tileAt(state.world, t.x, t.y)));
}

export function refreshSelection(app) {
  const { state, selection } = app;
  if (!selection) return;
  if (selection.type === 'person') {
    const p = state.people.find((q) => q.id === selection.id);
    if (p) ui.showPanel(panels.personPanel(state, p));
  } else if (selection.type === 'settlement') {
    const s = state.settlements.find((q) => q.id === selection.id);
    if (s) ui.showPanel(panels.settlementPanel(state, s));
  } else if (selection.type === 'civ') {
    const civ = civById(state, selection.id);
    if (civ) ui.showPanel(panels.civPanel(state, civ));
  }
}
