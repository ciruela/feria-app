import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/catalog_service.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../widgets/filter_buttons.dart';
import '../widgets/product_card.dart';
import '../widgets/quick_nav_bar.dart';
import 'cart_screen.dart';

class CategoryCatalogScreen extends StatefulWidget {
  const CategoryCatalogScreen({
    super.key,
    required this.type,
  });

  final ProductType type;

  @override
  State<CategoryCatalogScreen> createState() => _CategoryCatalogScreenState();
}

class _CategoryCatalogScreenState extends State<CategoryCatalogScreen> {
  String? _marca;
  String? _calibre;
  String? _marcaLetter;
  String? _codigoLetter;

  bool get _hasFilters =>
      _marca != null ||
      _calibre != null ||
      _marcaLetter != null ||
      _codigoLetter != null;

  void _clearFilters() {
    setState(() {
      _marca = null;
      _calibre = null;
      _marcaLetter = null;
      _codigoLetter = null;
    });
  }

  void _toggleMarca(String marca) {
    setState(() => _marca = _marca == marca ? null : marca);
  }

  void _toggleCalibre(String calibre) {
    setState(() => _calibre = _calibre == calibre ? null : calibre);
  }

  void _toggleMarcaLetter(String letter) {
    setState(() => _marcaLetter = _marcaLetter == letter ? null : letter);
  }

  void _toggleCodigoLetter(String letter) {
    setState(() => _codigoLetter = _codigoLetter == letter ? null : letter);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogService>();
    final type = widget.type;
    final brands = catalog.brandsFor(type);
    final calibers = catalog.calibersFor(type);
    final marcaLetters = catalog.usedLettersForMarca(type);
    final codigoLetters = catalog.usedLettersForCodigo(type);

    final products = catalog.filtered(
      type: type,
      marca: _marca,
      calibre: _calibre,
      marcaLetter: _marcaLetter,
      codigoLetter: _codigoLetter,
    );
    final cartCount = context.watch<CartService>().itemCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type.label),
        actions: [
          if (_hasFilters)
            TextButton(
              onPressed: _clearFilters,
              child: const Text(
                'VER TODOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterPanel(
            productCount: products.length,
            showCodigoFilter: type == ProductType.municion,
            brands: brands,
            calibers: calibers,
            marcaLetters: marcaLetters,
            codigoLetters: codigoLetters,
            selectedMarca: _marca,
            selectedCalibre: _calibre,
            selectedMarcaLetter: _marcaLetter,
            selectedCodigoLetter: _codigoLetter,
            onMarcaTap: _toggleMarca,
            onCalibreTap: _toggleCalibre,
            onMarcaLetterTap: _toggleMarcaLetter,
            onCodigoLetterTap: _toggleCodigoLetter,
          ),
          Expanded(
            child: products.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Ningún producto con esos filtros.\nTocá VER TODOS para volver.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 700;
                      final crossAxisCount = isWide ? 3 : 1;

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: isWide ? 0.52 : 0.42,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          return ProductCard(product: products[index]);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: QuickNavBar(
        cartCount: cartCount,
        onCartTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CartScreen()),
          );
        },
      ),
    );
  }
}

class _FilterPanel extends StatelessWidget {
  const _FilterPanel({
    required this.productCount,
    required this.showCodigoFilter,
    required this.brands,
    required this.calibers,
    required this.marcaLetters,
    required this.codigoLetters,
    required this.selectedMarca,
    required this.selectedCalibre,
    required this.selectedMarcaLetter,
    required this.selectedCodigoLetter,
    required this.onMarcaTap,
    required this.onCalibreTap,
    required this.onMarcaLetterTap,
    required this.onCodigoLetterTap,
  });

  final int productCount;
  final bool showCodigoFilter;
  final List<String> brands;
  final List<String> calibers;
  final Set<String> marcaLetters;
  final Set<String> codigoLetters;
  final String? selectedMarca;
  final String? selectedCalibre;
  final String? selectedMarcaLetter;
  final String? selectedCodigoLetter;
  final ValueChanged<String> onMarcaTap;
  final ValueChanged<String> onCalibreTap;
  final ValueChanged<String> onMarcaLetterTap;
  final ValueChanged<String> onCodigoLetterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 2),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$productCount producto${productCount == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            _FilterRow(
              label: 'MARCA',
              child: _HorizontalChips(
                items: brands,
                selected: selectedMarca,
                onTap: onMarcaTap,
                labelBuilder: (value) => value.toUpperCase(),
              ),
            ),
            const SizedBox(height: 8),
            _FilterRow(
              label: 'CALIBRE',
              child: _HorizontalChips(
                items: calibers,
                selected: selectedCalibre,
                onTap: onCalibreTap,
                labelBuilder: (value) => value.toUpperCase(),
              ),
            ),
            const SizedBox(height: 8),
            _FilterRow(
              label: 'LETRA MARCA',
              child: _HorizontalLetters(
                letters: marcaLetters,
                selected: selectedMarcaLetter,
                onTap: onMarcaLetterTap,
              ),
            ),
            const SizedBox(height: 8),
            if (showCodigoFilter) ...[
              _FilterRow(
                label: 'LETRA CÓDIGO',
                child: _HorizontalLetters(
                  letters: codigoLetters,
                  selected: selectedCodigoLetter,
                  onTap: onCodigoLetterTap,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _HorizontalChips extends StatelessWidget {
  const _HorizontalChips({
    required this.items,
    required this.selected,
    required this.onTap,
    required this.labelBuilder,
  });

  final List<String> items;
  final String? selected;
  final ValueChanged<String> onTap;
  final String Function(String) labelBuilder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected =
              selected != null && selected!.toLowerCase() == item.toLowerCase();

          return FilterChipButton(
            compact: true,
            label: labelBuilder(item),
            selected: isSelected,
            onTap: () => onTap(item),
          );
        },
      ),
    );
  }
}

class _HorizontalLetters extends StatelessWidget {
  const _HorizontalLetters({
    required this.letters,
    required this.selected,
    required this.onTap,
  });

  final Set<String> letters;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: alphabet.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final letter = alphabet[index];
          final enabled = letters.contains(letter);

          return LetterChip(
            letter: letter,
            enabled: enabled,
            selected: selected == letter,
            onTap: () => onTap(letter),
          );
        },
      ),
    );
  }
}
