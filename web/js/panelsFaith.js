import { formatDay, plural } from './events.js';
import { PRAYERS, POWER_LABELS, capitalize } from './faithData.js';
import { religionById, religionOf, aliveReligions, faithSettlements, religionPopulation, isPlayerFaith, legendById } from './religions.js';
import { aliveCivs, civTitle } from './civs.js';

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const TEMPLE_LABELS = ['', '🛕 temple', '🛕 grand temple'];
const RECENT_LEGENDS = 8;

export const faithLink = (rel) => `<span style="color:${rel.color}">${rel.emoji}</span> <span class="link" data-goto="faith:${rel.id}">${esc(capitalize(rel.name))}</span>`;
const placeLink = (s) => `<span class="link" data-goto="settlement:${s.id}">${esc(s.name)}</span>`;

function answersOf(need) {
  const powers = PRAYERS[need].answers.map((k) => POWER_LABELS[k]).filter(Boolean);
  return powers.length ? powers.join(' ou ') : null;
}

function prayerLine(state, s, rel) {
  if (!s.prayer || !PRAYERS[s.prayer.need]) return '';
  const who = rel ? `🙏 On prie ${esc(rel.deity)}` : '🙏 On implore le ciel';
  return `<p class="muted">${who} pour ${esc(PRAYERS[s.prayer.need].wish)} depuis ${plural(state.day - s.prayer.since, 'jour')}</p>`;
}

export function settlementFaithLines(state, s) {
  const rel = religionOf(state, s);
  const holy = rel && rel.holyId === s.id ? ' · ✴️ ville sainte' : '';
  const temple = TEMPLE_LABELS[s.temple || 0] ? ` · ${TEMPLE_LABELS[s.temple]}` : '';
  const faith = rel ? `<p>${faithLink(rel)} · ferveur ${Math.round(s.devotion)} %${holy}${temple}</p>` : `<p class="muted">🙏 Aucune religion${temple}</p>`;
  return faith + prayerLine(state, s, rel);
}

export function prophetLine(state, p) {
  const rel = religionById(state, p.prophetOf);
  if (!rel) return '';
  return `<p>✴️ ${p.sex === 'F' ? 'Prophétesse' : 'Prophète'} : ${faithLink(rel)}</p>`;
}

export function civFaithLine(state, civ) {
  const rel = religionById(state, civ.religionId);
  return rel && rel.alive ? `<p>🙏 Religion officielle : ${faithLink(rel)}</p>` : '';
}

function legendLine(legend) {
  const answered = legend.answered.length ? ` <span class="muted">· exaucé à ${esc(legend.answered.join(', '))}</span>` : '';
  return `<p>📖 ${esc(capitalize(legend.name))}${answered}</p>`;
}

function founderBlock(state, rel) {
  const founder = `<span class="link" data-goto="person:${rel.founderId}">${esc(rel.founderName)}</span>`;
  const holy = state.settlements.find((s) => s.id === rel.holyId);
  const parent = religionById(state, rel.parentId);
  const origin = parent ? ` · issue d'un schisme avec ${faithLink(parent)}` : '';
  return `<p class="muted">Fondée par ${founder}, ${formatDay(rel.foundedDay)}${origin}</p>
    <p>✴️ Ville sainte : ${holy ? placeLink(holy) : esc(rel.holyName)}</p>`;
}

export function religionPanel(state, rel) {
  const members = faithSettlements(state, rel);
  const status = rel.alive ? '' : ` · <span class="muted">éteinte ${formatDay(rel.fallDay)}</span>`;
  const you = isPlayerFaith(rel) ? '<p class="muted">✨ C\'est toi qu\'ils prient : tes pouvoirs sont leurs miracles.</p>' : '';
  const civs = aliveCivs(state).filter((c) => c.religionId === rel.id).map((c) => esc(civTitle(c, true)));
  const legends = rel.legendIds.map((id) => legendById(state, id)).filter(Boolean).reverse();
  const schisms = state.religions.filter((r) => r.parentId === rel.id);
  const temples = members.filter((s) => s.temple).length;
  return `
    <h2>${faithLink(rel)}${status}</h2>
    ${founderBlock(state, rel)}
    <p>🙏 Divinité : ${esc(rel.deity)}</p>${you}
    <p>👥 Fidèles : ${religionPopulation(state, rel)} · 🏘️ Colonies : ${members.length} · 🛕 Temples : ${temples}</p>
    ${civs.length ? `<p>👑 Religion officielle : ${civs.join(', ')}</p>` : ''}
    <h3>Légendes</h3>${legends.map(legendLine).join('') || '<p class="muted">Aucun miracle raconté pour l\'instant.</p>'}
    ${schisms.length ? `<h3>Schismes</h3>${schisms.map((r) => `<p>${faithLink(r)}${r.alive ? '' : ' <span class="muted">· éteinte</span>'}</p>`).join('')}` : ''}
    <h3>Colonies</h3>
    <ul class="list">${members.map((s) => `<li data-goto="settlement:${s.id}">${esc(s.name)}${s.id === rel.holyId ? ' ✴️' : ''}${s.temple ? ' 🛕' : ''} <span class="muted">· ferveur ${Math.round(s.devotion)} %</span></li>`).join('')}</ul>`;
}

export function faithSection(state) {
  const alive = aliveReligions(state);
  const gone = state.religions.filter((r) => !r.alive);
  if (!alive.length && !gone.length) return '<h3>🙏 Religions</h3><p class="muted">Aucune religion pour l\'instant. Un orage, un deuil… ou un miracle pourrait en faire naître une.</p>';
  const lines = alive.map((r) => `<p>${faithLink(r)} <span class="muted">· ${religionPopulation(state, r)} fidèles · ${plural(faithSettlements(state, r).length, 'colonie')}</span></p>`).join('');
  const past = gone.length ? `<p class="muted">🕯️ Éteintes : ${gone.map((r) => esc(r.name)).join(', ')}</p>` : '';
  return `<h3>🙏 Religions</h3>${lines}${past}`;
}

export function legendsSection(state) {
  const legends = (state.legends || []).slice(-RECENT_LEGENDS).reverse();
  if (!legends.length) return '';
  return `<h3>📖 Légendes</h3>${legends.map(legendLine).join('')}`;
}

export function prayersBlock(state) {
  const praying = state.settlements.filter((s) => !s.abandoned && s.prayer && PRAYERS[s.prayer.need] && answersOf(s.prayer.need));
  if (!praying.length) return '<h3>🙏 Prières</h3><p class="muted">Personne n\'implore le ciel pour l\'instant.</p>';
  const lines = praying.map((s) => `<p>${placeLink(s)} : ${esc(PRAYERS[s.prayer.need].wish)} <span class="muted">→ ${answersOf(s.prayer.need)}</span></p>`).join('');
  return `<h3>🙏 Prières</h3><p class="muted">Réponds-leur, et ils y verront un miracle.</p>${lines}`;
}
