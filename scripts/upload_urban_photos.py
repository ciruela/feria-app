#!/usr/bin/env python3
"""Sube fotos locales de Urban Tactical a Supabase Storage y las asocia a productos.

Espera archivos tipo: `carabina-benelli-lupo__BENELLILUPO.png`
donde el SKU tras `__` coincide con `productos.codigo`.

Uso:
  # Dry-run (no sube):
  python scripts/upload_urban_photos.py --dry-run

  # Subir (requiere SERVICE_ROLE en .env):
  python scripts/upload_urban_photos.py

Env (.env o variables):
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY   (Settings → API → service_role)
  URBAN_PHOTOS_DIR            (default: Desktop/fotos_productos)
"""

from __future__ import annotations

import argparse
import csv
import mimetypes
import os
import re
import sys
import time
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_PHOTOS = Path.home() / "Desktop" / "fotos_productos"
BUCKET = "feria-fotos"
SLUG = "urban-tactical"
EXTS = {".jpg", ".jpeg", ".png", ".webp"}
SKU_RE = re.compile(r"__([^.]+)\.[^.]+$", re.IGNORECASE)

# SKUs del CSV REVISAR_A_MANO marcados como foto incorrecta.
SKIP_SKUS = {
    "50596733",  # Canik TP9 Elite SC Grey → foto TP9 SFx
    "NUEVAgirsans9chrome",
    "NUEVAPSAdagger",
}


def load_dotenv(path: Path) -> None:
    if not path.is_file():
        return
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, val = line.split("=", 1)
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        os.environ.setdefault(key, val)


def norm(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", (s or "").lower())


def content_type(path: Path) -> str:
    guessed, _ = mimetypes.guess_type(path.name)
    if guessed:
        return guessed
    ext = path.suffix.lower()
    return {
        ".jpg": "image/jpeg",
        ".jpeg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
    }.get(ext, "application/octet-stream")


def collect_photos(photos_dir: Path) -> list[tuple[str, Path]]:
    out: list[tuple[str, Path]] = []
    for path in sorted(photos_dir.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in EXTS:
            continue
        m = SKU_RE.search(path.name)
        if not m:
            print(f"  skip (sin SKU): {path.name}")
            continue
        out.append((m.group(1), path))
    return out


def load_skip_from_revisar(photos_dir: Path) -> set[str]:
    skip = set(SKIP_SKUS)
    csv_path = photos_dir / "REVISAR_A_MANO.csv"
    if not csv_path.is_file():
        return skip
    with csv_path.open(encoding="utf-8", errors="replace", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            estado = (row.get("Estado") or "").upper()
            if "ERROR CONFIRMADO" not in estado:
                continue
            raw = row.get("SKU") or ""
            for part in re.split(r"[/,]", raw):
                sku = part.strip()
                if sku:
                    skip.add(sku)
    return skip


class Supabase:
    def __init__(self, url: str, key: str):
        self.url = url.rstrip("/")
        self.session = requests.Session()
        self.session.headers.update(
            {
                "apikey": key,
                "Authorization": f"Bearer {key}",
            }
        )

    def get_tenant_id(self, slug: str) -> str:
        r = self.session.get(
            f"{self.url}/rest/v1/tenants",
            params={"select": "id,slug,nombre", "slug": f"eq.{slug}"},
            timeout=60,
        )
        r.raise_for_status()
        rows = r.json()
        if not rows:
            raise SystemExit(f"No encontré tenant slug={slug}")
        return rows[0]["id"]

    def fetch_products(self, tenant_id: str) -> list[dict]:
        products: list[dict] = []
        page_size = 1000
        offset = 0
        while True:
            r = self.session.get(
                f"{self.url}/rest/v1/productos",
                params={
                    "select": "id,codigo,marca,modelo,descripcion,type,fotos,foto_url,activo",
                    "tenant_id": f"eq.{tenant_id}",
                    "activo": "eq.true",
                    "order": "codigo.asc",
                    "limit": str(page_size),
                    "offset": str(offset),
                },
                timeout=120,
            )
            r.raise_for_status()
            batch = r.json()
            products.extend(batch)
            if len(batch) < page_size:
                break
            offset += page_size
        return products

    def upload(self, storage_path: str, file_path: Path) -> None:
        data = file_path.read_bytes()
        if len(data) > 5 * 1024 * 1024:
            raise RuntimeError(f"Foto > 5MB: {file_path.name} ({len(data)} bytes)")
        r = self.session.post(
            f"{self.url}/storage/v1/object/{BUCKET}/{storage_path}",
            headers={
                "Content-Type": content_type(file_path),
                "x-upsert": "true",
            },
            data=data,
            timeout=120,
        )
        if r.status_code >= 400:
            raise RuntimeError(f"upload {storage_path}: {r.status_code} {r.text}")

    def update_photos(self, product_id: str, paths: list[str]) -> None:
        payload = {
            "fotos": paths,
            "foto_url": paths[0] if paths else "",
        }
        r = self.session.patch(
            f"{self.url}/rest/v1/productos",
            params={"id": f"eq.{product_id}"},
            headers={
                "Content-Type": "application/json",
                "Prefer": "return=minimal",
            },
            json=payload,
            timeout=60,
        )
        if r.status_code >= 400:
            raise RuntimeError(f"patch {product_id}: {r.status_code} {r.text}")


def index_products(products: list[dict]) -> dict[str, dict]:
    by_code: dict[str, dict] = {}
    for p in products:
        code = (p.get("codigo") or "").strip()
        if not code:
            continue
        by_code[norm(code)] = p
        by_code[code.lower()] = p
    return by_code


def existing_fotos(product: dict) -> list[str]:
    fotos = product.get("fotos") or []
    paths = [str(x).strip() for x in fotos if str(x).strip()]
    legacy = (product.get("foto_url") or "").strip()
    if legacy and legacy not in paths:
        paths.insert(0, legacy)
    return paths


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--photos",
        type=Path,
        default=Path(os.environ.get("URBAN_PHOTOS_DIR", DEFAULT_PHOTOS)),
    )
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Reemplaza foto aunque el producto ya tenga fotos",
    )
    parser.add_argument(
        "--include-bad",
        action="store_true",
        help="Incluye SKUs marcados ERROR CONFIRMADO en REVISAR_A_MANO.csv",
    )
    parser.add_argument("--limit", type=int, default=0)
    args = parser.parse_args()

    load_dotenv(ROOT / ".env")
    url = os.environ.get("SUPABASE_URL", "").strip()
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "").strip()
    if not url:
        print("Falta SUPABASE_URL en .env", file=sys.stderr)
        return 2
    if not key and not args.dry_run:
        print(
            "Falta SUPABASE_SERVICE_ROLE_KEY en .env\n"
            "Dashboard → Project Settings → API → service_role (secret).\n"
            "Pegala en .env como:\n"
            "  SUPABASE_SERVICE_ROLE_KEY=eyJ...\n"
            "Luego re-ejecutá este script.",
            file=sys.stderr,
        )
        return 2

    photos_dir = args.photos
    if not photos_dir.is_dir():
        print(f"No existe carpeta de fotos: {photos_dir}", file=sys.stderr)
        return 2

    pairs = collect_photos(photos_dir)
    skip = set() if args.include_bad else load_skip_from_revisar(photos_dir)
    print(f"Fotos: {len(pairs)} en {photos_dir}")
    print(f"SKUs a omitir (foto mala): {sorted(skip)}")

    if args.dry_run and not key:
        # Solo inventario local
        by_sku: dict[str, list[Path]] = {}
        for sku, path in pairs:
            by_sku.setdefault(sku, []).append(path)
        multi = {k: v for k, v in by_sku.items() if len(v) > 1}
        print(f"SKUs únicos: {len(by_sku)}")
        if multi:
            print(f"SKUs con más de una foto: {len(multi)}")
            for sku, paths in list(multi.items())[:10]:
                print(f"  {sku}: {[p.name for p in paths]}")
        print("Dry-run local OK. Agregá SERVICE_ROLE para matchear contra Supabase.")
        return 0

    sb = Supabase(url, key)
    tenant_id = sb.get_tenant_id(SLUG)
    print(f"Tenant {SLUG}: {tenant_id}")
    products = sb.fetch_products(tenant_id)
    print(f"Productos activos: {len(products)}")
    by_code = index_products(products)

    matched = 0
    uploaded = 0
    skipped_has_photo = 0
    skipped_bad = 0
    missing: list[str] = []
    errors: list[str] = []

    work = pairs
    if args.limit > 0:
        work = pairs[: args.limit]

    for i, (sku, path) in enumerate(work, 1):
        if sku in skip or any(norm(sku) == norm(s) for s in skip):
            skipped_bad += 1
            continue
        product = by_code.get(norm(sku)) or by_code.get(sku.lower())
        if product is None:
            missing.append(f"{sku}\t{path.name}")
            continue
        matched += 1
        current = existing_fotos(product)
        if current and not args.force:
            skipped_has_photo += 1
            continue

        ptype = product.get("type") or "arma_corta"
        pid = product["id"]
        ts = int(time.time() * 1000)
        ext = path.suffix.lower().lstrip(".")
        if ext == "jpeg":
            ext = "jpg"
        storage_path = f"{tenant_id}/{ptype}/{pid}/{ts}.{ext}"

        label = (
            f"[{i}/{len(work)}] {sku} -> "
            f"{product.get('marca')} {product.get('modelo') or product.get('codigo')}"
        )
        if args.dry_run:
            print(f"DRY  {label}")
            print(f"     {path.name} -> {storage_path}")
            continue

        try:
            print(f"UP   {label}")
            sb.upload(storage_path, path)
            # Sin fotos previas (o --force): una sola foto. No acumula.
            new_paths = [storage_path]
            sb.update_photos(pid, new_paths)
            product["fotos"] = new_paths
            product["foto_url"] = new_paths[0]
            uploaded += 1
        except Exception as exc:  # noqa: BLE001
            msg = f"{sku}: {exc}"
            errors.append(msg)
            print(f"ERR  {msg}")

    report = ROOT / "build" / "urban_photo_upload_report.txt"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(
        "\n".join(
            [
                f"matched={matched}",
                f"uploaded={uploaded}",
                f"skipped_has_photo={skipped_has_photo}",
                f"skipped_bad={skipped_bad}",
                f"missing={len(missing)}",
                f"errors={len(errors)}",
                "",
                "=== MISSING CODIGO ===",
                *missing,
                "",
                "=== ERRORS ===",
                *errors,
            ]
        ),
        encoding="utf-8",
    )

    print()
    print(f"matched={matched} uploaded={uploaded} "
          f"skipped_has_photo={skipped_has_photo} skipped_bad={skipped_bad} "
          f"missing={len(missing)} errors={len(errors)}")
    print(f"Reporte: {report}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
