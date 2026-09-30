const CACHE = 'petite-planete-v6';
const ASSETS = [
  './', './index.html', './manifest.json', './icon.svg', './css/style.css',
  './js/main.js', './js/rng.js', './js/names.js', './js/world.js', './js/people.js',
  './js/animals.js', './js/settlements.js', './js/events.js', './js/simulation.js',
  './js/save.js', './js/render.js', './js/ui.js', './js/panels.js', './js/camera.js',
  './js/census.js', './js/jobs.js', './js/work.js', './js/techTree.js', './js/technology.js', './js/regions.js',
  './js/diseaseTable.js', './js/disease.js', './js/epidemics.js', './js/defense.js', './js/hordes.js', './js/zombies.js',
  './js/governance.js', './js/powers.js', './js/migrate.js', './js/panelsWorld.js', './js/housekeeping.js',
  './js/resources.js', './js/context.js', './js/inspiration.js', './js/ideasEarly.js', './js/ideasLate.js', './js/lore.js', './js/daylight.js', './js/decor.js',
  './js/civs.js', './js/civFormation.js', './js/territory.js', './js/diplomacy.js', './js/war.js', './js/panelsCiv.js', './js/navigation.js', './js/borders.js',
  './js/faithData.js', './js/religions.js', './js/miracles.js', './js/faith.js', './js/faithBirth.js', './js/faithSpread.js', './js/panelsFaith.js'
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  e.respondWith(
    fetch(e.request).then((res) => {
      const copy = res.clone();
      caches.open(CACHE).then((c) => c.put(e.request, copy));
      return res;
    }).catch(() => caches.match(e.request))
  );
});
