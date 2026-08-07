import 'product.dart';

/// Pasa a mayúsculas y quita acentos comunes del español
/// (Á→A, É→E, Í→I, Ó→O, Ú→U, Ü→U, Ñ→N).
String normalizar(String input) {
  var s = input.toUpperCase();
  _acentos.forEach((from, to) => s = s.replaceAll(from, to));
  return s;
}

/// [normalizar] y además elimina todo lo que no sea `[A-Z0-9]`.
///
/// Así `.308 win` → `308WIN`, `30-06 SPRG` → `3006SPRG`, `9 mm` → `9MM`.
String compactar(String input) =>
    normalizar(input).replaceAll(_noAlfanumerico, '');

final RegExp _noAlfanumerico = RegExp('[^A-Z0-9]');

const Map<String, String> _acentos = {
  'Á': 'A',
  'À': 'A',
  'Ä': 'A',
  'Â': 'A',
  'É': 'E',
  'È': 'E',
  'Ë': 'E',
  'Ê': 'E',
  'Í': 'I',
  'Ì': 'I',
  'Ï': 'I',
  'Î': 'I',
  'Ó': 'O',
  'Ò': 'O',
  'Ö': 'O',
  'Ô': 'O',
  'Ú': 'U',
  'Ù': 'U',
  'Ü': 'U',
  'Û': 'U',
  'Ñ': 'N',
};

/// Sinónimos de calibre para cruzar las distintas grafías del mercado.
///
/// Las claves y valores están ya en forma compacta (mayúsculas, sin símbolos).
const Map<String, List<String>> kCalibreSinonimos = <String, List<String>>{
  '9MM': ['9X19', '9PARA', '9LUGER'],
  '9X19': ['9MM'],
  '308': ['762X51'],
  '223': ['556', '556X45'],
  '3006': ['762X63'],
  '38SPECIAL': ['38SPL'],
};

/// Índice de búsqueda precalculado por producto.
///
/// Se computa **una sola vez por producto** (cacheado en `CatalogService`) para
/// no rehacer los `toUpperCase()`/normalizaciones en cada tecla.
class ProductSearchIndex {
  const ProductSearchIndex({
    required this.principal,
    required this.compacto,
    required this.descripcion,
    required this.descripcionCompacta,
  });

  /// `codigo marca modeloDisplay calibre` normalizado (con espacios).
  final String principal;

  /// `codigo marca modeloDisplay calibre` compactado (solo `[A-Z0-9]`).
  final String compacto;

  /// Descripción normalizada (con espacios).
  final String descripcion;

  /// Descripción compactada (solo `[A-Z0-9]`).
  final String descripcionCompacta;

  factory ProductSearchIndex.fromProduct(Product p) {
    final base = '${p.codigo} ${p.marca} ${p.modeloDisplay} ${p.calibre}';
    return ProductSearchIndex(
      principal: normalizar(base),
      compacto: compactar(base),
      descripcion: normalizar(p.descripcion),
      descripcionCompacta: compactar(p.descripcion),
    );
  }
}

/// Busca [query] en [source] usando índices precalculados vía [indexOf].
///
/// Algoritmo:
/// 1. Parte la consulta en palabras y compacta cada una; descarta las vacías.
///    Si no queda ninguna, devuelve todo (ordenado).
/// 2. Pasada fuerte: un producto califica si TODAS las palabras aparecen en
///    `principal` o `compacto` (probando también los sinónimos de calibre).
///    Suma 100 puntos por palabra.
/// 3. Ordena por puntaje desc; a igual puntaje, orden actual (marca, luego
///    modelo o código).
/// 4. Respaldo: SOLO si la pasada fuerte da exactamente cero, repite buscando
///    también en la descripción (cubre `holosun`, `picatinny`, etc.).
///
/// Los filtros de tipo/marca/calibre deben aplicarse ANTES, sobre [source].
List<Product> searchCatalog(
  Iterable<Product> source,
  String query,
  ProductSearchIndex Function(Product) indexOf,
) {
  final words = query
      .split(RegExp(r'\s+'))
      .map(compactar)
      .where((w) => w.isNotEmpty)
      .toList(growable: false);

  final products = source.toList();

  if (words.isEmpty) {
    products.sort(_compareDefault);
    return products;
  }

  final strong = _scorePass(products, words, indexOf, includeDescripcion: false);
  if (strong.isNotEmpty) return _ordered(strong);

  // Respaldo por descripción SOLO cuando la pasada fuerte no encontró nada.
  final backup = _scorePass(products, words, indexOf, includeDescripcion: true);
  return _ordered(backup);
}

List<_ScoredProduct> _scorePass(
  List<Product> products,
  List<String> words,
  ProductSearchIndex Function(Product) indexOf, {
  required bool includeDescripcion,
}) {
  final matched = <_ScoredProduct>[];
  for (final product in products) {
    final index = indexOf(product);
    var score = 0;
    var allFound = true;
    for (final word in words) {
      final inPrincipal = _wordMatches(word, index.principal, index.compacto);
      final found = inPrincipal ||
          (includeDescripcion &&
              _wordMatches(
                word,
                index.descripcion,
                index.descripcionCompacta,
              ));
      if (found) {
        score += 100;
      } else {
        allFound = false;
        break;
      }
    }
    if (allFound) matched.add(_ScoredProduct(product, score));
  }
  return matched;
}

/// La palabra (o alguno de sus sinónimos) aparece como substring en el texto
/// normalizado o en el compactado.
bool _wordMatches(String word, String normalized, String compacted) {
  if (compacted.contains(word) || normalized.contains(word)) return true;
  final sinonimos = kCalibreSinonimos[word];
  if (sinonimos != null) {
    for (final syn in sinonimos) {
      if (compacted.contains(syn) || normalized.contains(syn)) return true;
    }
  }
  return false;
}

List<Product> _ordered(List<_ScoredProduct> scored) {
  scored.sort((a, b) {
    if (a.score != b.score) return b.score.compareTo(a.score);
    return _compareDefault(a.product, b.product);
  });
  return scored.map((e) => e.product).toList();
}

/// Orden estable actual: marca, luego modelo (armas) o código.
int _compareDefault(Product a, Product b) {
  final byMarca = a.marca.toLowerCase().compareTo(b.marca.toLowerCase());
  if (byMarca != 0) return byMarca;
  if (a.isArma) {
    return a.modeloDisplay.toLowerCase().compareTo(b.modeloDisplay.toLowerCase());
  }
  return a.codigo.compareTo(b.codigo);
}

class _ScoredProduct {
  const _ScoredProduct(this.product, this.score);
  final Product product;
  final int score;
}
