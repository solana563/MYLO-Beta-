/* MYLO — optional companion service worker.
 *
 * Drop this file in the SAME folder as the app's HTML file on your web
 * server. It's entirely optional: the app registers it if present and
 * silently skips it if not, so nothing breaks either way.
 *
 * What it does: caches the app shell (this page + whatever it loads) so
 * repeat visits open instantly and the app keeps working offline once
 * it's been loaded at least once. It does NOT cache your radio streams,
 * YouTube videos, or search results — those still need a connection.
 *
 * NOTE: if you rename the HTML file to something other than "index.html",
 * update APP_SHELL below to match.
 */

const CACHE_NAME = 'mylo-shell-v1';
const APP_SHELL = ['./', './index.html'];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL).catch(() => {
      // If neither URL resolves (different filename), that's fine — the
      // runtime fetch handler below will still cache things as they load.
    }))
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  // Never intercept cross-origin API/streaming traffic (radio streams,
  // YouTube, Supabase, iTunes, etc.) — only cache same-origin app-shell
  // requests (the HTML/CSS/JS/icons this page itself loads).
  if (new URL(request.url).origin !== self.location.origin) return;

  event.respondWith(
    caches.match(request).then((cached) => {
      const network = fetch(request)
        .then((response) => {
          if (response && response.status === 200) {
            const copy = response.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(request, copy));
          }
          return response;
        })
        .catch(() => cached);
      return cached || network;
    })
  );
});
