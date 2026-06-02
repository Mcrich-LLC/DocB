export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const basePath = "/documentation/docckit";
    const landingPath = `${basePath}/documentation/docckit`;

    // Redirect root to the DocC landing page
    if (url.pathname === "/" || url.pathname === "") {
      return Response.redirect(`${url.origin}${landingPath}`, 301);
    }

    if (url.pathname === basePath) {
      return Response.redirect(`${url.origin}${landingPath}`, 301);
    }

    // Worker Routes preserve the mounted path. Strip it so the asset binding
    // looks up ./docs/js, ./docs/css, ./docs/data, etc.
    if (url.pathname.startsWith(`${basePath}/`)) {
      url.pathname = url.pathname.slice(basePath.length) || "/";
    }

    return env.ASSETS.fetch(new Request(url, request));
  },
};
