// Edge Function: storefront-order
//
// Crea un pedido web para una armeria. Recalcula precios/totales del lado del
// servidor (nunca confia en el precio que manda el cliente) y valida stock.
// Usa service-role; el pedido queda 'pendiente' para que el admin lo confirme.
//
// POST /storefront-order
// body: { slug, cliente: {nombre,email,telefono,dni}, items: [{productId, quantity}] }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_ITEMS = 100;
const MAX_QTY_PER_ITEM = 9999;
const MAX_FIELD_LEN = 200;
const RATE_WINDOW_MS = 60 * 60 * 1000;
const RATE_MAX_PER_EMAIL = 5;
const RATE_MAX_PER_IP = 30;

function cleanField(value: unknown): string {
  return String(value ?? "").trim().slice(0, MAX_FIELD_LEN);
}

function looksLikeEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

function clientIp(req: Request): string {
  return (
    req.headers.get("cf-connecting-ip") ||
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    req.headers.get("x-real-ip") ||
    "unknown"
  );
}

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
  if (req.method !== "POST") {
    return json({ error: "Metodo no permitido" }, 405);
  }

  try {
    const url = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!url || !serviceKey) {
      console.error("storefront-order: missing env");
      return json({ error: "Configuracion del servidor incompleta" }, 500);
    }

    const body = await req.json();
    const slug = (body.slug ?? "").trim();
    const cliente = body.cliente ?? {};
    const rawItems: Array<{ productId: string; quantity: number }> =
      Array.isArray(body.items) ? body.items : [];

    if (!slug || rawItems.length === 0) {
      return json({ error: "Pedido invalido" }, 400);
    }
    if (rawItems.length > MAX_ITEMS) {
      return json({ error: "Demasiados items en el pedido" }, 400);
    }

    const nombre = cleanField(cliente.nombre);
    const email = cleanField(cliente.email).toLowerCase();
    const telefono = cleanField(cliente.telefono);
    const dni = cleanField(cliente.dni);

    if (nombre.length < 3) {
      return json({ error: "Nombre de cliente invalido" }, 400);
    }
    if (!looksLikeEmail(email)) {
      return json({ error: "Email invalido" }, 400);
    }
    if (dni.length < 6) {
      return json({ error: "DNI invalido" }, 400);
    }

    const wanted = new Map<string, number>();
    for (const item of rawItems) {
      const id = String(item?.productId ?? "").trim();
      if (!id) return json({ error: "Item invalido" }, 400);
      const qty = Math.floor(Number(item?.quantity) || 0);
      if (qty <= 0) continue;
      if (qty > MAX_QTY_PER_ITEM) {
        return json({ error: "Cantidad invalida" }, 400);
      }
      wanted.set(id, (wanted.get(id) ?? 0) + qty);
    }
    if (wanted.size === 0) {
      return json({ error: "Pedido invalido" }, 400);
    }

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false },
    });

    const { data: tenant, error: tenantError } = await admin
      .from("tenants")
      .select("id,activo,storefront_enabled")
      .eq("slug", slug)
      .maybeSingle();

    if (tenantError) {
      console.error("storefront-order tenant lookup failed", tenantError);
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

    const since = new Date(Date.now() - RATE_WINDOW_MS).toISOString();
    const { count: emailCount, error: emailRateError } = await admin
      .from("pedidos")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", tenant.id)
      .eq("cliente_email", email)
      .gte("created_at", since);

    if (emailRateError) {
      console.error("storefront-order rate email failed", emailRateError);
      if (isSchemaMissing(emailRateError)) {
        return json(
          {
            error: "Storefront no configurado en el servidor",
            code: "schema_missing",
          },
          503,
        );
      }
      return json({ error: emailRateError.message }, 500);
    }
    if ((emailCount ?? 0) >= RATE_MAX_PER_EMAIL) {
      return json({ error: "Demasiados pedidos. Proba mas tarde." }, 429);
    }

    const ip = clientIp(req);
    const ipMarker = `ip:${ip}`;
    const { count: ipCount, error: ipRateError } = await admin
      .from("pedidos")
      .select("id", { count: "exact", head: true })
      .eq("tenant_id", tenant.id)
      .eq("nota", ipMarker)
      .gte("created_at", since);

    if (ipRateError) {
      console.error("storefront-order rate ip failed", ipRateError);
      return json({ error: ipRateError.message }, 500);
    }
    if ((ipCount ?? 0) >= RATE_MAX_PER_IP) {
      return json({ error: "Demasiados pedidos. Proba mas tarde." }, 429);
    }

    const ids = [...wanted.keys()];
    const { data: productos, error: productosError } = await admin
      .from("productos")
      .select("id,precio_usd,stock,marca,modelo,codigo")
      .eq("tenant_id", tenant.id)
      .in("id", ids);

    if (productosError) {
      console.error("storefront-order productos failed", productosError);
      return json({ error: productosError.message }, 500);
    }

    const byId = new Map((productos ?? []).map((p: any) => [p.id, p]));

    let totalUsd = 0;
    const lines: any[] = [];
    for (const [productId, qty] of wanted) {
      const p = byId.get(productId);
      if (!p) return json({ error: `Producto inexistente: ${productId}` }, 400);
      if (p.stock !== null && Number(p.stock) < qty) {
        return json({ error: `Sin stock: ${p.marca} ${p.modelo}` }, 409);
      }
      const lineUsd = Number(p.precio_usd) * qty;
      totalUsd += lineUsd;
      lines.push({
        productId: p.id,
        codigo: p.codigo,
        detalle: `${p.marca} ${p.modelo}`.trim(),
        quantity: qty,
        unitUsd: Number(p.precio_usd),
        lineUsd,
      });
    }

    const { data: pedido, error } = await admin
      .from("pedidos")
      .insert({
        tenant_id: tenant.id,
        cliente_nombre: nombre,
        cliente_email: email,
        cliente_telefono: telefono,
        cliente_dni: dni,
        items: { lines },
        total_usd: totalUsd,
        estado: "pendiente",
        pago_estado: "pendiente",
        nota: ipMarker,
      })
      .select("id")
      .single();

    if (error) {
      console.error("storefront-order insert failed", error);
      if (isSchemaMissing(error)) {
        return json(
          {
            error: "Storefront no configurado en el servidor",
            code: "schema_missing",
          },
          503,
        );
      }
      return json({ error: error.message }, 500);
    }

    return json(
      { id: pedido.id, total_usd: totalUsd, estado: "pendiente" },
      201,
    );
  } catch (e) {
    console.error("storefront-order unhandled", e);
    return json({ error: String(e) }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
