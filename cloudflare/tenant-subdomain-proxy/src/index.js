/**
 * Enruta subdominios tenant (*.armenext.com) hacia feria-app Pages.
 * La URL del navegador no cambia; Flutter detecta el subdominio para branding.
 */
const PAGES_HOST = 'feria-app.pages.dev';

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const host = url.hostname.toLowerCase();

    if (!host.endsWith('.armenext.com') || host === 'armenext.com') {
      return fetch(request);
    }

    return proxyToPages(request, url);
  },
};

async function proxyToPages(request, url) {
  const target = new URL(url);
  target.hostname = PAGES_HOST;

  const headers = new Headers(request.headers);
  headers.set('Host', PAGES_HOST);

  return fetch(
    new Request(target, {
      method: request.method,
      headers,
      body: request.body,
      redirect: 'manual',
    }),
  );
}
