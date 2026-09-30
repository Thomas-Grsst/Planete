import { ageOf, settlementOf } from './people.js';
import { residents } from './settlements.js';
import { SPECIES } from './animals.js';
import { formatDay, plural } from './events.js';
import { BIOMES, SIZE } from './world.js';
import { jobLabel, jobEmoji } from './jobs.js';
import { TECHS } from './techTree.js';
import { ORES } from './resources.js';
import { settlementCivLine } from './panelsCiv.js';
import { territoryMap } from './territory.js';
import { civById, civTitle } from './civs.js';
import { DISEASES } from './diseaseTable.js';
import { diseaseLabel, immuneLabel } from './disease.js';
import { chefOf } from './governance.js';
import { settlementFaithLines, prophetLine } from './panelsFaith.js';

export { journalPanel, statsPanel, powersPanel } from './panelsWorld.js';
export { civPanel } from './panelsCiv.js';
export { religionPanel } from './panelsFaith.js';

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

function territoryLine(state, x, y) {
  const civ = civById(state, territoryMap(state)[y * SIZE + x]);
  return civ ? `<p>🗺️ Territoire : <span class="link" data-goto="civ:${civ.id}">${esc(civTitle(civ, true))}</span></p>` : '';
}
const personLink = (p) => `<span class="link" data-goto="person:${p.id}">${esc(p.name)}</span>`;

function lifeStatus(p, age) {
  const female = p.sex === 'F';
  if (p.alive) return `${age} ans`;
  if (p.departed === true) return `🚀 ${female ? 'partie' : 'parti'} vers les étoiles`;
  return `✝ ${female ? 'morte' : 'mort'} à ${Math.floor((p.deathDay - p.birthDay) / 360)} ans`;
}

function healthLines(state, p) {
  const female = p.sex === 'F';
  const lines = [];
  if (p.alive && p.sick) lines.push(`<p>🤒 ${esc(diseaseLabel(state, p))}</p>`);
  if (p.alive && p.bitten != null) lines.push(`<p>🧟 ${female ? 'Mordue' : 'Mordu'} depuis ${state.day - p.bitten} j</p>`);
  if ((p.knows || []).length) lines.push(`<p>🔑 Secrets : ${p.knows.filter((k) => TECHS[k]).map((k) => `${TECHS[k].emoji} ${esc(TECHS[k].name)}`).join(', ')}</p>`);
  if ((p.immune || []).length) lines.push(`<p class="muted">🛡️ ${female ? 'Immunisée' : 'Immunisé'} : ${esc(immuneLabel(p))}</p>`);
  return lines.join('');
}

export function personPanel(state, p) {
  const age = ageOf(state, p);
  const home = settlementOf(state, p);
  const partner = state.people.find((q) => q.id === p.partnerId);
  const kids = p.children.map((id) => state.people.find((q) => q.id === id)).filter(Boolean);
  const followed = state.followed.includes(p.id);
  return `
    <h2>${esc(p.name)} <span class="muted">· ${p.sex === 'F' ? 'Femme' : 'Homme'} · ${lifeStatus(p, age)}</span></h2>
    <p>${home ? `🏠 <span class="link" data-goto="settlement:${home.id}">${esc(home.name)}</span>` : '🏕️ Nomade'} · ${esc(jobLabel(p.job, p.sex))}</p>
    <p class="muted">${p.traits.map(esc).join(', ')}</p>
    ${prophetLine(state, p)}
    ${healthLines(state, p)}
    ${p.alive ? `<h3>Santé</h3><div class="bar"><i style="width:${Math.max(0, Math.round(p.health))}%"></i></div>
    <h3>Bonheur</h3><div class="bar"><i style="width:${Math.round(p.happiness)}%;background:#ffb300"></i></div>` : ''}
    <h3>Famille</h3>
    <p>${partner ? `💞 ${personLink(partner)}` : '<span class="muted">Célibataire</span>'}</p>
    <p>${kids.length ? kids.map((k) => `${personLink(k)}${k.alive ? '' : k.departed === true ? ' 🚀' : ' ✝'}`).join(', ') : '<span class="muted">Pas d\'enfant</span>'}</p>
    <h3>Histoire</h3>
    ${p.history.slice(-8).reverse().map((h) => `<div class="entry"><span class="d">${formatDay(h.day)}</span>${esc(h.text)}</div>`).join('') || '<p class="muted">Rien à raconter pour l\'instant.</p>'}
    <div class="row">
      <button data-action="follow:${p.id}" class="${followed ? 'active' : ''}">${followed ? '👁️ Suivi' : '👁️ Suivre'}</button>
      ${p.alive ? `<button data-action="goto:${p.x}:${p.y}">📍 Voir</button>` : ''}
    </div>`;
}

function knowledgeLine(s) {
  const techs = (s.techs || []).filter((k) => TECHS[k]);
  const fragile = (k) => Array.isArray(s.rooted) && !s.rooted.includes(k);
  const chips = techs.map((k) => `<span class="chip"${fragile(k) ? ' title="Savoir fragile : peu de gens le connaissent"' : ''}>${TECHS[k].emoji} ${esc(TECHS[k].name)}${fragile(k) ? ' 🕯️' : ''}</span>`).join('');
  return `<p>💡 Savoirs : ${chips || '<span class="muted">Aucune découverte</span>'}</p>`;
}

function governanceLines(state, s, pop) {
  const chef = chefOf(state, s);
  const lines = [];
  if (chef) lines.push(`<p>👑 ${chef.sex === 'F' ? 'Cheffe' : 'Chef'} : ${personLink(chef)} depuis ${formatDay(s.chefSince)}</p>`);
  else if (pop.length >= 20) lines.push('<p>👑 <span class="muted">Pas de chef</span></p>');
  const council = (s.council || []).map((id) => pop.find((p) => p.id === id)).filter(Boolean);
  if (council.length) lines.push(`<p>🏛️ Conseil : ${council.map(personLink).join(', ')}</p>`);
  return lines.join('');
}

function outbreakLine(state, s, pop) {
  const o = s.outbreak;
  const d = o && DISEASES[o.key];
  if (!d) return '';
  const sick = pop.filter((p) => p.sick).length;
  return `<p>🦠 ${esc(d.name)} sévit depuis ${state.day - o.since} j · ${plural(sick, 'malade')} · ${plural(o.deaths, 'mort')}</p>`;
}

function jobsLine(pop) {
  const counts = {};
  for (const p of pop) counts[p.job] = (counts[p.job] || 0) + 1;
  const parts = Object.entries(counts).sort((a, b) => b[1] - a[1]).map(([j, n]) => `${jobEmoji(j)} ${n}`);
  return parts.length ? `<p class="muted">${parts.join(' · ')}</p>` : '';
}

function fateLine(s) {
  if (s.fallen) return `<p>☠ Tombé aux mains des zombies ${formatDay(s.fallen)}</p>`;
  if (s.departed) return `<p>🚀 Partis vers les étoiles ${formatDay(s.departed)}</p>`;
  return '';
}

export function settlementPanel(state, s) {
  const pop = residents(state, s);
  const followed = state.followed.includes(s.id);
  return `
    <h2>${esc(s.name)} <span class="muted">· ${esc(s.level)}</span></h2>
    <p>👥 ${pop.length} habitants · 🏠 ${s.houses} maisons · 🪵 ${Math.round(s.wood)} bois</p>
    <p class="muted">Fondé ${formatDay(s.foundedDay)}${s.abandoned ? ` · abandonné ${formatDay(s.abandoned)}` : ''}</p>
    ${settlementCivLine(state, s)}
    ${s.abandoned ? '' : settlementFaithLines(state, s)}
    ${fateLine(s)}
    ${knowledgeLine(s)}
    ${governanceLines(state, s, pop)}
    ${outbreakLine(state, s, pop)}
    ${jobsLine(pop)}
    <h3>Habitants</h3>
    <ul class="list">${pop.slice(0, 30).map((p) => `<li data-goto="person:${p.id}">${esc(p.name)} <span class="muted">· ${ageOf(state, p)} ans · ${esc(jobLabel(p.job, p.sex))}${p.sick ? ' · 🤒' : ''}${p.bitten != null ? ' · 🧟' : ''}</span></li>`).join('')}</ul>
    ${pop.length > 30 ? `<p class="muted">… et ${pop.length - 30} autres</p>` : ''}
    <div class="row">
      <button data-action="follow:${s.id}" class="${followed ? 'active' : ''}">${followed ? '👁️ Suivi' : '👁️ Suivre'}</button>
      <button data-action="goto:${s.x}:${s.y}">📍 Voir</button>
    </div>`;
}

export function tilePanel(state, x, y, t) {
  const herds = state.herds.filter((h) => h.x === x && h.y === y);
  const hordes = state.zombies ? state.zombies.hordes.filter((h) => h.x === x && h.y === y) : [];
  return `
    <h2>${esc(BIOMES[t.biome].name)} <span class="muted">(${x}, ${y})</span></h2>
    <p>🌾 Nourriture : ${Math.round(t.food)} / ${Math.round(t.fertility * 12)} · 🌲 Arbres : ${t.trees}${t.stone ? ` · 🪨 Pierre : ${t.stone}` : ''}</p>
    ${territoryLine(state, x, y)}
    ${t.ore && ORES[t.ore] ? `<p>${ORES[t.ore].emoji} Gisement : ${ORES[t.ore].name}</p>` : ''}
    ${herds.map((h) => `<p>${SPECIES[h.species].emoji} ${SPECIES[h.species].name} : ${Math.round(h.count)}</p>`).join('')}
    ${hordes.map((h) => `<p>🧟 Zombies : ${Math.round(h.count)}</p>`).join('')}`;
}
