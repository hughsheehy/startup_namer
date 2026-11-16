// Service worker for Startup Names. It keeps the app on the device, so a repeat
// visit starts without asking the server about every file, and works offline.
//
// tool/build_web.py fills in BUILD and FILES after `flutter build web`. Each
// build gets its own cache, filled all at once when this worker installs, so a
// visit never mixes files from two builds. A new build installs in the
// background and takes over once every tab of the app has closed: updates show
// on the next visit after a deploy.
//
// Left unstamped (a plain `flutter build web`), it removes itself and its caches
// instead, so a build made without the script can't leave anyone on an old copy.
const BUILD = 'unstamped';
const FILES = /*FILES*/[]/*END*/;

const STAMPED = BUILD !== 'unstamped';
const CACHE = `startupnames-${BUILD}`;

// Addresses whose content never changes (Flutter's renderer and Google Fonts
// carry their version in the address), so a copy kept once is good for good.
const LASTING = /^https:\/\/(www|fonts)\.gstatic\.com\//;

self.addEventListener('install', (event) => {
  if (!STAMPED) {
    self.skipWaiting();
    return;
  }
  // All or nothing: if any file can't be fetched, this build isn't installed and
  // the app carries on from the network as before.
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(FILES)));
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    for (const name of await caches.keys()) {
      if (name.startsWith('startupnames-') && name !== CACHE) await caches.delete(name);
    }
    if (!STAMPED) await self.registration.unregister();
  })());
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (!STAMPED || request.method !== 'GET') return;
  const url = new URL(request.url);
  const ours = url.origin === self.location.origin;
  // Anything else, the .com checks included, goes straight to the network.
  if (!ours && !LASTING.test(request.url)) return;
  if (ours && url.pathname.endsWith('/sw.js')) return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    // The app is one page: a visit to it, with or without ?anything, gets the
    // kept copy of that page.
    const page = request.mode === 'navigate' && (url.pathname === '/' || url.pathname === '/index.html');
    const kept = await cache.match(page ? new URL('./', self.location).href : request);
    if (kept) return kept;
    const response = await fetch(request);
    // Keep what this build fetches later too, like the JavaScript version for
    // browsers that can't run the WebAssembly one.
    if (response.ok && !page) cache.put(request, response.clone());
    return response;
  })());
});
