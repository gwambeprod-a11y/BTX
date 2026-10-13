// Service Worker BATIX v3.1 — Fonctionnement Hors-Ligne (Réseau 3G instable / Chantier)
const CACHE_NAME = 'batix-cache-v3.1';
const ASSETS = ['/index.html', '/manifest.json'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request).then((cached) => cached || fetch(event.request))
  );
});
