import { SUMMARY_LABELS, PRIORITY, RARE, formatDay } from './events.js';
import { listWorlds } from './save.js';
import { jobLabel } from './jobs.js';
import { dayPhase } from './simulation.js';
import { clockHour, isNight } from './daylight.js';

const $ = (sel) => document.querySelector(sel);
const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

export function showPanel(html) {
  $('#panel-content').innerHTML = html;
  $('#panel').classList.remove('hidden');
}

export function hidePanel() {
  $('#panel').classList.add('hidden');
}

export function showModal(html) {
  $('#modal-content').innerHTML = html;
  $('#modal').classList.remove('hidden');
}

export function hideModal() {
  $('#modal').classList.add('hidden');
}

export function updateHud(state, weatherIcon, pop) {
  $('#year').textContent = `Année ${Math.floor(state.day / 360) + 1}`;
  const phase = dayPhase(state);
  const hour = clockHour(phase);
  $('#day').textContent = `Jour ${(state.day % 360) + 1} · ${String(hour).padStart(2, '0')}h ${isNight(phase) ? '🌙' : '☀️'} · ${state.name}`;
  $('#weather').textContent = weatherIcon === '☀️' && isNight(phase) ? '🌙' : weatherIcon;
  $('#pop').textContent = pop;
}

export function setSpeedButtons(speed) {
  document.querySelectorAll('#speeds button').forEach((b) => b.classList.toggle('active', Number(b.dataset.speed) === speed));
}

export function toast(text, onClick) {
  const el = document.createElement('div');
  el.className = 'toast';
  el.textContent = text;
  if (onClick) el.addEventListener('click', () => { onClick(); el.remove(); });
  const feed = $('#feed');
  feed.appendChild(el);
  while (feed.children.length > 4) feed.firstChild.remove();
  setTimeout(() => el.remove(), 6000);
}

export function formatDuration(ms) {
  const m = Math.floor(ms / 60000);
  if (m < 1) return 'quelques secondes';
  if (m < 60) return `${m} min`;
  const h = Math.floor(m / 60);
  if (h < 48) return `${h}h ${String(m % 60).padStart(2, '0')}min`;
  return `${Math.floor(h / 24)} jours`;
}

const rankOf = (type) => PRIORITY[type] || (RARE.has(type) ? 20 : 0);

const ALWAYS_SHOWN = ['naissance', 'deces'];
const MAX_SUMMARY_LINES = 10;

function countItems(summary) {
  const entries = Object.entries(summary.counts).filter(([k, n]) => SUMMARY_LABELS[k] && n > 0);
  const core = ALWAYS_SHOWN.map((k) => entries.find(([key]) => key === k)).filter(Boolean);
  const rest = entries
    .filter(([k]) => !ALWAYS_SHOWN.includes(k))
    .sort((a, b) => rankOf(b[0]) - rankOf(a[0]) || b[1] - a[1])
    .slice(0, MAX_SUMMARY_LINES - core.length);
  return [...core, ...rest]
    .map(([k, n]) => `<li>${SUMMARY_LABELS[k][0]} ${n} ${SUMMARY_LABELS[k][n > 1 ? 2 : 1]}</li>`)
    .join('');
}

function highlightBlock(h) {
  const label = SUMMARY_LABELS[h.type] ? SUMMARY_LABELS[h.type][0] : '⚠️';
  const emoji = /^\p{Extended_Pictographic}/u.test(h.text) ? '' : `${label} `;
  const goto = h.personId ? `person:${h.personId}` : h.x !== undefined ? `tile:${h.x}:${h.y}` : '';
  return `<div class="highlight"${goto ? ` data-goto="${goto}"` : ''}>${emoji}${esc(h.text)}<div class="muted" style="font-size:12px">${formatDay(h.day)}</div></div>`;
}

function followedLine(f) {
  const female = f.sex === 'F';
  let text;
  if (f.alive) text = `👁️ ${esc(f.name)} · ${f.age} ans · ${esc(jobLabel(f.job, f.sex))} · ${f.fresh} nouveauté${f.fresh > 1 ? 's' : ''}`;
  else if (f.departed) text = `🚀 ${esc(f.name)} ${female ? 'est partie' : 'est parti'} vers les étoiles`;
  else text = `✝ ${esc(f.name)} — ${esc(f.last)}`;
  return `<div class="followed" data-goto="person:${f.id}">${text}</div>`;
}

export function returnModal(state, summary, elapsedMs, days) {
  const items = countItems(summary);
  const highlights = summary.highlights.map(highlightBlock).join('');
  const followed = summary.followed || [];
  return `
    <h1>🌍 Bon retour</h1>
    <div class="sub">Tu étais absent depuis <b>${formatDuration(elapsedMs)}</b> — ${days} jour${days > 1 ? 's' : ''} se sont écoulés à ${esc(state.name)}.</div>
    ${items ? `<ul>${items}</ul>` : '<p class="muted">Le monde est resté calme.</p>'}
    ${highlights}
    ${followed.length ? `<h3>👁️ Tes suivis</h3>${followed.map(followedLine).join('')}` : ''}
    <div class="actions"><button class="primary" data-action="close-modal">Découvrir</button></div>`;
}

export function confirmModal(title, text, actionId) {
  return `
    <h1>${esc(title)}</h1>
    <div class="sub">${esc(text)}</div>
    <div class="actions"><button data-action="close-modal">Annuler</button><button class="primary" data-action="${esc(actionId)}">Oui</button></div>`;
}

export function endingModal(state) {
  const ended = state.ended;
  return `
    <h1>🌌 Le grand départ</h1>
    <div class="sub">${ended.departed} habitant${ended.departed > 1 ? 's' : ''} de ${esc(state.name)} ${ended.departed > 1 ? 'ont' : 'a'} quitté la planète, ${formatDay(ended.day)}.</div>
    <p>${ended.remaining > 0 ? `${ended.remaining} ${ended.remaining > 1 ? 'restent et regardent' : 'reste et regarde'} le ciel.` : 'La planète est désormais silencieuse.'}</p>
    <div class="actions"><button data-action="close-modal">Continuer à observer</button><button class="primary" data-action="menu">Nouveau monde</button></div>`;
}

export function menuModal(state) {
  const worlds = listWorlds();
  return `
    <h1>☰ Petite Planète</h1>
    <div class="sub">Monde actuel : <b>${esc(state.name)}</b> · jour ${state.day}</div>
    <h3>Mes mondes</h3>
    <ul>${worlds.map((w) => `<li><span class="link" data-action="load:${w.id}">🌍 ${esc(w.name)}</span> <span class="muted">· jour ${w.day} · ${w.pop} hab.</span>${w.id !== state.id ? ` <span class="link" data-action="delete:${w.id}" style="color:#ef9a9a">supprimer</span>` : ''}</li>`).join('')}</ul>
    <h3>Nouveau monde</h3>
    <input id="new-name" placeholder="Nom du monde (ex: Noria)" maxlength="20">
    <div class="actions"><button class="primary" data-action="new-world">Créer</button></div>
    <p class="muted" style="font-size:12px;margin-top:14px">Sur téléphone : « Ajouter à l'écran d'accueil » pour installer l'app. Le monde continue de vivre quand l'app est fermée.</p>
    <div class="actions"><button data-action="close-modal">Fermer</button></div>`;
}
