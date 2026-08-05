// Edge Function: seller-portal-validate
//
// AR-15: valida dominio+clave del portal de vendedores.
// - Solo POST (no GET oráculo)
// - Rate limit por IP (+ slug en SQL)
// - Llama validate_seller_portal con service-role (RPC no expuesto a anon)
//
// POST { slug, codigo }

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const IP_LIMIT = 40;
const IP_WINDOW_SEC = 900;

function clientIp(req: Request): string {
  return (
    req.headers.get("cf-connecting-ip") ||
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ||
    req.headers.get("x-real-ip") ||
    "unknown"
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
      console.error("seller-portal-validate: missing env");
      return json({ error: "Configuracion del servidor incompleta" }, 500);
    }

    const body = await req.json();
    const slug = String(body?.slug ?? "").trim();
    const codigo = String(body?.codigo ?? "").trim();
    if (!slug || !codigo) {
      return json({ error: "Dominio o clave incorrectos" }, 400);
    }

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false },
    });

    const ip = clientIp(req);
    const { data: ipRate, error: ipRateError } = await admin.rpc(
      "touch_seller_portal_rate_limit",
      {
        p_bucket: `ip:${ip}`,
        p_limit: IP_LIMIT,
        p_window_seconds: IP_WINDOW_SEC,
      },
    );

    if (ipRateError) {
      console.error("seller-portal-validate ip rate failed", ipRateError);
      return json({ error: "No se pudo validar el acceso" }, 500);
    }
    if (ipRate && ipRate.allowed === false) {
      return json(
        { error: "Demasiados intentos. Proba mas tarde." },
        429,
        { "Retry-After": String(ipRate.retry_after ?? IP_WINDOW_SEC) },
      );
    }

    const { data, error } = await admin.rpc("validate_seller_portal", {
      p_slug: slug,
      p_codigo: codigo,
      p_client_key: ip,
    });

    if (error) {
      const msg = error.message || "Dominio o clave incorrectos";
      if (msg.toLowerCase().includes("demasiados intentos")) {
        return json({ error: msg }, 429);
      }
      // Mensaje genérico: no filtrar existencia de slug.
      if (
        msg.includes("incorrectos") ||
        msg.includes("No hay vendedores")
      ) {
        return json({ error: msg }, msg.includes("vendedores") ? 403 : 401);
      }
      console.error("seller-portal-validate rpc failed", error);
      return json({ error: "Dominio o clave incorrectos" }, 401);
    }

    return json(data, 200);
  } catch (e) {
    console.error("seller-portal-validate unhandled", e);
    return json({ error: String(e) }, 500);
  }
});

function json(
  body: unknown,
  status: number,
  extraHeaders: Record<string, string> = {},
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...cors,
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}
