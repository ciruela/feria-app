import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/exchange_rate_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

/// Header del mock 03/04_Desk: saludo, búsqueda, stats.
class CatalogDesktopHeader extends StatelessWidget {
  const CatalogDesktopHeader({
    super.key,
    required this.sellerName,
    required this.sellerInitial,
    required this.exchangeRate,
    required this.lowStockCount,
    required this.showing,
    required this.totalLoaded,
    required this.onChangeSeller,
    this.searchController,
    this.searchFocus,
    this.onSearchChanged,
  });

  final String sellerName;
  final String sellerInitial;
  final ExchangeRateService exchangeRate;
  final int lowStockCount;
  final int showing;
  final int totalLoaded;
  final VoidCallback onChangeSeller;
  final TextEditingController? searchController;
  final FocusNode? searchFocus;
  final ValueChanged<String>? onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hola, $sellerName',
                    style: AppText.heading.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Armas cortas · largas · munición',
                    style: AppText.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocus,
                  readOnly: searchController == null,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Código, modelo o calibre',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                    ),
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
              ),
              const SizedBox(width: 12),
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
          CatalogDesktopStatsRow(
            rate: exchangeRate.hasServerRate ? exchangeRate.rate : null,
            updatedAt: exchangeRate.updatedAt,
            lowStockCount: lowStockCount,
            showing: showing,
            totalLoaded: totalLoaded,
          ),
        ],
      ),
    );
  }
}

class CatalogDesktopStatsRow extends StatelessWidget {
  const CatalogDesktopStatsRow({
    super.key,
    required this.rate,
    required this.updatedAt,
    required this.lowStockCount,
    required this.showing,
    required this.totalLoaded,
  });

  final double? rate;
  final DateTime? updatedAt;
  final int lowStockCount;
  final int showing;
  final int totalLoaded;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'DÓLAR DE REFERENCIA',
            value: rate != null ? _formatReferenceRate(rate!) : '—',
            subtitle: updatedAt != null ? formatDateTime(updatedAt!) : null,
            accent: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'ÚLTIMAS UNIDADES',
            value: '$lowStockCount',
            subtitle: 'productos',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatBox(
            label: 'MOSTRANDO',
            value: '$showing',
            subtitle: 'de $totalLoaded cargados',
          ),
        ),
      ],
    );
  }
}

String _formatReferenceRate(double rate) {
  return NumberFormat('#,##0', 'es_AR').format(rate);
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    this.subtitle,
    this.accent = false,
  });

  final String label;
  final String value;
  final String? subtitle;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppText.label.copyWith(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppText.number.copyWith(
              fontWeight: FontWeight.w700,
              color: accent ? AppColors.accent : AppColors.textPrimary,
              fontSize: accent ? 28 : 24,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}
