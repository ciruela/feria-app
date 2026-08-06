# Handoff — campañas Urban (2026-08-06)

## Estado remoto
- `main` @ 76663fe: import endurecido + pricing P0/P1 (deploy Pages OK).
- `staging`: push de commits locales que faltaban.
- Esta branch: plan de campañas/descuentos + notas del Excel Urban.

## Excel Urban (Desktop)
`Catalogo_Armas_Nuevas_Urban_con_Cantidad.xlsx`
- Hojas: Gral (~332), Taurus (~50), BERSA (ARS + promo), Accesorios.
- Gral: TC 1570, arancel 1.03, factores cuota 1.0913 / 1.1666 / 1.3659.
- BERSA: -5% efectivo + 3 cuotas sin interés.
- SARICAM: -10% efectivo en textos.

## Decisiones
- Feature general (todas las armerías).
- Campaña activa reemplaza Precios y cuotas en productos match.
- World Guns: pricing general. Urban: campañas (+ fórmula urban).

## Migración pendiente en Supabase
`040_pricing_settings.sql` (pricing_settings jsonb) — aplicar si aún no está en prod.

## Plan
Ver `docs/plans/campanas-descuentos-admin.md`
