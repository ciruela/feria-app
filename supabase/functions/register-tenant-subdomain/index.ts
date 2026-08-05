// Edge Function: register-tenant-subdomain
//
// Registra {slug}.armenext.com en Cloudflare Pages al crear una armería.
//
// Secrets (supabase secrets set):
//   CLOUDFLARE_API_TOKEN
//   CLOUDFLARE_ACCOUNT_ID
//   CLOUDFLARE_PAGES_PROJECT=feria-app   (opcional)
//   TENANT_APP_DOMAIN=armenext.com       (opcional)
//
// POST /register-tenant-subdomain
// Authorization: Bearer <jwt owner recién provisionado>

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }
  if (req.method !== "POST") {
    return json({ error: "Método no permitido" }, 405);
  }

  try {
    const token = Deno.env.get("CLOUDFLARE_API_TOKEN")?.trim();
    const accountId = Deno.env.get("CLOUDFLARE_ACCOUNT_ID")?.trim();
    if (!token || !accountId) {
      return json({ error: "Cloudflare no configurado en el servidor" }, 503);
    }

    const project = Deno.env.get("CLOUDFLARE_PAGES_PROJECT")?.trim() ||
      "feria-app";
    const baseDomain = Deno.env.get("TENANT_APP_DOMAIN")?.trim() ||
      "armenext.com";

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!jwt) return json({ error: "No autorizado" }, 401);

    const payload = decodeJwtPayload(jwt);
    const tenantId = String(payload.tenant_id ?? "").trim();
    if (!tenantId) {
      return json({ error: "Sin armería activa en la sesión" }, 400);
    }

    const slug = await fetchTenantSlug(tenantId);
    if (!slug) {
      return json({ error: "No se encontró el slug del tenant" }, 404);
    }

    const subdomain = slug.toLowerCase().replace(/-/g, "").replace(
      /[^a-z0-9]/g,
      "",
    );
    if (!subdomain) {
      return json({ error: "Slug inválido" }, 400);
    }

    const hostname = `${subdomain}.${baseDomain}`;
    const cf = await registerPagesDomain({
      accountId,
      project,
      hostname,
      token,
    });

    return json({
      ok: true,
      hostname,
      url: `https://${hostname}`,
      cloudflare: cf,
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return json({ error: message }, 500);
  }
});

async function fetchTenantSlug(tenantId: string): Promise<string | null> {
  const url = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const res = await fetch(
    `${url}/rest/v1/tenants?id=eq.${tenantId}&select=slug&limit=1`,
    {
      headers: {
        apikey: serviceKey,
        Authorization: `Bearer ${serviceKey}`,
      },
    },
  );
  if (!res.ok) {
    throw new Error(`Supabase tenants: HTTP ${res.status}`);
  }
  const rows = await res.json();
  const slug = rows?.[0]?.slug;
  return typeof slug === "string" && slug.trim() ? slug.trim() : null;
}

async function registerPagesDomain(opts: {
  accountId: string;
  project: string;
  hostname: string;
  token: string;
}): Promise<{ status: string }> {
  const res = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${opts.accountId}/pages/projects/${opts.project}/domains`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${opts.token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ name: opts.hostname }),
    },
  );

  const body = await res.json().catch(() => ({}));
  if (res.ok) {
    return { status: "created" };
  }

  const errors = JSON.stringify(body?.errors ?? body);
  if (/already exists|duplicate|already been taken|already added this custom domain|8000018/i.test(errors)) {
    return { status: "exists" };
  }

  throw new Error(`Cloudflare Pages domain: HTTP ${res.status} ${errors}`);
}

function decodeJwtPayload(jwt: string): Record<string, unknown> {
  const parts = jwt.split(".");
  if (parts.length < 2) return {};
  const padded = parts[1].replace(/-/g, "+").replace(/_/g, "/");
  const json = atob(padded.padEnd(padded.length + (4 - padded.length % 4) % 4, "="));
  return JSON.parse(json);
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}
