// Bump this version string with each deploy to invalidate the cache.
const CACHE_VERSION = "v1";
const CACHE_NAME = "crab-" + CACHE_VERSION;

// Only cache small UI files. Emscripten outputs (em.js, em.wasm) are excluded
// because iOS Safari has issues with WebAssembly.instantiateStreaming() on
// responses served from the Cache API, and the browser caches compiled WASM
// separately anyway.
const ASSETS = [
  "./",
  "./index.html",
  "./index.js",
  "./styles.css",
  "./manifest.json",
  "./apple-touch-icon-precomposed.png",
];

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(ASSETS))
  );
  // Activate immediately instead of waiting for existing tabs to close
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  // Delete old caches from previous versions
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key.startsWith("crab-") && key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    )
  );
  // Take control of all open tabs immediately
  self.clients.claim();
});

self.addEventListener("message", (event) => {
  if (event.data?.type === "skipWaiting") self.skipWaiting();
});

self.addEventListener("fetch", (event) => {
  event.respondWith(
    caches.match(event.request).then((cached) => cached || fetch(event.request))
  );
});
