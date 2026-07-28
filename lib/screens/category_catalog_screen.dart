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

  bool get hasActiveFilters =>
      _marca != null ||
      _calibre != null ||
      _marcaLetter != null ||
      _codigoLetter != null;

  int get _activeFilterCount => [
        _marca,
        _calibre,
        _marcaLetter,
        _codigoLetter,
      ].where((value) => value != null).length;

  void clearFilters() {
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

  Future<void> _openFilterSheet({
    required int productCount,
    required List<String> brands,
    required List<String> calibers,
    required Set<String> marcaLetters,
    required Set<String> codigoLetters,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return _FilterSheetContent(
              scrollController: scrollController,
              productCount: productCount,
              showCodigoFilter: widget.type == ProductType.municion,
              brands: brands,
              calibers: calibers,
              marcaLetters: marcaLetters,
              codigoLetters: codigoLetters,
              selectedMarca: _marca,
              selectedCalibre: _calibre,
              selectedMarcaLetter: _marcaLetter,
              selectedCodigoLetter: _codigoLetter,
              onMarcaTap: (marca) {
                _toggleMarca(marca);
                Navigator.pop(sheetContext);
              },
              onCalibreTap: (calibre) {
                _toggleCalibre(calibre);
                Navigator.pop(sheetContext);
              },
              onMarcaLetterTap: (letter) {
                _toggleMarcaLetter(letter);
                Navigator.pop(sheetContext);
              },
              onCodigoLetterTap: (letter) {
                _toggleCodigoLetter(letter);
                Navigator.pop(sheetContext);
              },
              onClear: () {
                clearFilters();
                Navigator.pop(sheetContext);
              },
            );
          },
        );
      },
    );
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
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompactFilterBar(
            productCount: products.length,
            activeFilterCount: _activeFilterCount,
            hasActiveFilters: hasActiveFilters,
            activeMarca: _marca,
            activeCalibre: _calibre,
            activeMarcaLetter: _marcaLetter,
            activeCodigoLetter: _codigoLetter,
            onOpenFilters: () => _openFilterSheet(
              productCount: products.length,
              brands: brands,
              calibers: calibers,
              marcaLetters: marcaLetters,
              codigoLetters: codigoLetters,
            ),
            onClear: clearFilters,
            onRemoveMarca: () => setState(() => _marca = null),
            onRemoveCalibre: () => setState(() => _calibre = null),
            onRemoveMarcaLetter: () => setState(() => _marcaLetter = null),
            onRemoveCodigoLetter: () => setState(() => _codigoLetter = null),
          ),
          Expanded(
            child: products.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Ningún producto con esos filtros',
                    subtitle: 'Tocá Filtros para ajustar o limpiar la búsqueda',
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final useList = constraints.maxWidth < 720;

                      if (useList) {
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          itemCount: products.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return ProductCard(
                              product: products[index],
                              layout: ProductCardLayout.list,
                            );
                          },
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 480,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          mainAxisExtent: 760,
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

class _CompactFilterBar extends StatelessWidget {
  const _CompactFilterBar({
    required this.productCount,
    required this.activeFilterCount,
    required this.hasActiveFilters,
    required this.activeMarca,
    required this.activeCalibre,
    required this.activeMarcaLetter,
    required this.activeCodigoLetter,
    required this.onOpenFilters,
    required this.onClear,
    required this.onRemoveMarca,
    required this.onRemoveCalibre,
    required this.onRemoveMarcaLetter,
    required this.onRemoveCodigoLetter,
  });

  final int productCount;
  final int activeFilterCount;
  final bool hasActiveFilters;
  final String? activeMarca;
  final String? activeCalibre;
  final String? activeMarcaLetter;
  final String? activeCodigoLetter;
  final VoidCallback onOpenFilters;
  final VoidCallback onClear;
  final VoidCallback onRemoveMarca;
  final VoidCallback onRemoveCalibre;
  final VoidCallback onRemoveMarcaLetter;
  final VoidCallback onRemoveCodigoLetter;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 1,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenFilters,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    side: BorderSide(
                      color: hasActiveFilters
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: Text(
                    activeFilterCount > 0
                        ? 'Filtros ($activeFilterCount)'
                        : 'Filtros',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: AppDecorations.goldGradient,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '$productCount',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const Spacer(),
                if (hasActiveFilters)
                  TextButton(
                    onPressed: onClear,
                    child: const Text(
                      'LIMPIAR',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
              ],
            ),
          ),
          if (hasActiveFilters)
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                children: [
                  if (activeMarca != null)
                    _ActiveFilterChip(
                      label: activeMarca!.toUpperCase(),
                      onRemove: onRemoveMarca,
                    ),
                  if (activeCalibre != null)
                    _ActiveFilterChip(
                      label: activeCalibre!.toUpperCase(),
                      onRemove: onRemoveCalibre,
                    ),
                  if (activeMarcaLetter != null)
                    _ActiveFilterChip(
                      label: 'Marca ${activeMarcaLetter!}',
                      onRemove: onRemoveMarcaLetter,
                    ),
                  if (activeCodigoLetter != null)
                    _ActiveFilterChip(
                      label: 'Cód. ${activeCodigoLetter!}',
                      onRemove: onRemoveCodigoLetter,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  const _ActiveFilterChip({
    required this.label,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InputChip(
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        onDeleted: onRemove,
        deleteIcon: const Icon(Icons.close, size: 16),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _FilterSheetContent extends StatelessWidget {
  const _FilterSheetContent({
    required this.scrollController,
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
    required this.onClear,
  });

  final ScrollController scrollController;
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
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            Text(
              'Filtrar catálogo',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const Spacer(),
            TextButton(onPressed: onClear, child: const Text('Limpiar')),
          ],
        ),
        Text(
          '$productCount producto${productCount == 1 ? '' : 's'} con estos filtros',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 16),
        _FilterSection(
          label: 'Marca',
          child: _HorizontalChips(
            items: brands,
            selected: selectedMarca,
            onTap: onMarcaTap,
            labelBuilder: (value) => value.toUpperCase(),
          ),
        ),
        _FilterSection(
          label: 'Calibre',
          child: _HorizontalChips(
            items: calibers,
            selected: selectedCalibre,
            onTap: onCalibreTap,
            labelBuilder: (value) => value.toUpperCase(),
          ),
        ),
        _FilterSection(
          label: 'Letra marca',
          child: _HorizontalLetters(
            letters: marcaLetters,
            selected: selectedMarcaLetter,
            onTap: onMarcaLetterTap,
          ),
        ),
        if (showCodigoFilter)
          _FilterSection(
            label: 'Letra código',
            child: _HorizontalLetters(
              letters: codigoLetters,
              selected: selectedCodigoLetter,
              onTap: onCodigoLetterTap,
            ),
          ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
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
    if (items.isEmpty) {
      return const Text(
        'Sin opciones',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    return SizedBox(
      height: 40,
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
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: alphabet.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
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
