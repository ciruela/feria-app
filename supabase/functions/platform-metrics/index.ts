// Edge Function: platform-metrics
//
// Devuelve metricas agregadas de TODAS las armerias (cross-tenant) para el
// panel de super admin. Usa la service-role key (solo del lado del servidor,
// NUNCA en el cliente) y verifica que quien llama sea un platform admin.
//
// Deploy:
//   supabase functions deploy platform-metrics
//   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=... (ya viene por defecto en el runtime)
//
// El runtime de Supabase ya inyecta SUPABASE_URL, SUPABASE_ANON_KEY y
// SUPABASE_SERVICE_ROLE_KEY como variables de entorno.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace("Bearer ", "").trim();
    if (!jwt) {
      return json({ error: "No autorizado" }, 401);
    }

    // 1. Verificar identidad del que llama.
    const authClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await authClient.auth.getUser(jwt);
    if (userErr || !userData?.user) {
      return json({ error: "No autorizado" }, 401);
    }

    // 2. Verificar que sea platform admin (con service role).
    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false },
    });
    const { data: pa } = await admin
      .from("platform_admins")
      .select("user_id")
      .eq("user_id", userData.user.id)
      .maybeSingle();
    if (!pa) {
      return json({ error: "Requiere super admin" }, 403);
    }

    // 3. Agregar metricas globales.
    const [{ data: tenants }, { data: ventas }, { data: vendedores }] =
      await Promise.all([
        admin.from("tenants").select("id,nombre,slug,activo"),
        admin.from("ventas").select("tenant_id,total_ars,total_usd,anulada"),
        admin.from("vendedores").select("tenant_id,activo"),
      ]);

    const tenantList = tenants ?? [];
    const ventaList = (ventas ?? []).filter((v: any) => !v.anulada);
    const vendedorList = vendedores ?? [];

    const byTenant = new Map<string, any>();
    for (const t of tenantList) {
      byTenant.set(t.id, {
        id: t.id,
        nombre: t.nombre,
        slug: t.slug,
        activo: t.activo,
        sales_count: 0,
        total_ars: 0,
        total_usd: 0,
        seller_count: 0,
      });
    }

    let totalArs = 0;
    let totalUsd = 0;
    for (const v of ventaList) {
      const row = byTenant.get(v.tenant_id);
      const ars = Number(v.total_ars ?? 0);
      const usd = Number(v.total_usd ?? 0);
      totalArs += ars;
      totalUsd += usd;
      if (row) {
        row.sales_count += 1;
        row.total_ars += ars;
        row.total_usd += usd;
      }
    }
    for (const s of vendedorList) {
      const row = byTenant.get(s.tenant_id);
      if (row) row.seller_count += 1;
    }

    const result = {
      tenant_count: tenantList.length,
      active_tenants: tenantList.filter((t: any) => t.activo).length,
      seller_count: vendedorList.length,
      sales_count: ventaList.length,
      total_ars: totalArs,
      total_usd: totalUsd,
      tenants: Array.from(byTenant.values()).sort(
        (a, b) => b.total_ars - a.total_ars,
      ),
    };

    return json(result, 200);
  } catch (e) {
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
