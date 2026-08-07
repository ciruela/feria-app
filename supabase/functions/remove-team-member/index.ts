// Edge Function: remove-team-member
//
// Quita a alguien del equipo de la armería activa (elimina la membership).
//
// POST /remove-team-member
// Authorization: Bearer <jwt del dueño>
// body: { user_id }
//
// Deploy:
//   supabase functions deploy remove-team-member --project-ref <ref>

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    const url = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    const authHeader = req.headers.get("Authorization") ?? "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!jwt) return json({ error: "No autorizado" }, 401);

    const body = await req.json().catch(() => ({}));
    const targetUserId = String(body.user_id ?? "").trim();
    if (!targetUserId) {
      return json({ error: "user_id requerido" }, 400);
    }

    const authClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });
    const { data: userData, error: userErr } = await authClient.auth.getUser(jwt);
    if (userErr || !userData?.user) {
      return json({ error: "No autorizado" }, 401);
    }
    const callerId = userData.user.id;

    const payload = decodeJwtPayload(jwt);
    const bodyTenant = String(body.tenant_id ?? "").trim();
    const metaTenant = String(
      (userData.user.app_metadata as Record<string, unknown> | undefined)
        ?.active_tenant ?? "",
    ).trim();
    let tenantId = String(payload.tenant_id ?? bodyTenant ?? metaTenant).trim();
    const isPlatformAdmin =
      payload.is_platform_admin === true ||
      payload.is_platform_admin === "true";

    if (!tenantId) {
      return json(
        { error: "Sin armería activa en la sesión. Elegí una organización." },
        400,
      );
    }

    if (targetUserId === callerId) {
      return json({ error: "No podés eliminarte a vos mismo del equipo" }, 400);
    }

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false },
    });

    if (!isPlatformAdmin) {
      const { data: callerMembership } = await admin
        .from("memberships")
        .select("rol,activo")
        .eq("user_id", callerId)
        .eq("tenant_id", tenantId)
        .maybeSingle();
      if (!callerMembership?.activo || callerMembership.rol !== "owner") {
        return json(
          { error: "Solo el dueño de la armería puede quitar personas" },
          403,
        );
      }
    }

    const { data: targetMembership, error: targetErr } = await admin
      .from("memberships")
      .select("rol,activo,nombre")
      .eq("user_id", targetUserId)
      .eq("tenant_id", tenantId)
      .maybeSingle();

    if (targetErr) {
      return json({ error: targetErr.message }, 500);
    }
    if (!targetMembership) {
      return json({ error: "Esa persona no está en el equipo" }, 404);
    }

    if (targetMembership.rol === "owner") {
      const { count, error: countErr } = await admin
        .from("memberships")
        .select("user_id", { count: "exact", head: true })
        .eq("tenant_id", tenantId)
        .eq("rol", "owner")
        .eq("activo", true);

      if (countErr) {
        return json({ error: countErr.message }, 500);
      }
      if ((count ?? 0) <= 1) {
        return json(
          { error: "No podés eliminar al único dueño de la armería" },
          400,
        );
      }
    }

    const { error: deleteErr } = await admin
      .from("memberships")
      .delete()
      .eq("user_id", targetUserId)
      .eq("tenant_id", tenantId);

    if (deleteErr) {
      return json({ error: deleteErr.message }, 500);
    }

    try {
      const { data: existing } = await admin.auth.admin.getUserById(targetUserId);
      const prevMeta =
        (existing.user?.app_metadata as Record<string, unknown> | undefined) ??
        {};
      if (String(prevMeta.active_tenant ?? "") === tenantId) {
        const nextMeta = { ...prevMeta };
        delete nextMeta.active_tenant;
        await admin.auth.admin.updateUserById(targetUserId, {
          app_metadata: nextMeta,
        });
      }
    } catch {
      // no bloqueante
    }

    return json(
      {
        ok: true,
        user_id: targetUserId,
        nombre: targetMembership.nombre ?? "",
      },
      200,
    );
  } catch (e) {
    console.error("remove-team-member error:", e);
    return json({ error: "Error interno" }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function decodeJwtPayload(token: string): Record<string, unknown> {
  try {
    const part = token.split(".")[1];
    if (!part) return {};
    const normalized = part.replace(/-/g, "+").replace(/_/g, "/");
    const jsonStr = atob(normalized);
    return JSON.parse(jsonStr) as Record<string, unknown>;
  } catch {
    return {};
  }
}
