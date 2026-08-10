import 'product_prices.dart';

enum ProductType {
  municion('municion', 'Munición'),
  armaCorta('arma_corta', 'Armas cortas'),
  armaLarga('arma_larga', 'Armas largas'),
  accesorios('accesorios', 'Accesorios');

  const ProductType(this.key, this.label);

  final String key;
  final String label;

  /// Resuelve el tipo desde su clave. Si la clave es desconocida (p. ej. una
  /// app vieja lee un tipo agregado después), NO crashea: cae en [municion],
  /// el bucket genérico no-arma. Así un cliente desactualizado sigue mostrando
  /// y vendiendo el producto en lugar de romper toda la pantalla.
  static ProductType fromKey(String key) {
    return ProductType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => ProductType.municion,
    );
  }
}

class Product {
  const Product({
    required this.id,
    required this.type,
    required this.marca,
    required this.calibre,
    required this.codigo,
    required this.precioUsd,
    this.modelo = '',
    this.descripcion = '',
    this.foto = '',
    this.fotoUrls = const [],
    this.stock,
    this.stockInicial,
    this.roundsPerBox,
    this.fixedPrices,
  });

  final String id;
  final ProductType type;
  final String marca;
  final String calibre;
  final String codigo;
  final String modelo;

  /// Descripción interna libre (munición: calibre, grains, modelo, etc.).
  final String descripcion;
  final double precioUsd;
  final String foto;

  /// Rutas en Storage, ej. `arma_corta/ac-001/1734567890.jpg`
  final List<String> fotoUrls;

  /// Saldo actual en unidades vendibles: armas/accesorios = unidades, munición
  /// = cajas.
  final int? stock;

  /// Saldo inicial (misma unidad que [stock]). Se fija en la primera carga.
  final int? stockInicial;

  /// Balas por caja (CAJA X). Solo munición; null/0 en armas.
  final int? roundsPerBox;

  /// Precios cargados tal cual desde el Excel (Urban Tactical). Cuando no es
  /// null, la app muestra estos montos y NO recalcula nada para este producto.
  final FixedPrices? fixedPrices;

  /// True cuando el producto trae precios fijos del Excel (sin cálculo interno).
  bool get hasFixedPrices => fixedPrices != null;

  String get marcaUpper => marca.toUpperCase();

  bool get isArma =>
      type == ProductType.armaCorta || type == ProductType.armaLarga;

  bool get isMunicion => type == ProductType.municion;

  bool get isAccesorios => type == ProductType.accesorios;

  String get modeloDisplay => modelo.isNotEmpty ? modelo : codigo;

  /// Texto para que el vendedor identifique el ítem en carrito / venta.
  String get cartDisplayDescription {
    if (descripcion.trim().isNotEmpty) return descripcion.trim();
    if (isArma) {
      final parts = <String>[modeloDisplay];
      if (calibre.isNotEmpty) parts.add('Cal. $calibre');
      return parts.join(' · ');
    }
    return codigo;
  }

  /// Código corto secundario en carrito (munición).
  String get cartDisplayCode =>
      isMunicion && codigo.isNotEmpty ? codigo : '';

  /// Unidad al elegir cantidad en carrito.
  String get cartQuantityUnit => isMunicion ? 'cajas' : 'unidades';

  /// Nombre corto para identificar rápido en catálogo / carrito.
  /// Ej: "Varmit V-Max" en lugar del texto CCI completo.
  String get sellerShortTitle {
    if (isArma) {
      return modelo.isNotEmpty ? modelo : modeloDisplay;
    }
    if (descripcion.trim().isEmpty) {
      return [
        if (calibre.isNotEmpty) calibre,
        if (granos.isNotEmpty) granos,
      ].join(' · ');
    }
    final parsed = _extractSellerShortTitle(descripcion);
    return parsed.isNotEmpty ? parsed : descripcion.trim();
  }

  /// Chips visuales para escaneo rápido (calibre, grains, caja, modelo).
  List<String> get sellerTagLabels {
    if (isArma) {
      return [
        if (calibre.isNotEmpty) calibre,
      ];
    }

    final tags = <String>[];
    void add(String value) {
      final v = value.trim();
      if (v.isEmpty) return;
      if (!tags.any((t) => t.toLowerCase() == v.toLowerCase())) {
        tags.add(v);
      }
    }

    add(calibre);
    add(granos);
    if (roundsPerBox != null && roundsPerBox! > 0) {
      add('$roundsPerBox/caja');
    }
    add(modelo);
    return tags;
  }

  static String _extractSellerShortTitle(String raw) {
    var text = raw.toUpperCase().replaceAll('\u00a0', ' ');
    text = text.replaceAll(RegExp(r'C\.?\s*\d{1,3}(?:\.\d{1,3})?\s*'), '');
    text = text.replaceAll(RegExp(r'\b\d{2,3}\s*G(R)?\b'), '');
    text = text.replaceAll(RegExp(r'\b\d{3,4}\s*FPS\b'), '');
    text = text.replaceAll(RegExp(r'\bLR\b'), '');
    text = text.replaceAll(RegExp(r'\bWMG\b'), '');
    text = text.replaceAll(RegExp(r'\bM\.\s*[A-Z0-9]+\b'), '');
    text = text.replaceAll(RegExp(r'\(\d+\)'), '');
    text = text.replaceAll(RegExp(r'\bCCI\b'), '');
    text = text.replaceAll(RegExp(r'[/\\]+'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (text.isEmpty) return '';

    return text
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(_titleCaseToken)
        .join(' ');
  }

  static String _titleCaseToken(String token) {
    if (token.isEmpty) return token;
    if (token.contains('-')) {
      return token
          .split('-')
          .where((part) => part.isNotEmpty)
          .map(_titleCaseToken)
          .join('-');
    }
    return token[0] + token.substring(1).toLowerCase();
  }

  /// Peso de la punta (grains) para munición. Se deriva de la descripción
  /// estilo CCI ("C.22 40G LR...") -> "40 gr". Vacío si no se detecta.
  String get granos {
    if (!isMunicion || descripcion.isEmpty) return '';
    final match =
        RegExp(r'\b(\d{2,3})\s*GR?\b', caseSensitive: false).firstMatch(descripcion);
    return match != null ? '${match.group(1)} gr' : '';
  }

  bool get hasNetworkPhoto => fotoUrls.isNotEmpty;

  bool get hasLocalPhoto => foto.isNotEmpty;

  bool get inStock => stock == null || stock! > 0;

  /// Cajas disponibles (munición). Para munición = [stock].
  int? get cajasDisponibles => isMunicion ? stock : null;

  /// Balas totales derivadas: cajas × balas por caja (munición).
  int? get balasDisponibles {
    if (!isMunicion || stock == null || roundsPerBox == null) return null;
    return stock! * roundsPerBox!;
  }

  /// Balas iniciales derivadas (munición).
  int? get balasIniciales {
    if (!isMunicion || stockInicial == null || roundsPerBox == null) return null;
    return stockInicial! * roundsPerBox!;
  }

  /// Unidades vendidas = inicial − actual (cajas para munición, unidades para armas).
  int? get unidadesVendidas {
    if (stockInicial == null || stock == null) return null;
    final sold = stockInicial! - stock!;
    return sold < 0 ? 0 : sold;
  }

  /// Balas vendidas derivadas (munición).
  int? get balasVendidas {
    if (!isMunicion || unidadesVendidas == null || roundsPerBox == null) {
      return null;
    }
    return unidadesVendidas! * roundsPerBox!;
  }

  Product copyWith({
    String? id,
    ProductType? type,
    String? marca,
    String? calibre,
    String? codigo,
    String? modelo,
    String? descripcion,
    double? precioUsd,
    String? foto,
    List<String>? fotoUrls,
    int? stock,
    int? stockInicial,
    int? roundsPerBox,
    FixedPrices? fixedPrices,
  }) {
    return Product(
      id: id ?? this.id,
      type: type ?? this.type,
      marca: marca ?? this.marca,
      calibre: calibre ?? this.calibre,
      codigo: codigo ?? this.codigo,
      modelo: modelo ?? this.modelo,
      descripcion: descripcion ?? this.descripcion,
      precioUsd: precioUsd ?? this.precioUsd,
      foto: foto ?? this.foto,
      fotoUrls: fotoUrls ?? this.fotoUrls,
      stock: stock ?? this.stock,
      stockInicial: stockInicial ?? this.stockInicial,
      roundsPerBox: roundsPerBox ?? this.roundsPerBox,
      fixedPrices: fixedPrices ?? this.fixedPrices,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final fotoUrls = _fotoUrlsFromJson(json);

    return Product(
      id: json['id'] as String,
      type: ProductType.fromKey(json['type'] as String),
      marca: json['marca'] as String,
      calibre: json['calibre'] as String,
      codigo: json['codigo'] as String,
      modelo: json['modelo'] as String? ?? '',
      descripcion: json['descripcion'] as String? ?? '',
      precioUsd: (json['precioUsd'] as num).toDouble(),
      foto: json['foto'] as String? ?? '',
      fotoUrls: fotoUrls,
      stock: json['stock'] as int?,
      stockInicial: json['stockInicial'] as int?,
      roundsPerBox: json['roundsPerBox'] as int?,
      fixedPrices: FixedPrices.fromJson(
        (json['fixedPrices'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }

  static List<String> _fotoUrlsFromJson(Map<String, dynamic> json) {
    final list = <String>[];
    final rawList = json['fotoUrls'];
    if (rawList is List) {
      for (final item in rawList) {
        if (item is String && item.trim().isNotEmpty) {
          list.add(item.trim());
        }
      }
    }

    final legacy = json['fotoUrl'] as String? ?? '';
    if (legacy.trim().isNotEmpty && !list.contains(legacy.trim())) {
      list.insert(0, legacy.trim());
    }

    return list;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.key,
      'marca': marca,
      'calibre': calibre,
      'codigo': codigo,
      if (modelo.isNotEmpty) 'modelo': modelo,
      if (descripcion.isNotEmpty) 'descripcion': descripcion,
      'precioUsd': precioUsd,
      if (foto.isNotEmpty) 'foto': foto,
      if (fotoUrls.isNotEmpty) 'fotoUrls': fotoUrls,
      if (stock != null) 'stock': stock,
      if (stockInicial != null) 'stockInicial': stockInicial,
      if (roundsPerBox != null) 'roundsPerBox': roundsPerBox,
      if (fixedPrices != null) 'fixedPrices': fixedPrices!.toJson(),
    };
  }
}
