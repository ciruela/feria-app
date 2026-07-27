# Tienda web multi-tenant (storefront)

App Next.js (App Router) que muestra el catálogo público de cada armería y
recibe pedidos. Cada armería es un tenant, identificado por su `slug`.

## Cómo funciona

- Ruta `/[tenant]` (ej. `/armeriapepe`) o subdominio `armeriapepe.tudominio.com`.
- El catálogo y los pedidos se sirven vía Edge Functions de Supabase:
  - `storefront-catalog` (catálogo público por slug)
  - `storefront-order` (crea el pedido, recalculando precios en el servidor)
- La tienda NO accede a la base directamente: solo usa esas funciones, así la
  RLS sigue estricta y no se expone data de ningún tenant.

## Setup

```bash
cd web-storefront
cp .env.example .env.local   # completar con tu proyecto Supabase
npm install
npm run dev
```

Variables:
- `NEXT_PUBLIC_SUPABASE_FUNCTIONS_URL` = `https://TU_PROYECTO.supabase.co/functions/v1`
- `NEXT_PUBLIC_SUPABASE_ANON_KEY` = anon key del proyecto

Habilitar la tienda de una armería: `update tenants set storefront_enabled = true where slug = 'armeriapepe';`

## Deploy

Deploy en Vercel (o similar). Para tenants por subdominio, configurar un
wildcard `*.tudominio.com` y resolver el slug desde el host.

## Pendiente (pagos y legal)

- Pagos: integrar Mercado Pago en `storefront-order` (crear preferencia y
  devolver `init_point`). Hoy el pedido queda `pendiente` y la armería coordina.
- Legal (ARG): la venta/entrega de armas y munición está regulada por ANMaC.
  La entrega exige validación presencial de credenciales del comprador
  (CLU/tenencia). El storefront funciona como catálogo + reserva/pedido, NO como
  entrega instantánea. Revisar requisitos legales antes de habilitar pagos.
