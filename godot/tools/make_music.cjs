// Musique de fond générée : un thème de jour (harpe et nappes) et un thème de nuit (flûte douce), en boucles sans couture.
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
  const gain = peak > 0 ? 0.85 / peak : 1;
  for (let i = 0; i < n; i++) buf.writeInt16LE(Math.round(Math.max(-1, Math.min(1, samples[i] * gain)) * 32767), 44 + i * 2);
  fs.writeFileSync(path.join(out, name + ".wav"), buf);
}

const midi = (m) => 440 * Math.pow(2, (m - 69) / 12);

// Ajoute un son dans la piste en bouclant : ce qui dépasse la fin revient au début, pour une boucle parfaite.
function mix(track, start, samples, gain) {
  for (let i = 0; i < samples.length; i++) track[(start + i) % track.length] += samples[i] * gain;
}

// Corde pincée (Karplus-Strong) : une harpe douce.
function pluck(freq, seconds, r, bright) {
  const n = Math.floor(seconds * RATE); const period = Math.max(2, Math.round(RATE / freq));
  const ring = Float32Array.from({ length: period }, () => r() * 2 - 1);
  const o = new Float32Array(n); let idx = 0; let last = 0;
  for (let i = 0; i < n; i++) {
    const v = ring[idx]; const next = ring[(idx + 1) % period];
    const avg = (v + next) * 0.5 * (0.994 + bright * 0.004);
    ring[idx] = avg; idx = (idx + 1) % period;
    last += 0.35 * (v - last);
    o[i] = last * Math.min(1, i / 60);
  }
  return o;
}

// Nappe : accord tenu, attaque et relâche lentes, léger désaccord pour la chaleur.
function pad(notes, seconds) {
  const n = Math.floor(seconds * RATE); const o = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const t = i / RATE; const env = Math.min(1, t / 1.6) * Math.min(1, (seconds - t) / 1.8);
    let v = 0;
    for (const m of notes) { const f = midi(m); v += Math.sin(2 * Math.PI * f * t) + 0.5 * Math.sin(2 * Math.PI * f * 1.003 * t) + 0.12 * Math.sin(4 * Math.PI * f * t); }
    o[i] = v * env / notes.length;
  }
  return o;
}

// Flûte douce : sinus avec un souffle et un vibrato qui arrive doucement.
function flute(m, seconds, r) {
  const n = Math.floor(seconds * RATE); const o = new Float32Array(n); const f = midi(m); let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / RATE; const env = Math.min(1, t / 0.12) * Math.min(1, (seconds - t) / 0.35);
    const vib = 1 + 0.006 * Math.sin(2 * Math.PI * 5 * t) * Math.min(1, t / 0.6);
    ph += 2 * Math.PI * f * vib / RATE;
    o[i] = (Math.sin(ph) + 0.18 * Math.sin(2 * ph) + (r() * 2 - 1) * 0.04) * env;
  }
  return o;
}

function lowpass(s, a) { let y = 0; for (let i = 0; i < s.length; i++) { y += a * (s[i] - y); s[i] = y; } return s; }

function song(opts) {
  const r = rng(opts.seed);
  const beat = 60 / opts.bpm; const barLen = beat * 4;
  const bars = opts.chords.length * opts.rounds;
  const track = new Float32Array(Math.floor(bars * barLen * RATE));
  let degree = 2;
  for (let bar = 0; bar < bars; bar++) {
    const chord = opts.chords[bar % opts.chords.length];
    const at = (b) => Math.floor((bar * barLen + b * beat) * RATE);
    if (bar % 2 == 0) mix(track, at(0), pad(chord.map((m) => m + 12), barLen * 2 + 1.5), opts.padGain);
    mix(track, at(0), pluck(midi(chord[0] - 12), 3.5, r, 0), opts.bassGain);
    mix(track, at(2), pluck(midi(chord[0] - 12 + 7), 3.0, r, 0), opts.bassGain * 0.7);
    const rest = bar % 8 >= 6 && opts.breathe;
    for (let b = 0; b < 4; b++) {
      if (rest || r() > opts.density) continue;
      degree = Math.max(0, Math.min(opts.scale.length - 1, degree + Math.floor(r() * 5) - 2));
      const note = opts.scale[degree];
      const half = r() < opts.eighths;
      for (let k = 0; k < (half ? 2 : 1); k++) {
        const pick = k == 0 ? note : opts.scale[Math.max(0, Math.min(opts.scale.length - 1, degree + (r() < 0.5 ? -1 : 1)))];
        const start = at(b + k * 0.5);
        if (opts.voice == "harp") mix(track, start, pluck(midi(pick), 2.6, r, 1), opts.leadGain);
        else mix(track, start, flute(pick, beat * (half ? 0.5 : r() < 0.5 ? 1 : 2) * 0.95, r), opts.leadGain);
      }
    }
  }
  return lowpass(track, 0.55);
}

fs.mkdirSync(out, { recursive: true });
// Jour : do majeur pentatonique, harpe, nappes C, Am, F, G.
write("music_day", song({
  seed: 21, bpm: 76, rounds: 4, voice: "harp", density: 0.55, eighths: 0.3, breathe: true,
  chords: [[60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62], [60, 64, 67], [57, 60, 64], [53, 57, 60], [55, 59, 62]],
  scale: [67, 69, 72, 74, 76, 79, 81, 84], padGain: 0.22, bassGain: 0.5, leadGain: 0.55,
}));
// Nuit : la mineur pentatonique, flûte lente, nappes Am, Em, F, C.
write("music_night", song({
  seed: 5, bpm: 58, rounds: 4, voice: "flute", density: 0.32, eighths: 0.1, breathe: true,
  chords: [[57, 60, 64], [52, 55, 59], [53, 57, 60], [48, 52, 55], [57, 60, 64], [52, 55, 59], [50, 53, 57], [52, 56, 59]],
  scale: [64, 67, 69, 72, 74, 76, 79], padGain: 0.3, bassGain: 0.35, leadGain: 0.28,
}));
console.log("music_day music_night");
