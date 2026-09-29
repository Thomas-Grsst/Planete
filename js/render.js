import { SIZE, BIOMES } from './world.js';
import { project, TILE_W, TILE_H, ELEV } from './camera.js';
import { SPECIES } from './animals.js';
import { tree, house, campfire, person, orePebbles, temple } from './decor.js';
import { drawNightOverlay, drawLights, nightAlpha } from './daylight.js';
import { dayPhase } from './simulation.js';
import { territoryMap } from './territory.js';
import { drawTerritory, civColors } from './borders.js';

const WEATHER_TINT = { rain: 'rgba(40,60,90,0.25)', storm: 'rgba(20,30,50,0.4)', cloud: 'rgba(60,70,80,0.15)', drought: 'rgba(200,120,40,0.15)', snow: 'rgba(220,230,255,0.25)', sun: null };
const NONE = [];

export function render(ctx, cam, state, selection) {
  const { canvas } = cam;
  ctx.fillStyle = '#0f1a24';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  const world = state.world;
  const hw = (TILE_W / 2) * cam.zoom;
  const hh = (TILE_H / 2) * cam.zoom;
  const overlay = [];
  const buckets = bucketEntities(state);
  const phase = dayPhase(state);
  buckets.lit = nightAlpha(phase) > 0.1;
  buckets.lights = [];
  const colors = civColors(state);
  const territory = colors.size ? territoryMap(state) : null;
  buckets.capitals = new Set(state.civs.filter((c) => c.alive).map((c) => c.capitalId));

  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const t = world.tiles[y * SIZE + x];
      const water = t.biome === 'ocean' || t.biome === 'lake';
      const h = water ? 0.38 : t.height;
      const { sx, sy } = project(cam, x, y, h);
      if (sx < -hw * 2 || sx > canvas.width + hw * 2 || sy < -hh * 8 || sy > canvas.height + hh * 8) continue;
      drawTile(ctx, sx, sy, hw, hh, h, t, cam.zoom, state);
      if (territory) drawTerritory(ctx, { x, y, sx, sy }, hw, hh, territory, colors, cam.zoom);
      overlay.push({ x, y, sx, sy, t });
    }
  }
  for (const o of overlay) drawDecor(ctx, o, cam.zoom, state, selection, buckets);
  const tint = WEATHER_TINT[state.weather];
  if (tint) { ctx.fillStyle = tint; ctx.fillRect(0, 0, canvas.width, canvas.height); }
  if (state.zombies && state.zombies.active) { ctx.fillStyle = 'rgba(40,80,30,0.18)'; ctx.fillRect(0, 0, canvas.width, canvas.height); }
  drawNightOverlay(ctx, canvas, phase);
  drawLights(ctx, buckets.lights, phase);
  return buckets.living;
}

function addTo(map, key, item) {
  const list = map.get(key);
  if (list) list.push(item);
  else map.set(key, [item]);
}

function bucketEntities(state) {
  const buckets = { people: new Map(), settlements: new Map(), herds: new Map(), hordes: new Map(), living: 0 };
  for (const p of state.people) {
    if (!p.alive) continue;
    buckets.living += 1;
    addTo(buckets.people, p.y * SIZE + p.x, p);
  }
  for (const s of state.settlements) addTo(buckets.settlements, s.y * SIZE + s.x, s);
  for (const h of state.herds) addTo(buckets.herds, h.y * SIZE + h.x, h);
  for (const h of state.zombies.hordes) addTo(buckets.hordes, h.y * SIZE + h.x, h);
  return buckets;
}

const settlementPrefix = (st) => (st.fallen ? '☠ ' : st.departed ? '🚀 ' : (st.techs || []).includes('electricite') ? '✨ ' : '');

function personColor(p, sel, followed) {
  if (sel) return '#ffd54f';
  if (followed) return '#8fd3ff';
  if (p.bitten != null) return '#7cb342';
  if (p.sick) return '#c5e1a5';
  return p.sex === 'F' ? '#f48fb1' : '#90caf9';
}

function drawHordes(ctx, hordes, sx, sy, s) {
  for (const h of hordes) {
    ctx.font = `${Math.max(10, 14 * s)}px system-ui`;
    ctx.textAlign = 'center';
    ctx.fillText('🧟', sx - 6 * s, sy + 4 * s);
    if (h.count < 2) continue;
    ctx.fillStyle = '#b9f6ca';
    ctx.font = `${Math.max(8, 9 * s)}px system-ui`;
    ctx.fillText(`×${Math.round(h.count)}`, sx + 8 * s, sy + 6 * s);
  }
}

function drawTile(ctx, sx, sy, hw, hh, h, t, zoom, state) {
  const base = BIOMES[t.biome].color;
  const depth = Math.max(hh * 0.6, (h - 0.34) * ELEV * zoom);
  ctx.fillStyle = shade(base, -0.35);
  ctx.beginPath();
  ctx.moveTo(sx - hw, sy); ctx.lineTo(sx, sy + hh); ctx.lineTo(sx, sy + hh + depth); ctx.lineTo(sx - hw, sy + depth);
  ctx.fill();
  ctx.fillStyle = shade(base, -0.2);
  ctx.beginPath();
  ctx.moveTo(sx + hw, sy); ctx.lineTo(sx, sy + hh); ctx.lineTo(sx, sy + hh + depth); ctx.lineTo(sx + hw, sy + depth);
  ctx.fill();
  let top = base;
  if (state.weather === 'snow' && !['ocean', 'lake', 'river'].includes(t.biome)) top = mix(base, '#e8f0ff', 0.55);
  if (t.biome === 'plain' || t.biome === 'forest') top = mix(top, '#c9a54a', Math.max(0, 1 - t.food / (t.fertility * 12 || 1)) * 0.45);
  ctx.fillStyle = top;
  ctx.beginPath();
  ctx.moveTo(sx, sy - hh); ctx.lineTo(sx + hw, sy); ctx.lineTo(sx, sy + hh); ctx.lineTo(sx - hw, sy);
  ctx.fill();
  ctx.strokeStyle = 'rgba(0,0,0,0.08)';
  ctx.lineWidth = 1;
  ctx.stroke();
}

function drawDecor(ctx, o, zoom, state, selection, buckets) {
  const { x, y, sx, sy, t } = o;
  const s = zoom;
  const key = y * SIZE + x;
  if (t.ore && s >= 0.9) orePebbles(ctx, sx, sy, s, t.ore);
  if (t.trees > 0) {
    const n = Math.min(t.trees, 4);
    for (let i = 0; i < n; i++) {
      const ox = ((i * 37) % 21 - 10) * 0.8 * s;
      const oy = ((i * 53) % 13 - 6) * 0.6 * s;
      tree(ctx, sx + ox, sy + oy, 5 * s, t.biome === 'forest' ? '#2e7d32' : '#4caf50');
    }
  }
  for (const st of buckets.settlements.get(key) || NONE) {
    const n = Math.min(st.houses, 6);
    for (let i = 0; i < n; i++) house(ctx, sx + ((i % 3) - 1) * 9 * s, sy + (Math.floor(i / 3) - 0.5) * 7 * s, 5 * s, buckets.lit ? buckets.lights : null);
    if (!st.abandoned && st.temple) temple(ctx, sx - 13 * s, sy + 5 * s, 4 * s, st.temple > 1, buckets.lit ? buckets.lights : null);
    if (!st.abandoned && (st.techs || []).includes('feu')) campfire(ctx, sx + 12 * s, sy + 6 * s, 3 * s, buckets.lights);
    ctx.fillStyle = selection && selection.type === 'settlement' && selection.id === st.id ? '#ffd54f' : '#fff';
    ctx.font = `${Math.max(10, 11 * s)}px system-ui`;
    ctx.textAlign = 'center';
    ctx.fillText(`${buckets.capitals.has(st.id) ? '🏰 ' : ''}${settlementPrefix(st)}${st.name}`, sx, sy - 16 * s);
  }
  for (const h of buckets.herds.get(key) || NONE) {
    ctx.font = `${Math.max(10, 12 * s)}px system-ui`;
    ctx.textAlign = 'center';
    ctx.fillText(SPECIES[h.species].emoji, sx + 8 * s, sy + 4 * s);
  }
  drawHordes(ctx, buckets.hordes.get(key) || NONE, sx, sy, s);
  let k = 0;
  for (const p of buckets.people.get(key) || NONE) {
    const ox = ((k * 29) % 17 - 8) * s;
    const oy = ((k * 17) % 9 - 4) * s * 0.6;
    k++;
    const sel = selection && selection.type === 'person' && selection.id === p.id;
    const followed = state.followed.includes(p.id);
    person(ctx, sx + ox, sy + oy, s, personColor(p, sel, followed));
    if (sel) { ctx.strokeStyle = '#ffd54f'; ctx.lineWidth = 2; ctx.beginPath(); ctx.arc(sx + ox, sy + oy - 3 * s, 8 * s, 0, Math.PI * 2); ctx.stroke(); }
  }
}




function shade(hex, amount) {
  const [r, g, b] = rgb(hex);
  const f = 1 + amount;
  return `rgb(${clamp(r * f)},${clamp(g * f)},${clamp(b * f)})`;
}

function mix(a, b, t) {
  const A = rgb(a);
  const B = rgb(b);
  return `rgb(${clamp(A[0] + (B[0] - A[0]) * t)},${clamp(A[1] + (B[1] - A[1]) * t)},${clamp(A[2] + (B[2] - A[2]) * t)})`;
}

const cache = new Map();
function rgb(color) {
  if (cache.has(color)) return cache.get(color);
  let out;
  if (color.startsWith('#')) out = [parseInt(color.slice(1, 3), 16), parseInt(color.slice(3, 5), 16), parseInt(color.slice(5, 7), 16)];
  else out = color.match(/\d+/g).slice(0, 3).map(Number);
  cache.set(color, out);
  return out;
}

const clamp = (v) => Math.max(0, Math.min(255, Math.round(v)));
