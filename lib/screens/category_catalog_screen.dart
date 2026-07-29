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

  /// Nombre de ruta para volver al catálogo desde comprobante / carrito.
  static const routeName = '/employee/category-catalog';

  final ProductType type;

  @override
  State<CategoryCatalogScreen> createState() => _CategoryCatalogScreenState();
}

class _CategoryCatalogScreenState extends State<CategoryCatalogScreen> {
  String? _marca;
  String? _calibre;
  String? _marcaLetter;
  String _codigoQuery = '';

  bool get hasActiveFilters =>
      _marca != null ||
      _calibre != null ||
      _marcaLetter != null ||
      _codigoQuery.isNotEmpty;

  int get _activeFilterCount => [
        _marca,
        _calibre,
        _marcaLetter,
        if (_codigoQuery.isNotEmpty) _codigoQuery,
      ].where((value) => value != null).length;

  void clearFilters() {
    setState(() {
      _marca = null;
      _calibre = null;
      _marcaLetter = null;
      _codigoQuery = '';
    });
  }

  Future<void> _openFilterSheet({
    required List<String> brands,
    required Set<String> marcaLetters,
    required Set<String> codigoPrefixes,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, sheetSetState) {
                final catalog = context.watch<CatalogService>();
                final calibers = catalog.calibersFor(widget.type, _marca);
                final products = catalog.filtered(
                  type: widget.type,
                  marca: _marca,
                  calibre: _calibre,
                  marcaLetter: _marcaLetter,
                  codigoQuery:
                      _codigoQuery.isEmpty ? null : _codigoQuery,
                );

                void refresh(VoidCallback update) {
                  setState(update);
                  sheetSetState(() {});
                }

                return _FilterSheetContent(
                  scrollController: scrollController,
                  productCount: products.length,
                  brands: brands,
                  calibers: calibers,
                  marcaLetters: marcaLetters,
                  codigoPrefixes: codigoPrefixes,
                  selectedMarca: _marca,
                  selectedCalibre: _calibre,
                  selectedMarcaLetter: _marcaLetter,
                  codigoQuery: _codigoQuery,
                  onMarcaTap: (marca) => refresh(
                    () => _marca = _marca == marca ? null : marca,
                  ),
                  onCalibreTap: (calibre) => refresh(
                    () => _calibre = _calibre == calibre ? null : calibre,
                  ),
                  onMarcaLetterTap: (letter) => refresh(
                    () => _marcaLetter =
                        _marcaLetter == letter ? null : letter,
                  ),
                  onCodigoQueryChanged: (query) => refresh(
                    () => _codigoQuery = query.trim(),
                  ),
                  onCodigoPrefixTap: (prefix) => refresh(() {
                    if (_codigoQuery == prefix) {
                      _codigoQuery = '';
                    } else {
                      _codigoQuery = prefix;
                    }
                  }),
                  onClear: () => refresh(() {
                    _marca = null;
                    _calibre = null;
                    _marcaLetter = null;
                    _codigoQuery = '';
                  }),
                  onApply: () => Navigator.pop(sheetContext),
                );
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
    final marcaLetters = catalog.usedLettersForMarca(type);
    final codigoPrefixes = catalog.usedLettersForCodigo(type);

    final products = catalog.filtered(
      type: type,
      marca: _marca,
      calibre: _calibre,
      marcaLetter: _marcaLetter,
      codigoQuery: _codigoQuery.isEmpty ? null : _codigoQuery,
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
            activeCodigoQuery: _codigoQuery,
            onOpenFilters: () => _openFilterSheet(
              brands: brands,
              marcaLetters: marcaLetters,
              codigoPrefixes: codigoPrefixes,
            ),
            onClear: clearFilters,
            onRemoveMarca: () => setState(() => _marca = null),
            onRemoveCalibre: () => setState(() => _calibre = null),
            onRemoveMarcaLetter: () => setState(() => _marcaLetter = null),
            onRemoveCodigoQuery: () => setState(() => _codigoQuery = ''),
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
    required this.activeCodigoQuery,
    required this.onOpenFilters,
    required this.onClear,
    required this.onRemoveMarca,
    required this.onRemoveCalibre,
    required this.onRemoveMarcaLetter,
    required this.onRemoveCodigoQuery,
  });

  final int productCount;
  final int activeFilterCount;
  final bool hasActiveFilters;
  final String? activeMarca;
  final String? activeCalibre;
  final String? activeMarcaLetter;
  final String activeCodigoQuery;
  final VoidCallback onOpenFilters;
  final VoidCallback onClear;
  final VoidCallback onRemoveMarca;
  final VoidCallback onRemoveCalibre;
  final VoidCallback onRemoveMarcaLetter;
  final VoidCallback onRemoveCodigoQuery;

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
                  if (activeCodigoQuery.isNotEmpty)
                    _ActiveFilterChip(
                      label: 'Cód. $activeCodigoQuery',
                      onRemove: onRemoveCodigoQuery,
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
    required this.brands,
    required this.calibers,
    required this.marcaLetters,
    required this.codigoPrefixes,
    required this.selectedMarca,
    required this.selectedCalibre,
    required this.selectedMarcaLetter,
    required this.codigoQuery,
    required this.onMarcaTap,
    required this.onCalibreTap,
    required this.onMarcaLetterTap,
    required this.onCodigoQueryChanged,
    required this.onCodigoPrefixTap,
    required this.onClear,
    required this.onApply,
  });

  final ScrollController scrollController;
  final int productCount;
  final List<String> brands;
  final List<String> calibers;
  final Set<String> marcaLetters;
  final Set<String> codigoPrefixes;
  final String? selectedMarca;
  final String? selectedCalibre;
  final String? selectedMarcaLetter;
  final String codigoQuery;
  final ValueChanged<String> onMarcaTap;
  final ValueChanged<String> onCalibreTap;
  final ValueChanged<String> onMarcaLetterTap;
  final ValueChanged<String> onCodigoQueryChanged;
  final ValueChanged<String> onCodigoPrefixTap;
  final VoidCallback onClear;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                'Podés combinar varios filtros antes de ver los resultados.',
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
                label: selectedMarca == null
                    ? 'Calibre'
                    : 'Calibre · ${selectedMarca!.toUpperCase()}',
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
              _FilterSection(
                label: 'Código',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CodigoQueryField(
                      value: codigoQuery,
                      onChanged: onCodigoQueryChanged,
                    ),
                    if (codigoPrefixes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text(
                        'Atajos por primer carácter',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _CodePrefixChips(
                        prefixes: codigoPrefixes,
                        selected: codigoQuery.length == 1 ? codigoQuery : null,
                        onTap: onCodigoPrefixTap,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onApply,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  'VER $productCount PRODUCTO${productCount == 1 ? '' : 'S'}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
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

class _CodigoQueryField extends StatefulWidget {
  const _CodigoQueryField({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_CodigoQueryField> createState() => _CodigoQueryFieldState();
}

class _CodigoQueryFieldState extends State<_CodigoQueryField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _CodigoQueryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: 'Escribí el código o parte de él',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: widget.value.isNotEmpty
            ? IconButton(
                tooltip: 'Borrar',
                onPressed: () => widget.onChanged(''),
                icon: const Icon(Icons.close_rounded, size: 18),
              )
            : null,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _CodePrefixChips extends StatelessWidget {
  const _CodePrefixChips({
    required this.prefixes,
    required this.selected,
    required this.onTap,
  });

  final Set<String> prefixes;
  final String? selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (prefixes.isEmpty) {
      return const Text(
        'Sin códigos en el catálogo',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }

    final items = prefixes.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a);
        final bNum = int.tryParse(b);
        if (aNum != null && bNum != null) return aNum.compareTo(bNum);
        if (aNum != null) return -1;
        if (bNum != null) return 1;
        return a.compareTo(b);
      });

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final prefix in items)
          LetterChip(
            letter: prefix,
            enabled: true,
            selected: selected == prefix,
            onTap: () => onTap(prefix),
          ),
      ],
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
