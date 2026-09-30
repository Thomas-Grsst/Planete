export const FAITH_SOURCES = {
  rain: {
    player: true, emoji: '🌧️', color: '#64b5f6', deity: 'le Faiseur de Pluie',
    names: ['le Culte de la Pluie', 'l\'Église des Nuées', 'les Enfants de l\'Averse'],
    legends: ['la Grande Pluie', 'le Déluge béni', 'les Larmes du Ciel'],
    sign: 'la pluie tombe',
    founding: '🙏 Depuis {legend}, {name} en est sûr{e} : quelqu\'un, là-haut, veille sur {place}. {Il} fonde {religion} et prie {deity}.',
  },
  sun: {
    player: true, emoji: '☀️', color: '#ffd54f', deity: 'l\'Œil d\'Or',
    names: ['le Culte du Soleil', 'l\'Ordre de l\'Aube', 'les Fils de la Lumière'],
    legends: ['le Grand Soleil', 'le Jour sans Nuage', 'l\'Éveil du Ciel'],
    sign: 'le soleil revient',
    founding: '🙏 Le jour où le ciel s\'est ouvert, {name} a vu un œil d\'or veiller sur {place}. {Il} fonde {religion} en l\'honneur {ofDeity}.',
  },
  grow: {
    player: true, emoji: '🌱', color: '#81c784', deity: 'la Mère Verte',
    names: ['le Culte de la Moisson', 'la Voie des Semences', 'les Gardiens du Bosquet'],
    legends: ['le Printemps miraculeux', 'la Grande Floraison', 'l\'Année d\'Abondance'],
    sign: 'la terre reverdit en une nuit',
    founding: '🙏 Depuis {legend}, {name} entend la voix {ofDeity} dans les champs de {place}. {Il} fonde {religion}.',
  },
  zombie: {
    player: true, emoji: '💀', color: '#9ccc65', deity: 'le Semeur de Morts',
    names: ['le Culte des Tombes', 'la Confrérie de la Brume', 'les Veilleurs des Morts'],
    legends: ['la Brume verte', 'le Réveil des Morts', 'la Nuit des Tombes'],
    sign: 'les morts se relèvent',
    founding: '💀 Après {legend}, {name} annonce à {place} que les morts obéissent à une volonté : {deity}. Dans la peur, {il} fonde {religion}.',
  },
  storm: {
    player: false, emoji: '⛈️', color: '#9575cd', deity: 'le Dieu de l\'Orage',
    names: ['le Culte de l\'Orage', 'les Enfants de la Foudre'],
    founding: '⛈️ Chaque orage fait trembler {place}. {name} y voit la colère {ofDeity} et fonde {religion}.',
  },
  ancestors: {
    player: false, emoji: '🕯️', color: '#bcaaa4', deity: 'les Ancêtres',
    names: ['le Culte des Ancêtres', 'la Voie des Aïeux'],
    founding: '🕯️ {name} rassemble {place} autour des tombes : les défunts veillent sur les vivants. {Il} fonde {religion}.',
  },
};

export const PRAYERS = {
  zombies: { answers: [], wish: 'la protection contre les morts' },
  drought: { answers: ['rain'], wish: 'la fin de la sécheresse' },
  hunger: { answers: ['grow', 'rain'], wish: 'de quoi nourrir les affamés' },
  sick: { answers: [], wish: 'la guérison des malades' },
  storm: { answers: ['sun'], wish: 'la fin de la tempête' },
  cold: { answers: ['sun'], wish: 'le retour de la chaleur' },
};

export const POWER_LABELS = { rain: '🌧️ Pluie', sun: '☀️ Soleil', grow: '🌱 Végétation' };

export const SCHISM_NAMES = ['les Purs', 'les Réformés', 'les Fidèles de l\'Aube', 'les Nouveaux Croyants', 'les Gardiens de la Vraie Foi'];

export const FAITH_COLORS = ['#f06292', '#4db6ac', '#ff8a65', '#aed581', '#ba68c8', '#90a4ae'];

export const capitalize = (text) => text.charAt(0).toUpperCase() + text.slice(1);

export function ofName(name) {
  if (name.startsWith('le ')) return `du ${name.slice(3)}`;
  if (name.startsWith('les ')) return `des ${name.slice(4)}`;
  return `de ${name}`;
}

export function toName(name) {
  if (name.startsWith('le ')) return `au ${name.slice(3)}`;
  if (name.startsWith('les ')) return `aux ${name.slice(4)}`;
  return `à ${name}`;
}

export function tellFaith(story, p, s, fields) {
  const female = p.sex === 'F';
  return story
    .replace('{name}', () => p.name)
    .replace('{place}', () => s.name)
    .replace('{religion}', () => fields.religion || '')
    .replace('{deity}', () => fields.deity || '')
    .replace('{ofDeity}', () => ofName(fields.deity || ''))
    .replace('{legend}', () => fields.legend || 'le miracle')
    .replace('{Il}', female ? 'Elle' : 'Il')
    .replace('{il}', female ? 'elle' : 'il')
    .replace('{e}', female ? 'e' : '');
}
