import { ORES } from './resources.js';

export function tree(ctx, x, y, r, color) {
  ctx.fillStyle = '#5d4037';
  ctx.fillRect(x - r * 0.15, y, r * 0.3, r * 0.8);
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(x, y - r * 2); ctx.lineTo(x + r, y + r * 0.2); ctx.lineTo(x - r, y + r * 0.2); ctx.fill();
}

export function house(ctx, x, y, r, lights) {
  ctx.fillStyle = '#a1887f';
  ctx.fillRect(x - r, y - r * 0.4, r * 2, r * 1.2);
  ctx.fillStyle = '#6d4c41';
  ctx.fillRect(x, y - r * 0.4, r, r * 1.2);
  ctx.fillStyle = '#c62828';
  ctx.beginPath(); ctx.moveTo(x - r * 1.1, y - r * 0.4); ctx.lineTo(x, y - r * 1.4); ctx.lineTo(x + r * 1.1, y - r * 0.4); ctx.fill();
  if (!lights) return;
  ctx.fillStyle = '#ffd54f';
  ctx.fillRect(x - r * 0.7, y, r * 0.45, r * 0.4);
  lights.push({ x: x - r * 0.5, y: y + r * 0.2, r: r * 2.2, color: '255,200,90', flicker: false });
}

export function campfire(ctx, x, y, r, lights) {
  ctx.fillStyle = '#ff9800';
  ctx.beginPath(); ctx.moveTo(x, y - r * 1.2); ctx.lineTo(x + r * 0.5, y); ctx.lineTo(x - r * 0.5, y); ctx.fill();
  ctx.fillStyle = '#ffeb3b';
  ctx.beginPath(); ctx.moveTo(x, y - r * 0.6); ctx.lineTo(x + r * 0.25, y); ctx.lineTo(x - r * 0.25, y); ctx.fill();
  lights.push({ x, y: y - r * 0.4, r: r * 5, color: '255,140,50', flicker: true });
}

export function temple(ctx, x, y, r, great, lights) {
  const w = great ? r * 1.6 : r * 1.1;
  ctx.fillStyle = '#eceff1';
  ctx.fillRect(x - w, y - r * 0.2, w * 2, r * 0.3);
  ctx.fillStyle = '#cfd8dc';
  const columns = great ? 4 : 3;
  for (let i = 0; i < columns; i++) ctx.fillRect(x - w * 0.85 + (i * w * 1.7) / (columns - 1) - r * 0.12, y - r * 1.1, r * 0.24, r * 0.9);
  ctx.fillStyle = great ? '#ffd54f' : '#b0bec5';
  ctx.beginPath(); ctx.moveTo(x - w * 1.1, y - r * 1.1); ctx.lineTo(x, y - r * (great ? 2 : 1.7)); ctx.lineTo(x + w * 1.1, y - r * 1.1); ctx.fill();
  if (lights) lights.push({ x, y: y - r * 0.6, r: r * (great ? 5 : 3.5), color: '255,230,160', flicker: false });
}

export function person(ctx, x, y, s, color) {
  ctx.fillStyle = color;
  ctx.fillRect(x - 1.5 * s, y - 4 * s, 3 * s, 4 * s);
  ctx.fillStyle = '#ffe0b2';
  ctx.beginPath(); ctx.arc(x, y - 5.5 * s, 1.8 * s, 0, Math.PI * 2); ctx.fill();
}

export function orePebbles(ctx, x, y, s, ore) {
  const def = ORES[ore];
  if (!def) return;
  ctx.fillStyle = def.color;
  ctx.strokeStyle = 'rgba(0,0,0,0.35)';
  ctx.lineWidth = Math.max(0.5, 0.6 * s);
  for (const [ox, oy] of [[-4, 1], [3, -1], [0, 3]]) {
    ctx.beginPath();
    ctx.arc(x + ox * s, y + oy * s, 1.6 * s, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();
  }
}
