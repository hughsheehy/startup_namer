// startupnames.loudvector.com: the Flutter web build is static files (build/web), served
// without this code. The Worker only answers /api/chocolate: how long the chocolate bought
// through Ko-fi covers the server costs, { until, daysLeft }, from loudvector.com's Worker,
// which keeps the count for all of LoudVector's apps (the LOUDVECTOR service binding, a
// direct link inside Cloudflare). Nothing (204) if it can't say; the button then just asks.

export default {
  async fetch(request, env) {
    if (new URL(request.url).pathname === "/api/chocolate") return chocolate(env);
    return env.ASSETS.fetch(request);
  },
};

async function chocolate(env) {
  try {
    const res = await env.LOUDVECTOR.fetch("https://loudvector.com/api/chocolate");
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const { until, daysLeft } = await res.json();
    if (!/^\d{4}-\d\d-\d\d$/.test(until) || !Number.isFinite(daysLeft)) throw new Error("unexpected answer");
    return new Response(JSON.stringify({ until, daysLeft }), {
      headers: { "content-type": "application/json; charset=utf-8", "cache-control": "public, max-age=3600" },
    });
  } catch {
    return new Response(null, { status: 204, headers: { "cache-control": "public, max-age=600" } });
  }
}
