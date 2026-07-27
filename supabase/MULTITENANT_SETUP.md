# Rollout multi-tenant (SaaS armerías)

Orden de despliegue para pasar de una armería a multi-tenant sin romper la app
en producción.

## 1. Backend (Supabase)

1. Ejecutar `supabase/migrations/001_multitenant.sql`
   - Crea `tenants`, `memberships`, `platform_admins`, agrega `tenant_id` a todo,
     crea el JWT hook, triggers y hace el backfill de tus datos actuales al
     tenant `default`.
   - NO corras todavía la sección final "ACTIVAR RLS ESTRICTA".
2. Activar el hook: Dashboard → Authentication → Hooks → Access Token →
   seleccionar `custom_access_token_hook`.
3. Crear el/los usuarios admin en Authentication → Users, y vincularlos:
   ```sql
   insert into public.memberships (user_id, tenant_id, rol, nombre)
   values ('<auth_user_id>', '<tenant_id_default>', 'owner', 'Dueño');
   ```
4. Crear tu super admin:
   ```sql
   insert into public.platform_admins (user_id, nombre)
   values ('<tu_auth_user_id>', 'Agustín');
   ```

## 2. App (Flutter) — Auth + registro

- Desplegar la app con login (ya incluido). Probar que un admin entra con
  email/password y ve solo su tenant.
- **Confirmación de email (obligatorio para registro):**
  Dashboard → Authentication → Providers → Email → activar **Confirm email**.
  Opcional: personalizar la plantilla del mail en Authentication → Email Templates.
- **Registro self-service:** pantalla **Registrar mi armería** (nombre, email,
  contraseña, nombre de armería). Tras confirmar el mail y volver a ingresar, se
  crea el tenant automáticamente (`provision_my_tenant`) **solo** si el registro
  incluyó `registration_intent: create_organization` en user_metadata.
- **Iniciar sesión:** no crea organizaciones. Cuentas sin membership ven la
  pantalla "Sin acceso" hasta recibir invitación (fase 2) o registrar armería.
- Ejecutar `008_provision_guard.sql` en prod para reforzar el guard en SQL.
- **Tenant World Guns (feria):** ejecutar `006_world_guns_tenant.sql` — migra
  los datos de `default` a `world-guns` y vincula al dueño.

## 3. Cerrar el acceso abierto

- Recién ahora correr la sección "ACTIVAR RLS ESTRICTA" de
  `001_multitenant.sql`. Esto reemplaza las policies `using (true)` por policies
  por tenant. Verificar con `supabase/tests/rls_isolation_test.sql`.

## 4. Panel super admin + cambio de armería (multi-membresía)

- `supabase functions deploy platform-metrics`
- Ejecutar `supabase/migrations/003_tenant_switching.sql`
  - Actualiza el JWT hook para respetar el "tenant activo" (guardado en
    `app_metadata.active_tenant`), amplía `tenants_select` para que un usuario
    vea todas sus armerías y crea el RPC `set_active_tenant`.
- Un mismo usuario puede pertenecer a varias armerías: sumale una fila por
  armería en `memberships`. Si además es super admin, agregalo a
  `platform_admins`.
  ```sql
  -- Ejemplo: dar acceso del mismo usuario a otra armería
  insert into public.memberships (user_id, tenant_id, rol, nombre)
  values ('<auth_user_id>', '<tenant_id_armeria_pepe>', 'admin', 'Agustín');
  ```
- Al iniciar sesión, si el usuario tiene más de un destino (varias armerías y/o
  el panel de plataforma), la app muestra un **selector de espacio de trabajo**.
  Con un solo destino entra directo. Desde adentro puede volver al selector con
  el botón "cambiar" (↔).

## 5. Tienda web (opcional)

1. `supabase/migrations/002_storefront.sql`
2. `supabase functions deploy storefront-catalog storefront-order`
3. Habilitar la tienda: `update tenants set storefront_enabled = true where slug = 'default';`
4. Deploy de `web-storefront/` (ver su README). Pagos (Mercado Pago) y marco
   legal (ANMaC) quedan pendientes de definir antes de cobrar online.

## Notas de seguridad

- La service-role key solo vive en Edge Functions, nunca en la app ni en la web.
- Los PIN se guardan hasheados (SHA-256).
- Aislamiento de datos garantizado por RLS + claims del JWT, testeado en
  `supabase/tests/rls_isolation_test.sql`.
