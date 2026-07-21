# feria-app

App Flutter para catálogo de precios en feria de armas, caza y pesca (uso interno).

## Ejecutar (modo local, sin nube)

```bash
flutter pub get
flutter run -d chrome
```

## Supabase

1. Creá un proyecto en [supabase.com](https://supabase.com)
2. Ejecutá `supabase/schema.sql` y `supabase/seed.sql` en el SQL Editor
3. Creá bucket público `feria-fotos` en Storage para las fotos
4. Corré la app con tus credenciales:

```bash
flutter run -d chrome \
  --dart-define=SUPABASE_URL=https://TU_PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Desde **Administración** podés **Publicar catálogo a Supabase** la primera vez para subir los productos locales.

## PIN admin por defecto

`2580`
