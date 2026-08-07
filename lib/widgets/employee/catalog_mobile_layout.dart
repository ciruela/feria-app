import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/product.dart';
import '../../services/exchange_rate_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/section_header.dart';
import 'catalog_category_chips.dart';
import 'catalog_filter_bar.dart';
import 'catalog_product_list.dart';
import 'employee_role_widgets.dart';

/// Mock 03_Mob — catálogo empleado.
class CatalogMobileLayout extends StatelessWidget {
  const CatalogMobileLayout({
    super.key,
    required this.products,
    required this.totalLoaded,
    required this.lowStockCount,
    required this.searchController,
    required this.searchFocus,
    required this.typeFilter,
    required this.marcaOptions,
    required this.calibreOptions,
    required this.marcaFilter,
    required this.calibreFilter,
    required this.sellerName,
    required this.sellerInitial,
    required this.exchangeRate,
    required this.onSearchChanged,
    required this.onTypeChanged,
    required this.onMarcaChanged,
    required this.onCalibreChanged,
    required this.onClearFilters,
    required this.onChangeSeller,
    this.onSync,
    this.isSyncing = false,
  });

  final List<Product> products;
  final int totalLoaded;
  final int lowStockCount;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ProductType? typeFilter;
  final List<String> marcaOptions;
  final List<String> calibreOptions;
  final String? marcaFilter;
  final String? calibreFilter;
  final String sellerName;
  final String sellerInitial;
  final ExchangeRateService exchangeRate;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ProductType?> onTypeChanged;
  final ValueChanged<String?> onMarcaChanged;
  final ValueChanged<String?> onCalibreChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onChangeSeller;
  final VoidCallback? onSync;
  final bool isSyncing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, $sellerName',
                          style: AppText.heading.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Armas cortas · largas · munición',
                          style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (onSync != null)
                    IconButton(
                      tooltip: 'Actualizar catálogo',
                      onPressed: isSyncing ? null : onSync,
                      icon: isSyncing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download_outlined, size: 20),
                    ),
                  DollarReferenceChip(
                    compact: true,
                    rate: exchangeRate.hasServerRate ? exchangeRate.rate : null,
                    updatedAt: exchangeRate.updatedAt,
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: AppColors.surfaceTouch,
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                    child: InkWell(
                      onTap: onChangeSeller,
                      borderRadius: BorderRadius.circular(AppDecorations.radius),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: Text(
                            sellerInitial,
                            style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                focusNode: searchFocus,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscá por nombre, código, marca o calibre',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceRaised,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDecorations.radius),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
        ),
        CatalogCategoryChips(
          selected: typeFilter,
          onSelected: onTypeChanged,
        ),
        const SizedBox(height: 10),
        CatalogFilterBar(
          marcas: marcaOptions,
          calibres: calibreOptions,
          selectedMarca: marcaFilter,
          selectedCalibre: calibreFilter,
          onMarcaChanged: onMarcaChanged,
          onCalibreChanged: onCalibreChanged,
          onClear: onClearFilters,
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Catálogo',
                style: AppText.bodyLarge.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '$totalLoaded producto${totalLoaded == 1 ? '' : 's'}'
                '${lowStockCount > 0 ? ' · $lowStockCount con últimas unidades' : ''}',
                style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: products.isEmpty
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Sin resultados',
                    subtitle: 'Probá otro código, modelo o categoría',
                  )
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceRaised,
                      borderRadius: BorderRadius.circular(AppDecorations.radius),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppDecorations.radius),
                      child: ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          return CatalogProductRow(product: products[index]);
                        },
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Indica si el catálogo remoto permite sync en mobile.
bool catalogMobileShowSync() => AppConfig.usesRemoteCatalog;
