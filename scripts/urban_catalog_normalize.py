#!/usr/bin/env python3
"""Normaliza el Excel de catálogo de Urban Tactical (4 pestañas heterogéneas)
a un Excel limpio y canónico que el importador de la app entiende, incluyendo
las columnas de precios fijos (fiel al Excel, la app NO recalcula nada).

Pestañas de entrada:
  - Gral      : armas (pistolas/revólver = arma_corta; carabinas/escopetas/
                fusiles/PCC/DEC = arma_larga). Efectivo/PVP en USD, cuotas en ARS.
  - Taurus    : idem Gral pero columnas corridas (precio en E, descripción en F).
  - BERSA     : pistolas agrupadas por calibre, con variantes por acabado. ARS.
  - Accesorios: munición (cajas). ARS.

Salida: un único sheet "Catalogo" con encabezados canónicos + precios fijos.

Uso:
  python3 scripts/urban_catalog_normalize.py \
      ~/Downloads/Catalogo_Armas_Nuevas_Urban_con_Cantidad.xlsx \
      ~/Downloads/urban_catalog_clean.xlsx
"""
import sys
import re

import openpyxl

TC = 1570.0  # tipo de cambio del Excel (celda R2 "TC:")

OUT_HEADERS = [
    "tipo", "marca", "calibre", "modelo", "codigo", "descripcion",
    "precio_usd", "stock", "stock_inicial",
    "efectivo_ars", "efectivo_usd", "tarjeta_ars",
    "cuota3_ars", "cuota6_ars", "cuota12_ars",
]


def num(v):
    """Convierte una celda a float o None."""
    if v is None:
        return None
    if isinstance(v, (int, float)):
        return float(v)
    s = str(v).strip()
    if not s:
        return None
    s = re.sub(r"[^\d.,\-]", "", s)
    if not s or s in {"-", ".", ","}:
        return None
    # Formato AR: 1.234,56 -> 1234.56 ; 1,50 -> 1.50 ; 1234.56 -> 1234.56
    if "," in s and "." in s:
        if s.rfind(",") > s.rfind("."):
            s = s.replace(".", "").replace(",", ".")
        else:
            s = s.replace(",", "")
    elif "," in s:
        s = s.replace(",", ".")
    try:
        return float(s)
    except ValueError:
        return None


def cell(ws, r, c):
    return ws.cell(row=r, column=c).value


def txt(v):
    if v is None:
        return ""
    return str(v).replace("\xa0", " ").strip()


def clean_desc(s):
    """Compacta la descripción (colapsa saltos/espacios múltiples)."""
    s = (s or "").replace("\xa0", " ")
    s = re.sub(r"\n{2,}", "\n", s)
    s = re.sub(r"[ \t]{2,}", " ", s)
    return s.strip()


def guess_calibre(text):
    """Extrae un calibre del nombre/desc cuando la columna Calibre viene vacía."""
    t = (text or "").replace("\xa0", " ")
    m = re.search(
        r"(\.\d{2,3}(?:\s*(?:LR|Special|Win|Mag|ACP|SPRG|S&W|SW|WMR|Rem))?)",
        t, re.IGNORECASE)
    if m:
        return m.group(1).strip()
    m = re.search(r"\b(9\s*mm|5\.56|7\.62|12/70|20/76|\.?22\s*LR)\b", t, re.IGNORECASE)
    return m.group(1).strip() if m else ""


def arma_type(subcat):
    s = (subcat or "").upper()
    if "PISTOLA" in s or "REVOLVER" in s or "REVÓLVER" in s:
        return "arma_corta"
    return "arma_larga"


def rows_gral_taurus(wb, sheet, desc_col, price_lista_col):
    """Gral y Taurus. desc_col: columna descripción (5=E Gral, 6=F Taurus)."""
    ws = wb[sheet]
    out = []
    for r in range(3, ws.max_row + 1):
        sku = txt(cell(ws, r, 1))
        marca = txt(cell(ws, r, 2))
        nombre = txt(cell(ws, r, 3))
        if not sku and not nombre:
            continue
        calibre = txt(cell(ws, r, 4))
        descripcion = clean_desc(txt(cell(ws, r, desc_col)))
        subcat = txt(cell(ws, r, 7))
        stock = num(cell(ws, r, 8))
        efectivo_usd = num(cell(ws, r, 9))     # I
        pvp_tarjeta_usd = num(cell(ws, r, 10))  # J
        cuota3 = num(cell(ws, r, 11))           # K (ARS por cuota)
        cuota6 = num(cell(ws, r, 12))           # L
        cuota12 = num(cell(ws, r, 13))          # M
        if efectivo_usd is None:
            continue
        if not calibre:
            calibre = guess_calibre(nombre) or guess_calibre(descripcion)
        efectivo_ars = round(efectivo_usd * TC, 2)
        tarjeta_ars = round(pvp_tarjeta_usd * TC, 2) if pvp_tarjeta_usd else None
        out.append({
            "tipo": arma_type(subcat),
            "marca": marca or "Urban",
            "calibre": calibre,
            "modelo": nombre,
            "codigo": sku,
            "descripcion": descripcion or nombre,
            "precio_usd": round(efectivo_usd, 2),
            "stock": int(stock) if stock is not None else None,
            "stock_inicial": int(stock) if stock is not None else None,
            "efectivo_ars": efectivo_ars,
            "efectivo_usd": round(efectivo_usd, 2),
            "tarjeta_ars": tarjeta_ars,
            "cuota3_ars": cuota3,
            "cuota6_ars": cuota6,
            "cuota12_ars": cuota12,
        })
    return out


def rows_bersa(wb):
    ws = wb["BERSA"]
    out = []
    current_cal = ""
    current_model = ""
    current_desc = ""
    for r in range(1, ws.max_row + 1):
        a = txt(cell(ws, r, 1))
        d = txt(cell(ws, r, 4))
        e = txt(cell(ws, r, 5))
        f = txt(cell(ws, r, 6))
        h = num(cell(ws, r, 8))     # precio sugerido (ARS)
        b = clean_desc(txt(cell(ws, r, 2)))
        # Sección de calibre
        m = re.match(r"CALIBRE\s+(.+)", a, re.IGNORECASE)
        if m:
            current_cal = m.group(1).strip()
            continue
        # Header de modelo: A tiene nombre y la fila trae rótulos (ACABADO/CÓDIGO)
        is_header = (d.upper() == "ACABADO" or e.upper() == "ACABADO"
                     or txt(cell(ws, r, 7)).upper() == "PRECIO")
        if a and is_header:
            current_model = a.strip()
            continue
        # Fila de variante: tiene código (F) y precio numérico (H)
        if f and h is not None:
            acabado = d if d and d.upper() != "ACABADO" else e
            if b:
                current_desc = b
            efectivo_ars = num(cell(ws, r, 10))  # J
            cuota3 = num(cell(ws, r, 11))
            cuota6 = num(cell(ws, r, 12))
            cuota12 = num(cell(ws, r, 13))
            modelo = (current_model + (f" {acabado}" if acabado else "")).strip()
            out.append({
                "tipo": "arma_corta",
                "marca": "BERSA",
                "calibre": current_cal,
                "modelo": modelo or current_model,
                "codigo": f,
                "descripcion": current_desc or modelo,
                "precio_usd": 0,
                "stock": int(num(cell(ws, r, 9))) if num(cell(ws, r, 9)) is not None else None,
                "stock_inicial": int(num(cell(ws, r, 9))) if num(cell(ws, r, 9)) is not None else None,
                "efectivo_ars": efectivo_ars if efectivo_ars else round(h, 2),
                "efectivo_usd": None,
                "tarjeta_ars": round(h, 2),
                "cuota3_ars": cuota3,
                "cuota6_ars": cuota6,
                "cuota12_ars": cuota12,
            })
    return out


def parse_accesorio_name(name):
    """('cajas de 9 mm x 100 municiones') -> (calibre, rounds_per_box)."""
    n = name.lower().replace("\xa0", " ")
    rounds = None
    mr = re.search(r"x\s*(\d{1,4})", n)
    if mr:
        rounds = int(mr.group(1))
    cal = ""
    # Token de calibre justo antes de "x N" (ej "9 mm x 100", "308 x 50").
    mc = re.search(r"([0-9]+(?:[./][0-9]+)?\s*(?:mm|l\.?)?)\s*[xX]\s*\d", n)
    if mc:
        cal = mc.group(1).strip().rstrip(".")
    return cal, rounds


def rows_accesorios(wb):
    ws = wb["Accesorios"]
    out = []
    idx = 0
    for r in range(2, ws.max_row + 1):
        name = txt(cell(ws, r, 1))
        if not name:
            continue
        stock = num(cell(ws, r, 2))
        pvp = num(cell(ws, r, 4))
        if pvp is None:
            continue
        idx += 1
        calibre, rounds = parse_accesorio_name(name)
        out.append({
            "tipo": "municion",
            "marca": "Munición",
            "calibre": calibre,
            "modelo": "",
            "codigo": f"ACC-{idx:02d}",
            "descripcion": clean_desc(name),
            "precio_usd": 0,
            "stock": int(stock) if stock is not None else None,
            "stock_inicial": int(stock) if stock is not None else None,
            "efectivo_ars": round(pvp, 2),
            "efectivo_usd": None,
            "tarjeta_ars": round(pvp, 2),
            "cuota3_ars": None,
            "cuota6_ars": None,
            "cuota12_ars": None,
            "balas_por_caja": rounds,
        })
    return out


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else \
        "/Users/abritos/Downloads/Catalogo_Armas_Nuevas_Urban_con_Cantidad.xlsx"
    dst = sys.argv[2] if len(sys.argv) > 2 else \
        "/Users/abritos/Downloads/urban_catalog_clean.xlsx"

    wb = openpyxl.load_workbook(src, data_only=True)
    products = []
    products += rows_gral_taurus(wb, "Gral", desc_col=5, price_lista_col=6)
    products += rows_gral_taurus(wb, "Taurus", desc_col=6, price_lista_col=5)
    products += rows_bersa(wb)
    products += rows_accesorios(wb)

    # Encabezados: canónicos + balas_por_caja (munición).
    headers = OUT_HEADERS + ["balas_por_caja"]

    out = openpyxl.Workbook()
    ws = out.active
    ws.title = "Catalogo"
    ws.append(headers)
    for p in products:
        ws.append([p.get(h) for h in headers])
    out.save(dst)

    # Resumen
    from collections import Counter
    by_type = Counter(p["tipo"] for p in products)
    by_marca = Counter(p["marca"] for p in products)
    print(f"OK -> {dst}")
    print(f"Total productos: {len(products)}")
    print("Por tipo:", dict(by_type))
    print("Marcas:", len(by_marca))
    # muestra
    print("\nEjemplos:")
    for p in products[:2] + products[-3:]:
        print(f"  [{p['tipo']}] {p['marca']} {p['modelo']} ({p['codigo']}) "
              f"cal={p['calibre']} stock={p['stock']} "
              f"efvo_ars={p['efectivo_ars']} usd={p['efectivo_usd']} "
              f"tarj={p['tarjeta_ars']} c3={p['cuota3_ars']}")


if __name__ == "__main__":
    main()
