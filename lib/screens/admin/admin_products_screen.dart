import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../services/catalog_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/filter_buttons.dart';
import '../../widgets/feria_shell.dart';
import 'admin_product_edit_screen.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  ProductType? _typeFilter;
  String? _marcaFilter;

  List<Product> _filteredProducts(CatalogService catalog) {
    final source = _typeFilter == null
        ? catalog.products
        : catalog.byType(_typeFilter!);

    var products = source.where((product) {
      if (_marcaFilter == null) return true;
      return product.marca.toLowerCase() == _marcaFilter!.toLowerCase();
    }).toList();

    products.sort((a, b) {
      final marca = a.marca.toLowerCase().compareTo(b.marca.toLowerCase());
      if (marca != 0) return marca;

      if (a.isArma && b.isArma) {
        return a.modeloDisplay.toLowerCase().compareTo(
              b.modeloDisplay.toLowerCase(),
            );
      }

      return a.codigo.compareTo(b.codigo);
    });

    return products;
  }

  List<String> _brandsForFilter(CatalogService catalog) {
    final source = _typeFilter == null
        ? catalog.products
        : catalog.byType(_typeFilter!);
    final brands = source.map((product) => product.marca).toSet().toList();
    brands.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return brands;
  }

  void _setTypeFilter(ProductType? type) {
    setState(() {
      _typeFilter = type;
      _marcaFilter = null;
    });
  }

  void _toggleMarca(String marca) {
    setState(() {
      _marcaFilter = _marcaFilter == marca ? null : marca;
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogService>();
    final products = _filteredProducts(catalog);
    final brands = _brandsForFilter(catalog);

    return FeriaScaffold(
      appBar: FeriaAppBar(
        title: const Text('Productos y stock'),
        actions: [
          if (_marcaFilter != null || _typeFilter != null)
            TextButton(
              onPressed: () => setState(() {
                _typeFilter = null;
                _marcaFilter = null;
              }),
              child: const Text(
                'VER TODOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(
            child: Row(
              children: [
                _TypeChip(
                  label: 'TODOS',
                  selected: _typeFilter == null,
                  onTap: () => _setTypeFilter(null),
                ),
                _TypeChip(
                  label: 'CORTAS',
                  selected: _typeFilter == ProductType.armaCorta,
                  onTap: () => _setTypeFilter(ProductType.armaCorta),
                ),
                _TypeChip(
                  label: 'LARGAS',
                  selected: _typeFilter == ProductType.armaLarga,
                  onTap: () => _setTypeFilter(ProductType.armaLarga),
                ),
                _TypeChip(
                  label: 'MUNICIÓN',
                  selected: _typeFilter == ProductType.municion,
                  onTap: () => _setTypeFilter(ProductType.municion),
                ),
              ],
            ),
          ),
          _FilterBar(
            label: 'MARCA',
            child: brands.isEmpty
                ? const Text('Sin marcas')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: brands.map((marca) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChipButton(
                            compact: true,
                            label: marca.toUpperCase(),
                            selected: _marcaFilter == marca,
                            onTap: () => _toggleMarca(marca),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              '${products.length} producto${products.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Text(
                      'Ningún producto con esos filtros',
                      style: TextStyle(fontSize: 18),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _ProductAdminTile(product: products[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.child,
    this.label,
  });

  final Widget child;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: label == null
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            )
          : Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    label!,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.textPrimary,
        ),
        selectedColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
    );
  }
}

class _ProductAdminTile extends StatelessWidget {
  const _ProductAdminTile({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final stockLabel = product.stock == null
        ? 'Sin stock'
        : product.stock! <= 0
            ? 'SIN STOCK'
            : 'Stock: ${product.stock}';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminProductEditScreen(productId: product.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.marcaUpper,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (product.isArma) ...[
                      _DetailLine(
                        label: 'MODELO',
                        value: product.modeloDisplay,
                      ),
                      const SizedBox(height: 4),
                      _DetailLine(label: 'CALIBRE', value: product.calibre),
                    ] else ...[
                      _DetailLine(label: 'CÓDIGO', value: product.codigo),
                      const SizedBox(height: 4),
                      _DetailLine(label: 'CALIBRE', value: product.calibre),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      formatUsd(product.precioUsd),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (product.stock != null && product.stock! <= 0
                              ? const Color(0xFFB42318)
                              : AppColors.accent)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      stockLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: product.stock != null && product.stock! <= 0
                            ? const Color(0xFFB42318)
                            : AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Icon(Icons.edit, color: AppColors.primary, size: 28),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 17, color: AppColors.textPrimary),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
