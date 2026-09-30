const fs = require("fs");
const path = require("path");
const RATE = 22050;
const out = path.join(__dirname, "..", "audio");

function rng(seed) { let s = seed >>> 0; return () => { s = (s + 0x6D2B79F5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; }; }

function write(name, samples) {
  const n = samples.length;
  const buf = Buffer.alloc(44 + n * 2);
  buf.write("RIFF", 0); buf.writeUInt32LE(36 + n * 2, 4); buf.write("WAVE", 8); buf.write("fmt ", 12);
  buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22); buf.writeUInt32LE(RATE, 24);
  buf.writeUInt32LE(RATE * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34); buf.write("data", 36); buf.writeUInt32LE(n * 2, 40);
  let peak = 0;
  for (const v of samples) peak = Math.max(peak, Math.abs(v));
  const gain = peak > 0 ? 0.9 / peak : 1;
  for (let i = 0; i < n; i++) buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i] * gain)) * 32767), 44 + i * 2);
  fs.writeFileSync(path.join(out, name + ".wav"), buf);
}

function loopify(s, fade) {
  const n = s.length - fade;
  const o = new Float32Array(n);
  for (let i = 0; i < n; i++) o[i] = s[i];
  for (let i = 0; i < fade; i++) { const k = i / fade; o[i] = s[i] * k + s[n + i] * (1 - k); }
  return o;
}

function lowpass(s, a) { let y = 0; return s.map((x) => (y += a * (x - y))); }

function noise(seconds, seed) { const r = rng(seed); return Float32Array.from({ length: Math.floor(seconds * RATE) }, () => r() * 2 - 1); }

function env(i, n, attack, release) { const t = i / RATE; const left = (n - i) / RATE; return Math.min(1, t / attack) * Math.min(1, left / release); }

function birds() {
  const n = 30 * RATE; const s = lowpass(lowpass(noise(30, 7), 0.004), 0.004).map((v) => v * 2.5); const r = rng(11);
  for (let k = 0; k < 9; k++) {
    const start = Math.floor(r() * (n - 3 * RATE)); const notes = 2 + Math.floor(r() * 3); const f0 = 1700 + r() * 1100;
    let j0 = start;
    for (let c = 0; c < notes; c++) {
      const len = Math.floor((0.14 + r() * 0.16) * RATE); const f = f0 * (1 + (r() - 0.5) * 0.25); const glide = (r() - 0.5) * 0.12; let ph = 0;
      for (let i = 0; i < len && j0 + i < n; i++) {
        const t = i / len; ph += 2 * Math.PI * f * (1 + glide * t + 0.015 * Math.sin(2 * Math.PI * 28 * i / RATE)) / RATE;
        s[j0 + i] += Math.sin(ph) * Math.sin(Math.PI * t) ** 2 * 0.12;
      }
      j0 += len + Math.floor((0.08 + r() * 0.15) * RATE);
    }
  }
  return loopify(s, RATE);
}

function crickets() {
  const n = 24 * RATE; const s = lowpass(lowpass(noise(24, 3), 0.004), 0.004).map((v) => v * 2.0);
  for (let i = 0; i < n; i++) {
    const t = i / RATE; const group = Math.max(0, Math.sin(2 * Math.PI * 0.35 * t)) ** 2;
    const pulse = Math.max(0, Math.sin(2 * Math.PI * 9 * t)) ** 4 * group;
    s[i] += Math.sin(2 * Math.PI * 3200 * t) * pulse * 0.06;
  }
  return loopify(lowpass(s, 0.5), RATE);
}

function rain() { const s = lowpass(noise(16, 5), 0.25); const r = rng(9); for (let k = 0; k < 900; k++) { const j = Math.floor(r() * (s.length - 200)); for (let i = 0; i < 120; i++) s[j + i] += (r() * 2 - 1) * Math.exp(-i / 18) * 0.6; } return loopify(s, RATE); }

function fire() { const s = lowpass(lowpass(noise(14, 13), 0.02), 0.05); const r = rng(17); for (let k = 0; k < 90; k++) { const j = Math.floor(r() * (s.length - 600)); const amp = 0.05 + r() * 0.12; for (let i = 0; i < 500; i++) s[j + i] += (r() * 2 - 1) * Math.exp(-i / 60) * amp; } return loopify(lowpass(s, 0.2), RATE); }

function tone(seconds, parts, attack, release) { const n = Math.floor(seconds * RATE); const s = new Float32Array(n); for (let i = 0; i < n; i++) { const t = i / RATE; let v = 0; for (const [f, a, d] of parts) v += Math.sin(2 * Math.PI * f * t) * a * Math.exp(-t / d); s[i] = v * env(i, n, attack, release); } return s; }

function arpeggio(notes, step, seconds) { const n = Math.floor(seconds * RATE); const s = new Float32Array(n); notes.forEach((f, k) => { const start = Math.floor(k * step * RATE); for (let i = start; i < n; i++) { const t = (i - start) / RATE; s[i] += (Math.sin(2 * Math.PI * f * t) + 0.3 * Math.sin(4 * Math.PI * f * t)) * Math.exp(-t / 0.6) * 0.4; } }); return s; }

function horn() { const n = Math.floor(2.2 * RATE); const s = new Float32Array(n); for (let i = 0; i < n; i++) { const t = i / RATE; const f = 146 * (1 + 0.03 * Math.min(1, t * 3)); let v = 0; for (let h = 1; h <= 6; h++) v += Math.sin(2 * Math.PI * f * h * t) / h; s[i] = v * env(i, n, 0.25, 0.6); } return lowpass(s, 0.3); }

function thunder() { const s = lowpass(noise(4, 21), 0.03); for (let i = 0; i < s.length; i++) { const t = i / RATE; s[i] *= Math.exp(-t / 1.3) * (t < 0.05 ? t / 0.05 : 1) * (1 + 0.6 * Math.sin(t * 9)); } return s; }

function groan() { const n = Math.floor(1.8 * RATE); const s = new Float32Array(n); const r = rng(31); for (let i = 0; i < n; i++) { const t = i / RATE; const f = 90 + 25 * Math.sin(t * 3.2) - t * 18; s[i] = (Math.sin(2 * Math.PI * f * t) + 0.5 * Math.sin(2 * Math.PI * f * 2.02 * t) + (r() * 2 - 1) * 0.25) * env(i, n, 0.2, 0.5); } return lowpass(s, 0.15); }

fs.mkdirSync(out, { recursive: true });
write("ambient_day", birds());
write("ambient_night", crickets());
write("rain", rain());
write("fire", fire());
write("bell", tone(4, [[523, 0.6, 1.6], [1046, 0.3, 0.9], [1318, 0.2, 0.7], [659, 0.25, 1.2]], 0.005, 0.5));
write("chime", arpeggio([659, 784, 988, 1318], 0.12, 2.2));
write("horn", horn());
write("thunder", thunder());
write("birth", arpeggio([880, 1175], 0.1, 1.0));
write("zombie", groan());
write("miracle", arpeggio([523, 659, 784, 1046, 1318, 1568], 0.09, 3.0));
console.log(fs.readdirSync(out).join(" "));
