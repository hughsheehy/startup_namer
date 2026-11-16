{{flutter_js}}
{{flutter_build_config}}

// Starts the app (WebAssembly where the browser can run it, JavaScript where it
// can't), then takes away the plain-HTML loading page in index.html once the
// app has had a couple of frames to draw. That page sits under the app and lets
// taps through, so even if this never ran the app would still work.
_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    requestAnimationFrame(() => requestAnimationFrame(() => document.getElementById('splash')?.remove()));
    // Keep the app on the device for next time (sw.js), once it's up and running
    // so it doesn't compete with starting.
    keepOnDevice();
  },
});

// Registers the service worker, and offers to reload when a new version has
// downloaded and is waiting: one that would otherwise wait for every tab of the
// app to close. Tabs left open look for a new version every hour.
async function keepOnDevice() {
  if (!navigator.serviceWorker) return;
  const registration = await navigator.serviceWorker.register('sw.js');
  // Only an update: a first install has nothing older to replace.
  const offer = (worker) => navigator.serviceWorker.controller && showReload(worker);
  if (registration.waiting) offer(registration.waiting);
  registration.addEventListener('updatefound', () => {
    const worker = registration.installing;
    worker?.addEventListener('statechange', () => worker.state === 'installed' && offer(worker));
  });
  // When the new version takes over (here, or from another tab's banner),
  // reload onto it, once.
  let reloading = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (reloading) return;
    reloading = true;
    location.reload();
  });
  setInterval(() => registration.update().catch(() => {}), 60 * 60 * 1000);
}

function showReload(worker) {
  if (document.getElementById('update')) return;
  const banner = document.createElement('div');
  banner.id = 'update';
  banner.setAttribute('role', 'status');
  const text = document.createElement('span');
  text.textContent = 'A new version is ready.';
  const button = document.createElement('button');
  button.type = 'button';
  button.textContent = 'Reload';
  button.addEventListener('click', () => {
    button.disabled = true;
    button.textContent = 'Reloading…';
    worker.postMessage('take over');
  });
  banner.append(text, button);
  document.body.append(banner);
}
