import 'package:app_feria/models/product.dart';

Product testProduct({
  String id = 'test-001',
  ProductType type = ProductType.municion,
  String marca = 'TEST',
  String calibre = '9MM',
  String codigo = 'M001',
  String modelo = '',
  String descripcion = '',
  double precioUsd = 100,
  int? stock,
}) {
  return Product(
    id: id,
    type: type,
    marca: marca,
    calibre: calibre,
    codigo: codigo,
    modelo: modelo,
    descripcion: descripcion,
    precioUsd: precioUsd,
    stock: stock,
  );
}
