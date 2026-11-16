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
  },
});
