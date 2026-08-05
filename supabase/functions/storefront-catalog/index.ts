// Edge Function: storefront-catalog
//
// Catalogo PUBLICO de una armeria para la tienda web. No requiere login del
// cliente. Resuelve el tenant por slug y devuelve solo productos publicables.
// Usa service-role del lado del servidor para no abrir la base a anonimos.
//
// GET /storefront-catalog?slug=armeriapepe

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function isSchemaMissing(error: { code?: string; message?: string } | null): boolean {
  if (!error) return false;
  const code = String(error.code ?? "");
  const msg = String(error.message ?? "").toLowerCase();
  return (
    code === "PGRST205" ||
    code === "42P01" ||
    code === "42703" ||
    msg.includes("could not find the table") ||
    msg.includes("does not exist") ||
    msg.includes("storefront_enabled")
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "GET") {
    return json({ error: "Metodo no permitido" }, 405);
  }

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) {
      console.error("storefront-catalog: missing env");
      return json({ error: "Configuracion del servidor incompleta" }, 500);
    }

    const slug = new URL(req.url).searchParams.get("slug")?.trim();
    if (!slug) return json({ error: "Falta slug" }, 400);

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false },
    });

    const { data: tenant, error: tenantError } = await admin
      .from("tenants")
      .select("id,nombre,slug,activo,storefront_enabled")
      .eq("slug", slug)
      .maybeSingle();

    if (tenantError) {
      console.error("storefront-catalog tenant lookup failed", tenantError);
      if (isSchemaMissing(tenantError)) {
        return json(
          {
            error: "Storefront no configurado en el servidor",
            code: "schema_missing",
          },
          503,
        );
      }
      return json({ error: tenantError.message }, 500);
    }

    if (!tenant || !tenant.activo || !tenant.storefront_enabled) {
      return json({ error: "Tienda no disponible" }, 404);
    }

    const { data: productos, error: productosError } = await admin
      .from("productos")
      .select(
        "id,type,marca,calibre,codigo,modelo,descripcion,precio_usd,foto_url,stock,rounds_per_box",
      )
      .eq("tenant_id", tenant.id);

    if (productosError) {
      console.error("storefront-catalog productos failed", productosError);
      return json({ error: productosError.message }, 500);
    }

    const disponibles = (productos ?? []).filter(
      (p: any) => p.stock === null || Number(p.stock) > 0,
    );

    return json(
      {
        tenant: { nombre: tenant.nombre, slug: tenant.slug },
        productos: disponibles,
      },
      200,
    );
  } catch (e) {
    console.error("storefront-catalog unhandled", e);
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
