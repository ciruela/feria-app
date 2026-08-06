// Edge Function: invite-team-member
//
// Invita a alguien a la armería activa por email.
// - Si NO tiene cuenta: Auth manda el mail de invitación (inviteUserByEmail)
//   y se crea la membership con el user_id nuevo.
// - Si YA tiene cuenta: se agrega la membership (sin exigir registro previo
//   del lado del dueño) y se responde como "already_member_added".
//
// POST /invite-team-member
// Authorization: Bearer <jwt del dueño>
// body: { email, nombre?, rol? }
//
// Deploy:
//   supabase functions deploy invite-team-member --project-ref <ref>

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
    const email = String(body.email ?? "").trim().toLowerCase();
    const nombre = String(body.nombre ?? "").trim();
    const rol = String(body.rol ?? "admin").trim().toLowerCase();

    if (!email || !email.includes("@")) {
      return json({ error: "Email inválido" }, 400);
    }
    if (rol !== "owner" && rol !== "admin") {
      return json({ error: "Rol inválido" }, 400);
    }

    // 1. Identidad del que llama.
    const authClient = createClient(url, anonKey, {
      global: { headers: { Authorization: authHeader } },
      auth: { persistSession: false },
    });
    const { data: userData, error: userErr } = await authClient.auth.getUser(jwt);
    if (userErr || !userData?.user) {
      return json({ error: "No autorizado" }, 401);
    }
    const callerId = userData.user.id;

    // Claims del JWT (tenant activo).
    const payload = decodeJwtPayload(jwt);
    const tenantId = String(payload.tenant_id ?? "").trim();
    const isPlatformAdmin =
      payload.is_platform_admin === true ||
      payload.is_platform_admin === "true";

    if (!tenantId) {
      return json(
        { error: "Sin armería activa en la sesión. Elegí una organización." },
        400,
      );
    }

    const admin = createClient(url, serviceKey, {
      auth: { persistSession: false },
    });

    // 2. Solo dueño (o platform admin) puede invitar.
    if (!isPlatformAdmin) {
      const { data: membership } = await admin
        .from("memberships")
        .select("rol,activo")
        .eq("user_id", callerId)
        .eq("tenant_id", tenantId)
        .maybeSingle();
      if (!membership?.activo || membership.rol !== "owner") {
        return json(
          { error: "Solo el dueño de la armería puede invitar personas" },
          403,
        );
      }
    }

    const displayName =
      nombre || email.split("@")[0] || "Integrante";

    // 3. Preferir siempre el mail de invitación de Auth:
    //    la persona crea su cuenta desde el link del correo.
    //    Si ya estaba registrada → solo membership (sin otro mail).
    let userId: string | null = null;
    let emailSent = false;
    let status: "invited" | "added" = "added";

    const { data: invited, error: inviteErr } = await admin.auth.admin
      .inviteUserByEmail(email, {
        data: {
          full_name: displayName,
          invited_tenant_id: tenantId,
          invited_role: rol,
        },
      });

    if (!inviteErr && invited?.user) {
      userId = invited.user.id;
      emailSent = true;
      status = "invited";
    } else if (isAlreadyRegisteredError(inviteErr)) {
      userId = await findUserIdByEmail(admin, email);
      if (!userId) {
        return json(
          { error: inviteErr?.message ?? "No se pudo invitar" },
          400,
        );
      }
      // Si nunca confirmó el mail, reenviar invitación para que termine de crear la cuenta.
      const { data: existingUser } = await admin.auth.admin.getUserById(userId);
      if (!existingUser.user?.email_confirmed_at) {
        try {
          const { error: resendErr } = await admin.auth.resend({
            type: "invite",
            email,
          });
          if (!resendErr) {
            emailSent = true;
            status = "invited";
          }
        } catch {
          // best-effort: la membership igual se crea
        }
      }
    } else {
      return json(
        { error: inviteErr?.message ?? "No se pudo enviar la invitación" },
        400,
      );
    }

    // 4. Membership en el tenant (idempotente).
    const { error: upsertErr } = await admin.from("memberships").upsert(
      {
        user_id: userId,
        tenant_id: tenantId,
        rol,
        nombre: displayName,
        activo: true,
      },
      { onConflict: "user_id,tenant_id" },
    );
    if (upsertErr) {
      return json({ error: upsertErr.message }, 500);
    }

    // 5. Dejar active_tenant listo SOLO si el usuario no tiene uno ya.
    //    AR-24: no pisar el tenant activo de alguien que ya opera en OTRA
    //    armería (efecto cross-tenant).
    try {
      const { data: existing } = await admin.auth.admin.getUserById(userId!);
      const prevMeta =
        (existing.user?.app_metadata as Record<string, unknown> | undefined) ??
        {};
      const currentActive = String(prevMeta.active_tenant ?? "").trim();
      if (!currentActive) {
        await admin.auth.admin.updateUserById(userId!, {
          app_metadata: { ...prevMeta, active_tenant: tenantId },
        });
      }
    } catch {
      // no bloqueante
    }

    return json(
      {
        ok: true,
        status,
        email_sent: emailSent,
        user_id: userId,
        email,
      },
      200,
    );
  } catch (e) {
    console.error("invite-team-member error:", e);
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

function isAlreadyRegisteredError(error: { message?: string } | null): boolean {
  const msg = (error?.message ?? "").toLowerCase();
  return (
    msg.includes("already") ||
    msg.includes("registered") ||
    msg.includes("exists")
  );
}

/** Busca user_id por email (Auth Admin). Pagina si hace falta. */
async function findUserIdByEmail(
  admin: ReturnType<typeof createClient>,
  email: string,
): Promise<string | null> {
  const target = email.toLowerCase();
  // listUsers no filtra por email en todos los runtimes; paginamos hasta un
  // tope alto (AR-24: antes cortaba en 2.000 usuarios y dejaba de encontrar
  // gente en silencio). Se recorre hasta agotar páginas.
  for (let page = 1; page <= 200; page++) {
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage: 200,
    });
    if (error) break;
    const hit = data.users.find(
      (u) => (u.email ?? "").toLowerCase() === target,
    );
    if (hit) return hit.id;
    if (data.users.length < 200) break;
  }
  return null;
}
