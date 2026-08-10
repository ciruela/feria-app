# Accesorios en el catálogo — documentación de implementación

Branch: `feature/accesorios-catalogo`  
Base: `main` @ `165267a` (sincronizado con `origin/main`)  
Estado: **Fase 0 y Fase 1 completadas** · Fases 2–5 pendientes

---

## Objetivo

Agregar la categoría **Accesorios** al catálogo de feria-app, con el mismo flujo que armas cortas, armas largas y munición:

- Importación desde Excel (hoja separada + columna `tipo`)
- Alta desde administración / stock
- Carrito y ventas
- Métricas y cierre de stock (planificado en fases posteriores)

---

## Decisiones de producto (Acordadas)

| Tema | Decisión |
|---|---|
| Calibre | Opcional; si aplica va en **descripción**, no como campo obligatorio |
| Stock | **Unidades** (no cajas) |
| Datos previos | No hay accesorios importados; arranque limpio |
| Métricas | Bucket propio `accesorios` (Fase 4) |
| Excel | Hoja `"Accesorios"` + columna `tipo = accesorios` en cada fila |

---

## Fase 0 — Alineación de branch

**Qué se hizo**

```bash
git checkout main
git pull origin main          # +52 commits
git checkout feature/accesorios-catalogo
git rebase main
```

**Verificación**

- `HEAD`, `main` y `origin/main` → mismo commit `165267a`
- 0 commits de diferencia entre `main` y la feature branch
- Working tree limpio antes de codear

---

## Fase 1 — Core (implementado en este commit)

### 1. Modelo de dominio

**Archivo:** `lib/models/product.dart`

- Nuevo valor enum: `ProductType.accesorios` (`key`: `accesorios`, `label`: `Accesorios`)
- Getter: `isAccesorios`
- Stock documentado como unidades para armas/accesorios

### 2. Importación Excel

**Archivo:** `lib/services/excel_catalog_service.dart`

- `ExcelCatalogService.resolveProductType()`:
  - Lee columna `tipo` (`accesorios`, `municion`, `arma_corta`, `arma_larga`)
  - **Fallback:** si `tipo` está vacío y la hoja se llama `"Accesorios"` → `accesorios`
  - Sin `tipo` ni hoja reconocida → default `municion` (planillas CCI)
- `ExcelProductRow.fromMap` usa el resolver anterior

### 3. Catálogo / alta manual

**Archivo:** `lib/services/catalog_service.dart`

- Calibre **opcional** para accesorios en `addProduct`
- Prefijo de ID: `acc` (`_nextProductId`)
- Validación al crear: marca + (código **o** descripción); calibre no requerido
- `_canCreateFromRow`: accesorios siguen reglas de munición (identificación por código/modelo/descripción)

### 4. Migración Supabase

**Archivo:** `supabase/migrations/052_accesorios_product_type.sql`

```sql
-- Amplía productos_type_check para incluir 'accesorios'
```

**⚠️ No aplicada en prod todavía.** Orden seguro de deploy:

1. Aplicar migración SQL en Supabase
2. Deploy app con soporte `accesorios`
3. Importar / crear productos accesorios

Aplicación manual: SQL Editor del dashboard, o GitHub Action `Supabase Migrations` con `migration_file: 052_accesorios_product_type.sql`.

### 5. Script Urban Tactical

**Archivo:** `scripts/urban_catalog_normalize.py`

- Hoja `Accesorios` → `tipo: "accesorios"` (antes mapeaba a `municion`)
- Sin `balas_por_caja`; calibre vacío; descripción con el nombre del ítem
- Marca genérica: `"Accesorios"`

### 6. UI mínima para compilar

**Archivos:** `lib/theme/app_theme.dart`, `lib/widgets/product_card.dart`, `lib/screens/product_detail_screen.dart`

- Color `AppColors.accesorios` y casos en switches de acento (requerido por exhaustividad del enum)

### 7. Documentación admin Excel

**Archivo:** `lib/screens/admin/admin_excel_screen.dart`

- Tipos válidos: `municion · arma_corta · arma_larga · accesorios`

### 8. Tests

**Archivos:** `test/models/product_test.dart`, `test/services/excel_catalog_test.dart`

- `ProductType.fromKey('accesorios')`
- Flags y carrito para accesorios
- Parseo Excel por columna `tipo` y por nombre de hoja

---

## Comportamiento esperado de Accesorios

| Aspecto | Comportamiento |
|---|---|
| Stock | Unidades |
| Carrito | Merge de cantidad (como munición) |
| Número de serie | No |
| Tarjeta de consumo | No |
| Balas por caja | No |
| Calibre en DB | Vacío; detalle en `descripcion` |
| Pricing | Reglas generales (no promo munición) |

---

## Infraestructura local configurada (sesión)

| Herramienta | Estado |
|---|---|
| GitHub CLI (`gh`) | Instalado; sesión `Marobarrera` |
| Flutter SDK | Instalado en `C:\Users\Mariano\flutter` (stable 3.44.9) |
| `.env` | No presente → app corre en **modo local** (`assets/data/products.json`) |

**Correr la app (modo local, sin Supabase):**

```powershell
$env:Path = "C:\Users\Mariano\flutter\bin;" + $env:Path
flutter pub get
flutter run -d chrome --web-port=8080
```

**Tests Fase 1:**

```powershell
flutter test test/models/product_test.dart test/services/excel_catalog_test.dart
```

**PIN admin por defecto (README):** `2580`

---

## Qué probar ya (Fase 1)

1. **Preview Excel** — Admin → Importar Excel → archivo con hoja Accesorios (no confirmar sync a prod sin migración)
2. **Alta manual** — Admin → Nuevo producto → chip Accesorios → sin calibre, con descripción
3. **Tests automáticos** — comandos arriba

**No probar aún en prod:** insertar `type = accesorios` en Supabase sin migración `052`.

---

## Fases pendientes

| Fase | Contenido |
|---|---|
| **2 — UI** | Botón home, chips filtro, formulario admin adaptado, taglines |
| **3 — Carrito/venta** | Verificar merge qty, checkout, `register_sale` |
| **4 — Métricas/cierre** | Bucket `accesorios` en `sales_metrics`, `stock_cierre`, pantallas admin |
| **5 — Deploy prod** | Migración → app → import Excel |

---

## Riesgos conocidos (prod)

1. **Orden deploy:** app antes de datos, migración antes de inserts
2. **Excel sin `tipo` ni hoja Accesorios:** filas caen en munición (mitigado con doble salvaguarda acordada)
3. **Métricas/cierre sin Fase 4:** accesorios vendidos se mezclan con munición/armas en reportes
4. **`ProductType.fromKey`:** crash si DB tiene `accesorios` y app vieja

---

## Archivos tocados (Fase 0 + 1)

```
lib/models/product.dart
lib/services/excel_catalog_service.dart
lib/services/catalog_service.dart
lib/theme/app_theme.dart
lib/widgets/product_card.dart
lib/screens/product_detail_screen.dart
lib/screens/admin/admin_excel_screen.dart
scripts/urban_catalog_normalize.py
supabase/migrations/052_accesorios_product_type.sql
test/models/product_test.dart
test/services/excel_catalog_test.dart
docs/accesorios-catalogo.md
```

---

## Historial de la sesión

1. Análisis de alcance y riesgos (sin implementar)
2. Respuestas de producto validadas contra el código
3. Branch `feature/accesorios-catalogo` creada desde `main`
4. Fase 0: rebase sobre `origin/main` (+52 commits)
5. Fase 1: enum, Excel, catalog service, migración, Urban, tests
6. Fix compilación: switches exhaustivos + `AppColors.accesorios`
7. Setup local: `gh` auth, Flutter SDK clone, `flutter pub get`
8. Intento `flutter run`: primer build falló por switches; puerto 7357 ocupado en reintento
