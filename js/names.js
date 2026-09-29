const SYLLABLES_A = ['Ni', 'Mi', 'E', 'Ly', 'As', 'No', 'Va', 'Ka', 'Te', 'Ori', 'Sa', 'Lu', 'Ra', 'Il', 'Ju', 'Ma', 'Fe', 'To', 'Ae', 'Bri'];
const SYLLABLES_B = ['lo', 'ra', 'no', 'a', 'ter', 'ria', 'rek', 'mar', 'lis', 'en', 'do', 'va', 'ni', 'ko', 'sa', 'wen', 'ris', 'la', 'mo', 'thi'];
const SYLLABLES_C = ['', '', '', 'n', 's', 'r', 'l', 'th', 'k', 'm'];

const PLACE_A = ['As', 'Na', 'Va', 'El', 'Or', 'Tal', 'Bel', 'Kor', 'Mir', 'Sol', 'Ven', 'Dul', 'Fal', 'Hel', 'Isk'];
const PLACE_B = ['ter', 'mar', 'rek', 'ys', 'ia', 'dun', 'wick', 'heim', 'ora', 'ande', 'ford', 'mont', 'vale', 'holm', 'brook'];

const JOBS = ['cueilleur', 'cueilleur', 'chasseur', 'bâtisseur'];

export function personName(rng) {
  return rng.pick(SYLLABLES_A) + rng.pick(SYLLABLES_B) + rng.pick(SYLLABLES_C);
}

export function placeName(rng) {
  return rng.pick(PLACE_A) + rng.pick(PLACE_B);
}

export function randomJob(rng) {
  return rng.pick(JOBS);
}

export const TRAITS = ['curieux', 'courageux', 'agressif', 'sociable', 'travailleur', 'inventif', 'prudent', 'aventurier'];
