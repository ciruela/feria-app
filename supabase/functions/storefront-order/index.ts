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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const body = await req.json();

    const slug = (body.slug ?? "").trim();
    const cliente = body.cliente ?? {};
    const items: Array<{ productId: string; quantity: number }> =
      Array.isArray(body.items) ? body.items : [];

    if (!slug || items.length === 0) {
      return json({ error: "Pedido invalido" }, 400);
    }

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false },
    });

    const { data: tenant } = await admin
      .from("tenants")
      .select("id,activo,storefront_enabled")
      .eq("slug", slug)
      .maybeSingle();
    if (!tenant || !tenant.activo || !tenant.storefront_enabled) {
      return json({ error: "Tienda no disponible" }, 404);
    }

    // Traer los productos reales del tenant para recalcular precios.
    const ids = items.map((i) => i.productId);
    const { data: productos } = await admin
      .from("productos")
      .select("id,precio_usd,stock,marca,modelo,codigo")
      .eq("tenant_id", tenant.id)
      .in("id", ids);

    const byId = new Map((productos ?? []).map((p: any) => [p.id, p]));

    let totalUsd = 0;
    const lines: any[] = [];
    for (const item of items) {
      const p = byId.get(item.productId);
      const qty = Math.max(1, Math.floor(Number(item.quantity) || 0));
      if (!p) return json({ error: `Producto inexistente: ${item.productId}` }, 400);
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
        cliente_nombre: (cliente.nombre ?? "").toString(),
        cliente_email: (cliente.email ?? "").toString(),
        cliente_telefono: (cliente.telefono ?? "").toString(),
        cliente_dni: (cliente.dni ?? "").toString(),
        items: { lines },
        total_usd: totalUsd,
        estado: "pendiente",
        pago_estado: "pendiente",
      })
      .select("id")
      .single();

    if (error) return json({ error: error.message }, 500);

    // TODO(pagos): aca se crearia la preferencia de Mercado Pago y se devolveria
    // el init_point para redirigir al checkout. Por ahora el pedido queda
    // 'pendiente' y la armeria coordina pago/retiro (requisito legal ANMaC:
    // la entrega de armas/municion exige validacion presencial de credenciales).

    return json({ id: pedido.id, total_usd: totalUsd, estado: "pendiente" }, 201);
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
