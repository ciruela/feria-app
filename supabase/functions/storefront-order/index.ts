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

// Límites defensivos del pedido web público.
const MAX_ITEMS = 100;
const MAX_QTY_PER_ITEM = 9999;
const MAX_FIELD_LEN = 200;

// Recorta un campo de texto libre del cliente a un largo seguro.
function cleanField(value: unknown): string {
  return String(value ?? "").trim().slice(0, MAX_FIELD_LEN);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });

  try {
    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const body = await req.json();

    const slug = (body.slug ?? "").trim();
    const cliente = body.cliente ?? {};
    const rawItems: Array<{ productId: string; quantity: number }> =
      Array.isArray(body.items) ? body.items : [];

    if (!slug || rawItems.length === 0) {
      return json({ error: "Pedido invalido" }, 400);
    }

    // Límite defensivo de líneas por pedido (evita payloads abusivos).
    if (rawItems.length > MAX_ITEMS) {
      return json({ error: "Demasiados items en el pedido" }, 400);
    }

    // Agrega cantidades por producto: si el mismo id viene repetido, se suma
    // (así el chequeo de stock es contra el total real, no por línea suelta).
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

    const { data: tenant } = await admin
      .from("tenants")
      .select("id,activo,storefront_enabled")
      .eq("slug", slug)
      .maybeSingle();
    if (!tenant || !tenant.activo || !tenant.storefront_enabled) {
      return json({ error: "Tienda no disponible" }, 404);
    }

    // Traer los productos reales del tenant para recalcular precios.
    const ids = [...wanted.keys()];
    const { data: productos } = await admin
      .from("productos")
      .select("id,precio_usd,stock,marca,modelo,codigo")
      .eq("tenant_id", tenant.id)
      .in("id", ids);

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
        cliente_nombre: cleanField(cliente.nombre),
        cliente_email: cleanField(cliente.email),
        cliente_telefono: cleanField(cliente.telefono),
        cliente_dni: cleanField(cliente.dni),
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
