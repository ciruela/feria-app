import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';

class AdminProductEditScreen extends StatefulWidget {
  const AdminProductEditScreen({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  State<AdminProductEditScreen> createState() => _AdminProductEditScreenState();
}

class _AdminProductEditScreenState extends State<AdminProductEditScreen> {
  late final TextEditingController _precioController;
  late final TextEditingController _stockController;
  late final TextEditingController _fotoUrlController;
  late final TextEditingController _modeloController;
  Product? _product;

  @override
  void initState() {
    super.initState();
    _product = context.read<CatalogService>().productById(widget.productId);
    _precioController = TextEditingController(
      text: _product?.precioUsd.toString() ?? '',
    );
    _stockController = TextEditingController(
      text: _product?.stock?.toString() ?? '',
    );
    _fotoUrlController = TextEditingController(
      text: _product?.fotoUrl ?? '',
    );
    _modeloController = TextEditingController(
      text: _product?.modelo ?? '',
    );
  }

  @override
  void dispose() {
    _precioController.dispose();
    _stockController.dispose();
    _fotoUrlController.dispose();
    _modeloController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;

    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Producto')),
        body: const Center(child: Text('Producto no encontrado')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(product.isArma ? product.modeloDisplay : product.codigo),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ReadOnlyField(label: 'Marca', value: product.marca),
          const SizedBox(height: 12),
          if (product.isArma) ...[
            TextField(
              controller: _modeloController,
              decoration: const InputDecoration(
                labelText: 'Modelo',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ] else
            _ReadOnlyField(label: 'Código', value: product.codigo),
          const SizedBox(height: 12),
          _ReadOnlyField(label: 'Calibre', value: product.calibre),
          const SizedBox(height: 12),
          if (product.isArma)
            _ReadOnlyField(label: 'Ref. interna', value: product.codigo),
          if (product.isArma) const SizedBox(height: 12),
          _ReadOnlyField(label: 'Tipo', value: product.type.label),
          const SizedBox(height: 24),
          TextField(
            controller: _precioController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio USD',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _stockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Stock (vacío = no mostrar)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _fotoUrlController,
            decoration: const InputDecoration(
              labelText: 'URL foto en la nube',
              hintText: 'https://.../producto.jpg',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _save(context, product),
            child: const Text('GUARDAR CAMBIOS'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, Product product) async {
    final precio = double.tryParse(
      _precioController.text.replaceAll(',', '.'),
    );
    if (precio == null || precio < 0) {
      _showError(context, 'Precio USD inválido');
      return;
    }

    int? stock;
    if (_stockController.text.trim().isNotEmpty) {
      stock = int.tryParse(_stockController.text.trim());
      if (stock == null || stock < 0) {
        _showError(context, 'Stock inválido');
        return;
      }
    }

    final updated = product.copyWith(
      precioUsd: precio,
      stock: stock,
      fotoUrl: _fotoUrlController.text.trim(),
      modelo: product.isArma ? _modeloController.text.trim() : product.modelo,
    );

    await context.read<CatalogService>().updateProduct(updated);

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Producto actualizado')),
    );
    Navigator.of(context).pop();
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
