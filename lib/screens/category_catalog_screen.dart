import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../services/catalog_service.dart';
import '../services/cart_service.dart';
import '../theme/app_theme.dart';
import '../widgets/feria_shell.dart';
import '../widgets/filter_buttons.dart';
import '../widgets/product_card.dart';
import '../widgets/quick_nav_bar.dart';
import '../widgets/section_header.dart';
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

    return FeriaScaffold(
      appBar: FeriaAppBar(
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
                  fontSize: 15,
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
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Ningún producto con esos filtros',
                    subtitle: 'Tocá VER TODOS para volver al catálogo completo',
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      // Altura fija por tarjeta para que el panel de precios/cuotas
                      // no quede recortado en tablet (GridView con aspect ratio bajo).
                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 500,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 920,
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
        ),
        boxShadow: [AppDecorations.softShadow],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppDecorations.goldGradient,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$productCount producto${productCount == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Filtrá tocando los botones',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
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
          width: 118,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
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
