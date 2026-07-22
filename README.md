# feria-app

App Flutter para catálogo de precios en feria de armas, caza y pesca (uso interno).

## Configuración Supabase (obligatorio para sync entre celulares)

1. Creá un proyecto en [supabase.com](https://supabase.com)
2. Seguí [`supabase/SETUP.md`](supabase/SETUP.md): ejecutá `schema.sql`, `seed.sql` y creá el bucket `feria-fotos`
3. Copiá credenciales a `.env`:

```bash
cp .env.example .env
# Editá SUPABASE_URL y SUPABASE_ANON_KEY
```

4. Desde **Administración** → **Publicar catálogo a Supabase** (carga inicial desde JSON local)

Los scripts de iOS leen `.env` automáticamente vía `scripts/dart_defines.sh`.

## Ejecutar en iPhone / iPad físico

La app compila para **iPhone e iPad** (iOS 15.5+), incluyendo iPhone 17 Pro Max e iPad Pro 11 pulgadas.

**Importante (iOS 26):** en dispositivos físicos recientes, el modo **debug crashea al abrir**. Usá siempre **release**:

```bash
chmod +x scripts/run_ios_device.sh scripts/dart_defines.sh
./scripts/run_ios_device.sh
```

Con `.env` configurado, el script incluye las credenciales de Supabase.

### Tu dispositivo (desarrollo)

1. Conectá el iPhone/iPad por USB y tocá **Confiar** en la Mac.
2. En Xcode, abrí `ios/Runner.xcworkspace` → target **Runner** → **Signing & Capabilities** → elegí tu **Team**.
3. Ejecutá `./scripts/run_ios_device.sh` (modo release + `.env`).

O directamente:

```bash
flutter run -d <ID_DE_TU_IPHONE> --release $(scripts/dart_defines.sh)
```

### Equipo (~20 personas) — TestFlight (recomendado)

Requisito: **Apple Developer Program** activo (Team `DU5HQZ784R`).

#### Una sola vez — App Store Connect

1. Entrá a [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **+** → **New App**
2. Nombre: `Catálogo Feria` (o el que quieras)
3. Bundle ID: `com.armeria.feria.appFeria` (debe existir en [Certificates, Identifiers](https://developer.apple.com/account/resources/identifiers/list))
4. SKU: `feria-app-001`
5. **No hace falta publicar en la App Store** — solo TestFlight

#### Cada build nuevo

1. Verificá `.env` con Supabase (las credenciales quedan embebidas en el IPA):

```bash
cp .env.example .env   # si aún no existe
./scripts/verify_supabase.sh
```

2. Generá el IPA para TestFlight:

```bash
chmod +x scripts/build_ios_ipa.sh scripts/dart_defines.sh
./scripts/build_ios_ipa.sh appstore
```

3. Subí el IPA:
   - Abrí **Transporter** (Mac App Store) y arrastrá `build/ios/ipa/*.ipa`, **o**
   - Xcode → **Window → Organizer** → **Distribute App** → App Store Connect

4. En App Store Connect → tu app → **TestFlight**:
   - Esperá que termine el procesamiento (~5–15 min)
   - **External Testing** → creá un grupo (ej. `Armería`) → agregá los mails del equipo
   - La primera build externa pide revisión beta de Apple (suele tardar pocas horas)

5. Cada vendedor:
   - Instala la app **TestFlight** de Apple
   - Abre el mail de invitación → **Accept** → **Install**
   - Puede activar actualización automática de betas en TestFlight

**Notas TestFlight:**

- Usá `appstore`, no `development` — solo `appstore` sirve para TestFlight.
- El IPA va en **release** con Supabase embebido; no hace falta `.env` en cada celu.
- Tras instalar, Admin → **Publicar catálogo** una vez; después stock/TC/vendedores sync solos.
- Para subir otra versión: cambiá `version:` en `pubspec.yaml` (ej. `1.0.1+2`) y repetí el build.

**Opción alternativa: Ad Hoc** (sin TestFlight)

- Registrá los UDID de cada teléfono en [developer.apple.com](https://developer.apple.com).
- `./scripts/build_ios_ipa.sh adhoc`
- Distribuí el `.ipa` e instalá con Apple Configurator o Xcode.

### Simulador (solo desarrollo)

El simulador **iOS 26** (iPhone 17 Pro) no es compatible con el escaneo de DNI (ML Kit).
Usá un simulador **iOS 17.5** o un dispositivo físico:

```bash
flutter run -d "iPhone 15 Pro" $(scripts/dart_defines.sh)
```

En dispositivos reales el escaneo de DNI, PDF e impresión funcionan con normalidad.

## CI — TestFlight automático (GitHub Actions)

Cada push a `main` que toque `lib/`, `ios/` o `pubspec.yaml` compila y sube a **TestFlight**.

### Configurar secrets (una sola vez)

En GitHub → **feria-app** → **Settings** → **Secrets and variables** → **Actions**:

| Secret | Qué es |
|--------|--------|
| `SUPABASE_URL` | URL del proyecto Supabase |
| `SUPABASE_ANON_KEY` | anon key de Supabase |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID ([Integrations → API](https://appstoreconnect.apple.com/access/integrations/api)) |
| `APP_STORE_CONNECT_KEY_ID` | Key ID de la API key |
| `APP_STORE_CONNECT_PRIVATE_KEY` | Contenido completo del archivo `.p8` |
| `APP_STORE_CERTIFICATE_KEY` | Contraseña interna del certificado (ya configurada en el repo) |

Ya **no hace falta** exportar `.p12` manualmente: el CI crea/descarga el certificado con la API Key.

Para cargar los secrets de Apple en GitHub:

```bash
# 1. Crear API Key en App Store Connect → Integrations → API
# 2. Guardar en .secrets/apple-api.env y .secrets/AuthKey_XXX.p8
# 3. Ejecutar:
./scripts/load_apple_secrets_to_github.sh
```

### Flujo

1. Editás código y hacés `git push` a `main`
2. GitHub Actions compila el IPA y lo sube a TestFlight
3. Los testers reciben la update (con **actualizaciones automáticas** activadas en TestFlight)

Los cambios de **catálogo / TC / vendedores** en Supabase **no** pasan por CI — se sincronizan solos en la app.

## Ejecutar (modo local, sin nube)

Sin `.env` la app usa `assets/data/products.json` y `sellers.json` embebidos:

```bash
flutter pub get
flutter run -d chrome
```

## Supabase (referencia rápida)

Variables en `.env` o `--dart-define`:

| Variable | Descripción |
|----------|-------------|
| `SUPABASE_URL` | Project URL del dashboard |
| `SUPABASE_ANON_KEY` | anon public key |

Setup completo: [`supabase/SETUP.md`](supabase/SETUP.md)

## PIN admin por defecto

`2580`
