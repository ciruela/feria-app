# Estado de migraciones (AR-21)

Fuente de verdad del SQL que corre en producción. Toda migración aplicada
queda registrada en `supabase_migrations.schema_migrations` (consultable con
`supabase migration list --linked`). Este archivo documenta el estado y los
huecos históricos de numeración.

## Aplicadas

`001`, `003`, `004`, `005`, `007`, `008`, `009`, `011`, `012`, `014`, `015`,
`016`, `017`, `018`, `019`, `020`, `021*`, `022`, `023`, `024`, `025`, `026`,
`027`, `028`, `029`, `030`, `031`, `032`, `033`, `034`, `035`, `036`, `037`,
`038`, `039`, `040`, `041`, `042`, `043`, `044`, `045`, `046`, `047`, `048`, `049`, `050`,
`051`, `052`.

- `035` — Realtime: `vendedores`/`administradores`/`ventas` en la publication
  + `REPLICA IDENTITY FULL` (AR-18, AR-20).
- `036` — grants por columna en `productos`/`tenants` (AR-26, mass assignment AR-23).
- `037` — FK `stock_movimientos.producto_id` + CHECK de dominio (AR-23).
- `038` — `cierres_caja` persistido + guard de período cerrado (AR-22).
- `039` — índice de trazabilidad `(tenant_id, producto_id, created_at)` (AR-25).
- `040` — `pricing_settings` en `app_config`.
- `041` — columna `productos.fixed_prices` (Urban).
- `042` — `register_sale` respeta `fixed_prices` (totales Urban).
- `046` — admin master PIN.
- `047` — override pricing munición (`p_pricing.municion`) + seed World Guns.
- `048` — 3 cuotas SI munición solo arma larga (`tarjeta3_solo_arma_larga`).
- `049` — `dolar_billete` cotiza como efectivo (mismo %); unit_usd alineado.
- `050` — World Guns: `transferencia_como_efectivo` tenant-wide + restore promos.

- `051` — World Guns: alta del producto especial "Cajón Stopping Power 9mm"
  (1 cajón = 20 cajas = 1000 tiros) con `fixed_prices` (USD 440 / $682.000
  final efectivo/transferencia, sin tarjeta ni el 10%). Aplicada por SQL
  Editor + `supabase migration repair --status applied 051`.

- `052` — amplía `productos_type_check` para incluir `'accesorios'`
  (categoría accesorios). Defensiva/idempotente. Aplicada vía workflow
  `Supabase Migrations` (run 31392405731, HTTP 201).

## NO aplicada (decisión pendiente)

- `002_storefront.sql` — la tienda web pública. Ver **AR-13**: se decide su
  destino antes de aplicarla (activaría hallazgos latentes de AR-24).

## Huecos de numeración (documentados)

- `010` y `013` — no existen archivos. No representan cambios aplicados;
  la numeración salta. No renumerar (rompería el histórico ya registrado).

`*` `021` reutiliza numeración de un objeto de stock; su marcador está activo
en la base (verificado). Si hay dudas, correr `supabase migration list --linked`.

## Reglas

1. Nada de SQL a mano en producción: siempre archivo en `migrations/` +
   registro en `schema_migrations`.
2. Permisos: un `REVOKE` solo resta de un `GRANT` del **mismo alcance** y
   destinatario (AR-16 funciones, AR-26 columnas). Verificado por
   `supabase/tests/*_grants_test.sql`.
3. El CI (`ci.yml` job `hygiene`) valida que toda Edge Function esté en el
   workflow de deploy y declare `verify_jwt` en `config.toml`.
