-- 040_pricing_settings.sql
-- Promos (% efectivo / débito / cuotas) por tenant en app_config.
-- Fuente de verdad compartida entre devices (antes solo SharedPreferences).

alter table public.app_config
  add column if not exists pricing_settings jsonb;

comment on column public.app_config.pricing_settings is
  'JSON: efectivo, debito, tarjeta1..18 (porcentajes). Null = defaults de app.';
