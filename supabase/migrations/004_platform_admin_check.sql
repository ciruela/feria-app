-- Verifica si el usuario autenticado es platform admin (para el selector de workspace).
-- El JWT a veces no trae is_platform_admin al primer login; esto lo confirma en servidor.

create or replace function public.am_i_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.platform_admins pa
    where pa.user_id = auth.uid()
  );
$$;

grant execute on function public.am_i_platform_admin() to authenticated;
