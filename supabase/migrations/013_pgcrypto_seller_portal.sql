-- 013_pgcrypto_seller_portal.sql
-- Hotfix si ya corriste 012 sin pgcrypto (error digest(text, unknown) does not exist).

create extension if not exists pgcrypto with schema extensions;

create or replace function public.hash_portal_code(p_code text)
returns text
language sql
immutable
parallel safe
as $$
  select encode(
    extensions.digest(
      'feria-armeria::portal::v1' || trim(p_code),
      'sha256'
    ),
    'hex'
  );
$$;

notify pgrst, 'reload schema';
