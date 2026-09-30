import { formatDay, plural } from './events.js';
import { aliveCivs, civById, civOf, civSettlements, civTitle, civPopulation, civTechShare } from './civs.js';
import { territoryShare } from './territory.js';
import { relationLabel } from './diplomacy.js';
import { warLine } from './war.js';
import { civFaithLine } from './panelsFaith.js';

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const dot = (civ) => `<span style="color:${civ.color}">●</span>`;
const civLink = (civ) => `${dot(civ)} <span class="link" data-goto="civ:${civ.id}">${esc(civTitle(civ, true))}</span>`;

function relationsBlock(state, civ) {
  const others = aliveCivs(state).filter((c) => c !== civ);
  if (!others.length) return '<p class="muted">Aucune autre civilisation connue.</p>';
  return others.map((o) => `<p>${civLink(o)} : ${relationLabel(state, civ, o)}</p>`).join('');
}

function citiesBlock(state, civ) {
  return `<ul class="list">${civSettlements(state, civ).map((s) => {
    const capital = s.id === civ.capitalId ? ' 🏰' : '';
    const conquered = s.conqueredDay != null ? ' 🏴' : '';
    return `<li data-goto="settlement:${s.id}">${esc(s.name)}${capital}${conquered} <span class="muted">· ${esc(s.level)}</span></li>`;
  }).join('')}</ul>`;
}

export function civPanel(state, civ) {
  const followed = state.followed.includes(civ.id);
  const capital = state.settlements.find((s) => s.id === civ.capitalId);
  const founder = civ.founderId ? `<span class="link" data-goto="person:${civ.founderId}">${esc(civ.founderName)}</span>` : 'ses premiers habitants';
  const wars = state.wars.filter((w) => w.a === civ.id || w.b === civ.id).map((w) => `<p>${esc(warLine(state, w))}</p>`).join('');
  const status = civ.alive ? '' : ` · <span class="muted">disparue ${formatDay(civ.fallDay)}</span>`;
  return `
    <h2>${dot(civ)} ${esc(civTitle(civ, true))}${status}</h2>
    <p class="muted">Fondée par ${founder}, ${formatDay(civ.foundedDay)}${capital ? ` · capitale : <span class="link" data-goto="settlement:${capital.id}">${esc(capital.name)}</span>` : ''}</p>
    <p>👥 Population : ${civPopulation(state, civ)} · 🏘️ Villes : ${civSettlements(state, civ).length}</p>
    <p>🗺️ Territoire : ${territoryShare(state, civ)} % · 💡 Technologie : ${civTechShare(state, civ)} % · 🎭 Culture : ${Math.round(civ.culture)} %</p>
    ${civFaithLine(state, civ)}
    ${civ.conquests ? `<p>🏴 ${plural(civ.conquests, 'conquête')}</p>` : ''}
    ${wars ? `<h3>Guerres</h3>${wars}` : ''}
    <h3>Relations</h3>${relationsBlock(state, civ)}
    <h3>Villes</h3>${citiesBlock(state, civ)}
    <div class="row"><button data-action="follow:${civ.id}" class="${followed ? 'active' : ''}">${followed ? '👁️ Suivie' : '👁️ Suivre'}</button></div>`;
}

export function settlementCivLine(state, s) {
  const civ = civOf(state, s);
  if (!civ) return '<p class="muted">🏳️ Indépendant</p>';
  const role = s.id === civ.capitalId ? ' · 🏰 capitale' : '';
  return `<p>${civLink(civ)}${role}</p>`;
}

export function civSection(state) {
  const civs = aliveCivs(state);
  const fallen = state.civs.filter((c) => !c.alive);
  if (!civs.length && !fallen.length) return '<h3>🏰 Civilisations</h3><p class="muted">Aucune civilisation pour l\'instant. Il faut un village d\'au moins 30 habitants avec un chef.</p>';
  const lines = civs.map((c) => `<p>${civLink(c)} <span class="muted">· ${civPopulation(state, c)} hab. · ${territoryShare(state, c)} %</span></p>`).join('');
  const wars = state.wars.map((w) => `<p>${esc(warLine(state, w))}</p>`).join('');
  const past = fallen.length ? `<p class="muted">🏚️ Disparues : ${fallen.map((c) => esc(civTitle(c))).join(', ')}</p>` : '';
  return `<h3>🏰 Civilisations</h3>${lines}${wars}${past}`;
}

export function civForRef(state, id) {
  return civById(state, Number(id));
}
