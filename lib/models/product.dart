enum ProductType {
  municion('municion', 'Munición'),
  armaCorta('arma_corta', 'Armas cortas'),
  armaLarga('arma_larga', 'Armas largas');

  const ProductType(this.key, this.label);

  final String key;
  final String label;

  static ProductType fromKey(String key) {
    return ProductType.values.firstWhere((type) => type.key == key);
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

  /// Saldo actual en unidades vendibles: armas = unidades, munición = cajas.
  final int? stock;

  /// Saldo inicial (misma unidad que [stock]). Se fija en la primera carga.
  final int? stockInicial;

  /// Balas por caja (CAJA X). Solo munición; null/0 en armas.
  final int? roundsPerBox;

  String get marcaUpper => marca.toUpperCase();

  bool get isArma =>
      type == ProductType.armaCorta || type == ProductType.armaLarga;

  bool get isMunicion => type == ProductType.municion;

  String get modeloDisplay => modelo.isNotEmpty ? modelo : codigo;

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
    };
  }
}
