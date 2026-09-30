# 🧊 Petite Planète — version web (figée)

C'est la première version du jeu, en JavaScript pur (PWA installable). **Elle n'évolue plus** : tout continue dans la version Godot, dans le dossier [`godot/`](../godot).

Elle reste jouable telle quelle, et l'étiquette git `web-final` marque son dernier état.

Elle contient : métiers, 22 savoirs découverts par causes, savoir fragile, maladies, loups, apocalypse zombie, chefs et conseils, civilisations, territoires, diplomatie, guerres, religions nées de tes miracles, cycle jour/nuit de 10 min et rattrapage hors ligne.

## Lancer

```bash
powershell -ExecutionPolicy Bypass -File web/serve.ps1
```

Puis ouvre http://localhost:8080. N'importe quel serveur de fichiers statiques fonctionne aussi (les modules JavaScript ne se chargent pas en ouvrant `index.html` directement).

Sur téléphone : héberge le dossier `web/` en HTTPS, ouvre-le, puis « Installer l'application » (Android) ou « Sur l'écran d'accueil » (iPhone).
