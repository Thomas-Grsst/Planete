const NIGHT_ALPHA = 0.62;
const DAWN_END = 0.05;
const DUSK_START = 0.45;
const NIGHT_START = 0.5;

export function nightAlpha(phase) {
  if (phase < DAWN_END) return NIGHT_ALPHA * (1 - phase / DAWN_END);
  if (phase < DUSK_START) return 0;
  if (phase < NIGHT_START) return NIGHT_ALPHA * ((phase - DUSK_START) / (NIGHT_START - DUSK_START));
  return NIGHT_ALPHA;
}

export function clockHour(phase) {
  return Math.floor(6 + phase * 24) % 24;
}

export function isNight(phase) {
  const h = clockHour(phase);
  return h >= 18 || h < 6;
}

function duskTint(phase) {
  const edge = Math.min(Math.abs(phase - DUSK_START - 0.025), Math.abs(phase - 0.025));
  return edge < 0.03 ? 0.18 * (1 - edge / 0.03) : 0;
}

export function drawNightOverlay(ctx, canvas, phase) {
  const tint = duskTint(phase);
  if (tint > 0) {
    ctx.fillStyle = `rgba(255,120,60,${tint.toFixed(3)})`;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  }
  const alpha = nightAlpha(phase);
  if (alpha <= 0) return;
  ctx.fillStyle = `rgba(8,12,40,${alpha.toFixed(3)})`;
  ctx.fillRect(0, 0, canvas.width, canvas.height);
}

export function drawLights(ctx, lights, phase) {
  const strength = nightAlpha(phase) / NIGHT_ALPHA;
  if (strength <= 0.05 || !lights.length) return;
  ctx.save();
  ctx.globalCompositeOperation = 'lighter';
  for (const l of lights) {
    const r = l.r * (l.flicker ? 0.9 + Math.random() * 0.2 : 1);
    const g = ctx.createRadialGradient(l.x, l.y, 0, l.x, l.y, r);
    g.addColorStop(0, `rgba(${l.color},${(0.75 * strength).toFixed(3)})`);
    g.addColorStop(1, `rgba(${l.color},0)`);
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(l.x, l.y, r, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.restore();
}
