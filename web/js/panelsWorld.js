import { RARE, formatDay, plural } from './events.js';
import { TECHS, TECH_ORDER, ANCIENTS_NAME } from './techTree.js';
import { SPECIES, animalPopulation } from './animals.js';
import { ageOf, ADULT_AGE } from './people.js';
import { zombiePowerState } from './powers.js';
import { civSection } from './panelsCiv.js';
import { civById, civTitle } from './civs.js';
import { faithSection, legendsSection, prayersBlock } from './panelsFaith.js';

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const WEATHER_LABELS = { sun: '☀️ soleil', cloud: '☁️ nuageux', rain: '🌧️ pluie', storm: '⛈️ tempête', drought: '🔥 sécheresse', snow: '❄️ neige' };

const ZOMBIE_TYPES = new Set(['zombie', 'apocalypse', 'apocalypse_fin']);
const JOURNAL_FILTERS = [['all', 'Tout'], ['followed', '👁️ Suivis'], ['rare', '⭐ Marquants']];
const EMPTY_JOURNAL = {
  all: 'Rien pour l\'instant.',
  followed: 'Aucune nouvelle de tes suivis pour l\'instant.',
  rare: 'Rien de marquant pour l\'instant.',
};

const isRare = (e) => RARE.has(e.type) || e.highlight === true;

function normalizeFilter(filter) {
  if (filter === true) return 'followed';
  return EMPTY_JOURNAL[filter] ? filter : 'all';
}

function matchesFilter(state, e, filter) {
  if (e.type === 'couple_silent') return false;
  if (filter === 'followed') return state.followed.includes(e.personId) || (e.civId != null && state.followed.includes(e.civId));
  if (filter === 'rare') return isRare(e);
  return true;
}

function journalEntry(e) {
  const classes = ['entry', isRare(e) ? 'rare' : '', ZOMBIE_TYPES.has(e.type) ? 'zombie' : ''].filter(Boolean).join(' ');
  const goto = e.personId ? `person:${e.personId}` : e.x !== undefined ? `tile:${e.x}:${e.y}` : '';
  return `<div class="${classes}"${goto ? ` data-goto="${goto}"` : ''}><span class="d">${formatDay(e.day)}</span>${esc(e.text)}</div>`;
}

export function journalPanel(state, filter) {
  const active = normalizeFilter(filter);
  const entries = state.journal.filter((e) => matchesFilter(state, e, active));
  const buttons = JOURNAL_FILTERS.map(([key, label]) => `<button data-action="journal:${key}" class="${active === key ? 'active' : ''}">${label}</button>`).join('');
  return `
    <h2>📜 Journal du monde</h2>
    <div class="row">${buttons}</div>
    ${entries.slice(-120).reverse().map(journalEntry).join('') || `<p class="muted">${EMPTY_JOURNAL[active]}</p>`}`;
}

function populationBySettlement(alive) {
  const pops = new Map();
  for (const p of alive) pops.set(p.homeId, (pops.get(p.homeId) || 0) + 1);
  return pops;
}

function settlementLine(s, pop) {
  const marks = `${s.chefId != null ? ' 👑' : ''}${s.outbreak ? ' 🦠' : ''}`;
  return `<li data-goto="settlement:${s.id}">${esc(s.name)}${marks} <span class="muted">· ${esc(s.level)} · ${pop} hab.</span></li>`;
}

function worldStatus(state, active) {
  const lines = [`<p>🦠 Épidémies en cours : ${active.filter((s) => s.outbreak).length}</p>`];
  const z = state.zombies;
  if (z && z.active) lines.push(`<p style="color:#b9f6ca">🧟 Apocalypse : ${plural(z.hordes.length, 'horde')} · ${plural(z.dead, 'mort')} · depuis ${state.day - z.startDay} j</p>`);
  else if (z && z.count > 0) lines.push(`<p class="muted">🕊️ ${plural(z.count, 'apocalypse')} zombie${z.count > 1 ? 's' : ''} surmontée${z.count > 1 ? 's' : ''}</p>`);
  const exodus = state.exodus;
  if (exodus && !exodus.done) {
    const origin = state.settlements.find((s) => s.id === exodus.settlementId);
    lines.push(`<p>🚀 Le grand départ se prépare${origin ? ` à ${esc(origin.name)}` : ''} : dans ${Math.max(0, exodus.launchDay - state.day)} j</p>`);
  }
  if (state.ended) lines.push(`<p>🌌 ${state.ended.departed} habitants partis vers les étoiles (${formatDay(state.ended.day)})</p>`);
  return lines.join('');
}

function discoveryLine(key, d) {
  const t = TECHS[key];
  const name = esc(d.personName || ANCIENTS_NAME);
  const who = d.personId ? `<span class="link" data-goto="person:${d.personId}">${name}</span>` : name;
  const where = d.settlementName ? ` à ${esc(d.settlementName)}` : '';
  return `<p>${t.emoji} ${t.name} — ${who}${where}, ${formatDay(d.day || 0)}</p>`;
}

function knowledgeSection(state) {
  const discoveries = state.discoveries || {};
  const known = TECH_ORDER.filter((k) => discoveries[k]);
  const body = known.map((k) => discoveryLine(k, discoveries[k])).join('') || '<p class="muted">Aucune découverte pour l\'instant.</p>';
  return `<h3>💡 Savoirs · ${known.length}/${TECH_ORDER.length}</h3>${body}`;
}

const followedMark = (p) => (p.alive ? '' : p.departed === true ? ' 🚀' : ' ✝');

function followedSection(state) {
  if (!state.followed.length) return '<p class="muted">Touche un habitant ou un village, puis « Suivre ».</p>';
  return state.followed.map((id) => {
    const p = state.people.find((q) => q.id === id);
    if (p) return `<p><span class="link" data-goto="person:${p.id}">${esc(p.name)}</span>${followedMark(p)}</p>`;
    const s = state.settlements.find((q) => q.id === id);
    if (s) return `<p><span class="link" data-goto="settlement:${s.id}">${esc(s.name)}</span></p>`;
    const c = civById(state, id);
    return c ? `<p><span class="link" data-goto="civ:${c.id}">🏰 ${esc(civTitle(c, true))}</span></p>` : '';
  }).join('');
}

export function statsPanel(state) {
  const alive = state.people.filter((p) => p.alive);
  const kids = alive.filter((p) => ageOf(state, p) < ADULT_AGE).length;
  const dead = state.people.filter((p) => !p.alive && p.departed !== true).length + (state.removedDead || 0);
  const active = state.settlements.filter((s) => !s.abandoned);
  const pops = populationBySettlement(alive);
  return `
    <h2>👥 ${alive.length} habitants</h2>
    <p class="muted">${kids} enfants · ${dead} morts depuis le début</p>
    ${worldStatus(state, active)}
    <h3>Colonies</h3>
    <ul class="list">${active.map((s) => settlementLine(s, pops.get(s.id) || 0)).join('')}</ul>
    ${civSection(state)}
    ${faithSection(state)}
    ${legendsSection(state)}
    ${knowledgeSection(state)}
    <h3>Animaux</h3>
    ${Object.entries(SPECIES).map(([k, sp]) => `<p>${sp.emoji} ${sp.name} : ${animalPopulation(state, k)}</p>`).join('')}
    <h3>Suivis</h3>
    ${followedSection(state)}`;
}

export function powersPanel(state) {
  const zombie = zombiePowerState(state);
  const count = state.powers.zombie || 0;
  const forced = `${state.powers.rain ? ` · pluie forcée ${state.powers.rain} j` : ''}${state.powers.sun ? ` · soleil forcé ${state.powers.sun} j` : ''}`;
  return `
    <h2>✨ Pouvoirs</h2>
    <p class="muted">Interviens ponctuellement. Chaque action a des conséquences.</p>
    <div class="row">
      <button data-action="power:rain">🌧️ Pluie (10 jours)</button>
      <button data-action="power:sun">☀️ Soleil (10 jours)</button>
      <button data-action="power:grow">🌱 Végétation</button>
      <button data-action="power:skip">⏩ Avancer 30 jours</button>
    </div>
    ${prayersBlock(state)}
    <h3>☣️ Interdit aux âmes sensibles</h3>
    <div class="row"><button data-action="power:zombie"${zombie.ready ? '' : ' disabled'}>${zombie.label}</button></div>
    <p class="muted">☣️ Irréversible : des habitants mourront. Tu as déclenché ${plural(count, 'apocalypse')}.</p>
    <p class="muted" style="margin-top:10px">Météo actuelle : ${WEATHER_LABELS[state.weather] || state.weather}${forced}</p>`;
}
