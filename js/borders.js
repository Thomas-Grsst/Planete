import { SIZE } from './world.js';

const FILL_ALPHA = '52';
const EDGES = [
  [-1, 0, 'left', 'top'],
  [0, -1, 'top', 'right'],
  [1, 0, 'right', 'bottom'],
  [0, 1, 'bottom', 'left'],
];

function owner(map, x, y) {
  if (x < 0 || y < 0 || x >= SIZE || y >= SIZE) return -1;
  return map[y * SIZE + x];
}

export function civColors(state) {
  const colors = new Map();
  for (const c of state.civs) if (c.alive) colors.set(c.id, c.color);
  return colors;
}

export function drawTerritory(ctx, o, hw, hh, map, colors, zoom) {
  const id = owner(map, o.x, o.y);
  const color = colors.get(id);
  if (!color) return;
  const { sx, sy } = o;
  const corner = { top: [sx, sy - hh], right: [sx + hw, sy], bottom: [sx, sy + hh], left: [sx - hw, sy] };
  ctx.fillStyle = `${color}${FILL_ALPHA}`;
  ctx.beginPath();
  ctx.moveTo(...corner.top); ctx.lineTo(...corner.right); ctx.lineTo(...corner.bottom); ctx.lineTo(...corner.left);
  ctx.fill();
  ctx.strokeStyle = color;
  ctx.lineWidth = Math.max(1.5, 2.4 * zoom);
  for (const [dx, dy, from, to] of EDGES) {
    if (owner(map, o.x + dx, o.y + dy) === id) continue;
    ctx.beginPath();
    ctx.moveTo(...corner[from]);
    ctx.lineTo(...corner[to]);
    ctx.stroke();
  }
}
