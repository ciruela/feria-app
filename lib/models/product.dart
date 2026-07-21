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
    this.foto = '',
    this.fotoUrl = '',
    this.stock,
  });

  final String id;
  final ProductType type;
  final String marca;
  final String calibre;
  final String codigo;
  final String modelo;
  final double precioUsd;
  final String foto;
  final String fotoUrl;
  final int? stock;

  String get marcaUpper => marca.toUpperCase();

  bool get isArma =>
      type == ProductType.armaCorta || type == ProductType.armaLarga;

  bool get isMunicion => type == ProductType.municion;

  String get modeloDisplay => modelo.isNotEmpty ? modelo : codigo;

  bool get hasNetworkPhoto => fotoUrl.isNotEmpty;

  bool get hasLocalPhoto => foto.isNotEmpty;

  bool get inStock => stock == null || stock! > 0;

  Product copyWith({
    String? id,
    ProductType? type,
    String? marca,
    String? calibre,
    String? codigo,
    String? modelo,
    double? precioUsd,
    String? foto,
    String? fotoUrl,
    int? stock,
  }) {
    return Product(
      id: id ?? this.id,
      type: type ?? this.type,
      marca: marca ?? this.marca,
      calibre: calibre ?? this.calibre,
      codigo: codigo ?? this.codigo,
      modelo: modelo ?? this.modelo,
      precioUsd: precioUsd ?? this.precioUsd,
      foto: foto ?? this.foto,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      stock: stock ?? this.stock,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      type: ProductType.fromKey(json['type'] as String),
      marca: json['marca'] as String,
      calibre: json['calibre'] as String,
      codigo: json['codigo'] as String,
      modelo: json['modelo'] as String? ?? '',
      precioUsd: (json['precioUsd'] as num).toDouble(),
      foto: json['foto'] as String? ?? '',
      fotoUrl: json['fotoUrl'] as String? ?? '',
      stock: json['stock'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.key,
      'marca': marca,
      'calibre': calibre,
      'codigo': codigo,
      if (modelo.isNotEmpty) 'modelo': modelo,
      'precioUsd': precioUsd,
      if (foto.isNotEmpty) 'foto': foto,
      if (fotoUrl.isNotEmpty) 'fotoUrl': fotoUrl,
      if (stock != null) 'stock': stock,
    };
  }
}
