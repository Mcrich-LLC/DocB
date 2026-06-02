export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Redirect root to the DocC landing page
    if (url.pathname === "/" || url.pathname === "") {
      return Response.redirect(`${url.origin}/documentation/`, 301);
    }

    // Serve static assets — not_found_handling: "single-page-application" in
    // wrangler.jsonc means unmatched paths automatically fall back to index.html,
    // so DocC's client-side router handles deep links without a manual 404 check here.
    return env.ASSETS.fetch(request);
  },
};
