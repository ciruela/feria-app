-- =====================================================================
-- Migracion 001 - Fundacion multi-tenant (SaaS armerias)
-- =====================================================================
--
-- Convierte la base de una sola armeria en multi-tenant:
--   - tenants (armerias), memberships (usuario -> tenant + rol), platform_admins
--   - columna tenant_id en todas las tablas de negocio
--   - custom access token hook (mete tenant_id / rol / is_platform_admin en el JWT)
--   - RLS por tenant (reemplaza las policies abiertas `using (true)`)
--   - triggers que setean tenant_id en cada insert desde el claim
--   - backfill: mueve TODOS los datos actuales al tenant #1
--
-- IMPORTANTE - orden de despliegue:
--   1) Correr esta migracion (crea estructura + backfill, RLS aun permisiva).
--   2) Desplegar la app con Supabase Auth (Fase 2).
--   3) Correr la seccion final "ACTIVAR RLS ESTRICTA" para cerrar el acceso anon.
--   Asi la app actual NO se rompe entre el paso 1 y el 2.
--
-- Ejecutar en: Supabase Dashboard -> SQL Editor
-- =====================================================================

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- 1. Tablas base de tenancy
-- ---------------------------------------------------------------------

create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  slug text not null unique,
  activo boolean not null default true,
  plan text not null default 'basico',
  created_at timestamptz not null default now()
);

-- Usuario (auth.users) -> tenant + rol. Un usuario puede pertenecer a >1 tenant.
create table if not exists public.memberships (
  user_id uuid not null references auth.users (id) on delete cascade,
  tenant_id uuid not null references public.tenants (id) on delete cascade,
  rol text not null default 'admin' check (rol in ('owner', 'admin')),
  nombre text not null default '',
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  primary key (user_id, tenant_id)
);

create index if not exists memberships_user_idx on public.memberships (user_id);
create index if not exists memberships_tenant_idx on public.memberships (tenant_id);

-- Super admins de la plataforma (vos). Acceso global, cross-tenant.
create table if not exists public.platform_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  nombre text not null default '',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- 2. Columna tenant_id en todas las tablas de negocio
-- ---------------------------------------------------------------------

alter table public.productos          add column if not exists tenant_id uuid references public.tenants (id);
alter table public.vendedores         add column if not exists tenant_id uuid references public.tenants (id);
alter table public.administradores    add column if not exists tenant_id uuid references public.tenants (id);
alter table public.stock_movimientos  add column if not exists tenant_id uuid references public.tenants (id);
alter table public.audit_log          add column if not exists tenant_id uuid references public.tenants (id);
alter table public.ventas             add column if not exists tenant_id uuid references public.tenants (id);
alter table public.app_config         add column if not exists tenant_id uuid references public.tenants (id);

create index if not exists productos_tenant_idx         on public.productos (tenant_id);
create index if not exists vendedores_tenant_idx        on public.vendedores (tenant_id);
create index if not exists administradores_tenant_idx   on public.administradores (tenant_id);
create index if not exists stock_mov_tenant_idx         on public.stock_movimientos (tenant_id, created_at);
create index if not exists audit_log_tenant_idx         on public.audit_log (tenant_id, created_at);
create index if not exists ventas_tenant_idx            on public.ventas (tenant_id, created_at);

-- Unicidad de negocio por tenant (dos armerias pueden repetir codigo/PIN entre si,
-- pero no dentro de la misma armeria).
create unique index if not exists productos_tenant_codigo_uidx
  on public.productos (tenant_id, codigo) where codigo <> '';
create unique index if not exists administradores_tenant_pin_uidx
  on public.administradores (tenant_id, pin);

-- ---------------------------------------------------------------------
-- 3. Backfill: mover TODO lo existente al tenant #1 (tu armeria actual)
-- ---------------------------------------------------------------------

do $$
declare
  v_tenant uuid;
begin
  -- Crea (o reutiliza) el tenant por defecto para los datos actuales.
  select id into v_tenant from public.tenants where slug = 'default';
  if v_tenant is null then
    insert into public.tenants (nombre, slug) values ('Mi Armeria', 'default')
    returning id into v_tenant;
  end if;

  update public.productos         set tenant_id = v_tenant where tenant_id is null;
  update public.vendedores        set tenant_id = v_tenant where tenant_id is null;
  update public.administradores   set tenant_id = v_tenant where tenant_id is null;
  update public.stock_movimientos set tenant_id = v_tenant where tenant_id is null;
  update public.audit_log         set tenant_id = v_tenant where tenant_id is null;
  update public.ventas            set tenant_id = v_tenant where tenant_id is null;
  update public.app_config        set tenant_id = v_tenant where tenant_id is null;
end $$;

-- ---------------------------------------------------------------------
-- 4. Custom access token hook: agrega claims al JWT en cada login
--    (tenant_id, app_role, is_platform_admin)
--    Habilitar luego en: Dashboard -> Authentication -> Hooks -> Access Token
-- ---------------------------------------------------------------------

create or replace function public.custom_access_token_hook(event jsonb)
returns jsonb
language plpgsql
stable
as $$
declare
  claims jsonb;
  v_tenant uuid;
  v_role text;
  v_is_platform boolean;
begin
  select m.tenant_id, m.rol
    into v_tenant, v_role
  from public.memberships m
  where m.user_id = (event->>'user_id')::uuid
    and m.activo
  order by m.created_at
  limit 1;

  select exists (
    select 1 from public.platform_admins pa
    where pa.user_id = (event->>'user_id')::uuid
  ) into v_is_platform;

  claims := coalesce(event->'claims', '{}'::jsonb);

  if v_tenant is not null then
    claims := jsonb_set(claims, '{tenant_id}', to_jsonb(v_tenant::text));
    claims := jsonb_set(claims, '{app_role}', to_jsonb(coalesce(v_role, 'admin')));
  end if;
  claims := jsonb_set(claims, '{is_platform_admin}', to_jsonb(coalesce(v_is_platform, false)));

  event := jsonb_set(event, '{claims}', claims);
  return event;
end;
$$;

-- Permisos para que el motor de Auth pueda ejecutar el hook.
grant usage on schema public to supabase_auth_admin;
grant execute on function public.custom_access_token_hook(jsonb) to supabase_auth_admin;
grant select on public.memberships to supabase_auth_admin;
grant select on public.platform_admins to supabase_auth_admin;

-- ---------------------------------------------------------------------
-- 5. Helpers de RLS (leen los claims del JWT)
-- ---------------------------------------------------------------------

create or replace function public.current_tenant_id()
returns uuid
language sql
stable
as $$
  select nullif(auth.jwt()->>'tenant_id', '')::uuid;
$$;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
as $$
  select coalesce((auth.jwt()->>'is_platform_admin')::boolean, false);
$$;

-- ---------------------------------------------------------------------
-- 6. Triggers: setear tenant_id automaticamente en insert desde el claim
--    (asi el codigo del cliente casi no cambia)
-- ---------------------------------------------------------------------

create or replace function public.set_tenant_id()
returns trigger
language plpgsql
as $$
begin
  if new.tenant_id is null then
    new.tenant_id := public.current_tenant_id();
  end if;
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'productos', 'vendedores', 'administradores',
    'stock_movimientos', 'audit_log', 'ventas', 'app_config'
  ]
  loop
    execute format('drop trigger if exists set_tenant_id_trg on public.%I;', t);
    execute format(
      'create trigger set_tenant_id_trg before insert on public.%I
         for each row execute function public.set_tenant_id();', t
    );
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 7. RLS en las tablas de tenancy
-- ---------------------------------------------------------------------

alter table public.tenants enable row level security;
alter table public.memberships enable row level security;
alter table public.platform_admins enable row level security;

-- tenants: el usuario ve su(s) tenant(s); platform admin ve todos.
drop policy if exists "tenants_select" on public.tenants;
create policy "tenants_select" on public.tenants
  for select using (
    public.is_platform_admin()
    or id = public.current_tenant_id()
  );

drop policy if exists "tenants_platform_write" on public.tenants;
create policy "tenants_platform_write" on public.tenants
  for all using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- memberships: cada quien ve sus membresias; platform admin ve todo.
drop policy if exists "memberships_select" on public.memberships;
create policy "memberships_select" on public.memberships
  for select using (
    public.is_platform_admin()
    or user_id = auth.uid()
    or tenant_id = public.current_tenant_id()
  );

drop policy if exists "memberships_platform_write" on public.memberships;
create policy "memberships_platform_write" on public.memberships
  for all using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- platform_admins: solo platform admins.
drop policy if exists "platform_admins_all" on public.platform_admins;
create policy "platform_admins_all" on public.platform_admins
  for all using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- =====================================================================
-- ACTIVAR RLS ESTRICTA (paso 3 del despliegue)
-- ---------------------------------------------------------------------
-- Correr SOLO despues de desplegar la app con Supabase Auth (Fase 2).
-- Reemplaza las policies abiertas por policies por tenant.
-- Para revertir temporalmente al modo abierto, volve a las policies
-- `using (true)` de supabase/schema.sql.
-- =====================================================================

do $$
declare
  t text;
begin
  foreach t in array array[
    'productos', 'vendedores', 'administradores',
    'stock_movimientos', 'audit_log', 'ventas', 'app_config'
  ]
  loop
    execute format('alter table public.%I enable row level security;', t);

    -- Borrar policies abiertas heredadas del esquema single-tenant.
    execute format('drop policy if exists "%1$s_select" on public.%1$s;', t);
    execute format('drop policy if exists "%1$s_write"  on public.%1$s;', t);
    execute format('drop policy if exists "%1$s_insert" on public.%1$s;', t);
    execute format('drop policy if exists "%1$s_update" on public.%1$s;', t);
    execute format('drop policy if exists "%1$s_tenant" on public.%1$s;', t);

    -- Policy por tenant (platform admin puede todo).
    execute format(
      'create policy "%1$s_tenant" on public.%1$s
         for all
         using (tenant_id = public.current_tenant_id() or public.is_platform_admin())
         with check (tenant_id = public.current_tenant_id() or public.is_platform_admin());',
      t
    );
  end loop;
end $$;
