# Configuración de Supabase (Dashboard)

Pasos manuales en [supabase.com/dashboard](https://supabase.com/dashboard). Ejecutalos **una vez** por proyecto.

## 1. SQL — tablas y datos iniciales

1. Abrí **SQL Editor** → **New query**
2. Pegá y ejecutá [`schema.sql`](schema.sql)
3. Pegá y ejecutá [`seed.sql`](seed.sql)

## 2. Storage — fotos de productos

1. **Storage** → **New bucket**
2. Nombre: `feria-fotos`
3. Marcá **Public bucket**
4. (Opcional) Ejecutá [`storage.sql`](storage.sql) para políticas de lectura pública

Subí las fotos al bucket (ej. `magtech-9mm.jpg`) y guardá en `productos.foto_url` el **path relativo** (`magtech-9mm.jpg`) o la URL pública completa.

## 3. Credenciales para la app

1. **Settings** → **API**
2. Copiá **Project URL** y **anon public key**
3. En la raíz del repo:

```bash
cp .env.example .env
# Editá .env con URL y anon key reales
```

## 4. Verificación

1. Corré la app con `.env` configurado (ver README)
2. Admin → **Publicar catálogo a Supabase** (carga inicial desde JSON local)
3. Empleado → botón nube: debe bajar productos y vendedores
4. Generá un comprobante: debe aparecer una fila en `ventas` y bajar el stock del producto en todos los celulares al instante

## Tiempo real

La app escucha cambios en vivo de Supabase cuando hay `.env` configurado:

- **`app_config`** — tipo de cambio (admin guarda → todos actualizan precios)
- **`productos`** — stock, precios y datos del catálogo

Ejecutá la sección de Realtime en `schema.sql` si el proyecto ya existía antes de esta versión.

## Consultas útiles

```sql
select count(*) from productos;
select count(*) from vendedores;
select id, cliente_nombre, total_ars, created_at from ventas order by created_at desc limit 10;
```
