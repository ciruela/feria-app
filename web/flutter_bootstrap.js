// Bootstrap web de Armenext.
//
// App 100% online (requiere Supabase): NO registramos service worker. Así el
// navegador siempre trae la última versión desplegada en vez de quedar pegado
// a una copia cacheada. Los headers de Cloudflare (web/_headers) ya evitan el
// cache del JS. La limpieza del SW anterior se hace en index.html.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();
