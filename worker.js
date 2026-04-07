export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // Redirect root to the DocC landing page
    if (url.pathname === "/" || url.pathname === "") {
      return Response.redirect(`${url.origin}/documentation/DocB`, 301);
    }

    // Try to serve the static asset
    let res = await env.ASSETS.fetch(request);

    // Fall back to the SPA shell for DocC client-side routing
    if (res.status === 404 || res.status === 403) {
      return env.ASSETS.fetch(
        new Request(new URL("/spa.html", request.url), request)
      );
    }

    return res;
  },
};
