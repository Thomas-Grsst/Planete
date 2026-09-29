import { SIZE } from './world.js';

export const TILE_W = 44;
export const TILE_H = 22;
export const ELEV = 70;

export function createCamera(canvas) {
  const cam = { x: 0, y: 0, zoom: 1.4, target: null, canvas };
  cam.x = 0;
  cam.y = (SIZE * TILE_H) / 2;
  return cam;
}

export function project(cam, x, y, h = 0) {
  const wx = (x - y) * (TILE_W / 2);
  const wy = (x + y) * (TILE_H / 2) - h * ELEV;
  return {
    sx: (wx - cam.x) * cam.zoom + cam.canvas.width / 2,
    sy: (wy - cam.y) * cam.zoom + cam.canvas.height / 2,
  };
}

export function screenToTile(cam, sx, sy, world) {
  const wx = (sx - cam.canvas.width / 2) / cam.zoom + cam.x;
  let best = null;
  let bestD = Infinity;
  for (let h = 0; h <= 1; h += 0.1) {
    const wy = (sy - cam.canvas.height / 2) / cam.zoom + cam.y + h * ELEV;
    const a = wx / (TILE_W / 2);
    const b = wy / (TILE_H / 2);
    const x = Math.round((a + b) / 2);
    const y = Math.round((b - a) / 2);
    if (x < 0 || y < 0 || x >= SIZE || y >= SIZE) continue;
    const t = world.tiles[y * SIZE + x];
    const th = t.biome === 'ocean' || t.biome === 'lake' ? 0.38 : t.height;
    const d = Math.abs(th - h);
    if (d < bestD) { bestD = d; best = { x, y }; }
  }
  return best;
}

export function focusOn(cam, x, y, h = 0.5) {
  cam.target = { x: (x - y) * (TILE_W / 2), y: (x + y) * (TILE_H / 2) - h * ELEV };
}

export function updateCamera(cam) {
  if (!cam.target) return;
  cam.x += (cam.target.x - cam.x) * 0.15;
  cam.y += (cam.target.y - cam.y) * 0.15;
  if (Math.abs(cam.target.x - cam.x) + Math.abs(cam.target.y - cam.y) < 0.5) cam.target = null;
}

export function attachControls(cam, onTap) {
  const c = cam.canvas;
  const pointers = new Map();
  let start = null;
  let lastDist = 0;
  let moved = false;

  c.addEventListener('pointerdown', (e) => {
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    start = { x: e.clientX, y: e.clientY };
    moved = false;
    cam.target = null;
    if (pointers.size === 2) lastDist = dist(pointers);
  });
  c.addEventListener('pointermove', (e) => {
    if (!pointers.has(e.pointerId)) return;
    const prev = pointers.get(e.pointerId);
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size === 1) {
      cam.x -= (e.clientX - prev.x) / cam.zoom;
      cam.y -= (e.clientY - prev.y) / cam.zoom;
      if (Math.hypot(e.clientX - start.x, e.clientY - start.y) > 6) moved = true;
    } else if (pointers.size === 2) {
      const d = dist(pointers);
      if (lastDist) zoomBy(cam, d / lastDist);
      lastDist = d;
      moved = true;
    }
  });
  const up = (e) => {
    pointers.delete(e.pointerId);
    if (pointers.size < 2) lastDist = 0;
    if (pointers.size === 0 && !moved && start) onTap(e.clientX, e.clientY);
  };
  c.addEventListener('pointerup', up);
  c.addEventListener('pointercancel', up);
  c.addEventListener('wheel', (e) => { e.preventDefault(); zoomBy(cam, e.deltaY < 0 ? 1.1 : 0.9); }, { passive: false });
}

function zoomBy(cam, f) {
  cam.zoom = Math.max(0.5, Math.min(4, cam.zoom * f));
}

function dist(pointers) {
  const [a, b] = [...pointers.values()];
  return Math.hypot(a.x - b.x, a.y - b.y);
}
