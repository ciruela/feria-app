-- =====================================================================
-- 035_realtime_sync.sql
-- ---------------------------------------------------------------------
-- AR-18: el cliente polléa cada 5s porque Realtime de vendedores /
-- administradores nunca emite (tablas fuera de supabase_realtime).
-- productos y app_config ya estaban en la publication.
--
-- También FULL replica identity para DELETE con RLS por tenant (AR-20).
-- =====================================================================

begin;

-- Publication: idempotente (ignora si ya está).
do $$
begin
  begin
    alter publication supabase_realtime add table public.vendedores;
  exception
    when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.administradores;
  exception
    when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.ventas;
  exception
    when duplicate_object then null;
  end;
end $$;

alter table public.vendedores replica identity full;
alter table public.administradores replica identity full;
alter table public.ventas replica identity full;

-- productos / app_config ya FULL; reafirmar por si un entorno quedó en default.
alter table public.productos replica identity full;
alter table public.app_config replica identity full;

commit;
