import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/presupuesto_branding.dart';
import '../models/product_prices.dart';
import '../services/cart_service.dart';
import '../services/cart_totals_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/tenant_session_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// World Guns: selector por venta para cobrar con o sin descuento.
///
/// Muestra siempre los dos precios (con descuento y a precio de lista) y deja
/// elegir cuál se aplica en esta venta. Solo aparece en World Guns; en el resto
/// de armerías es un `SizedBox.shrink()` y la venta sigue con descuentos.
class CartDiscountsPanel extends StatelessWidget {
  const CartDiscountsPanel({super.key, this.raisedSurface = false});

  /// Fondo elevado (mock mobile) en lugar de touch.
  final bool raisedSurface;

  @override
  Widget build(BuildContext context) {
    final slug = context.watch<TenantSessionService>().activeTenantSlug;
    final isWorldGuns = PresupuestoBranding.forTenant(slug: slug).isWorldGuns;
    if (!isWorldGuns) return const SizedBox.shrink();

    final cart = context.watch<CartService>();
    if (cart.isEmpty) return const SizedBox.shrink();

    final exchangeRate = context.watch<ExchangeRateService>();
    final pricingSettings = context.watch<PricingSettingsService>();
    final totalsService = context.read<CartTotalsService>();
    final hasRate = exchangeRate.hasServerRate;
    final applied = cart.applyDiscounts;

    double sumEfectivo({required bool applyDiscounts}) {
      var ars = 0.0;
      for (final item in cart.items) {
        ars += totalsService
            .lineTotal(
              item: item,
              method: PaymentMethod.efectivo,
              exchangeRate: exchangeRate,
              pricingSettings: pricingSettings,
              applyDiscounts: applyDiscounts,
            )
            .ars;
      }
      return ars;
    }

    final conDesc = hasRate ? sumEfectivo(applyDiscounts: true) : 0.0;
    final sinDesc = hasRate ? sumEfectivo(applyDiscounts: false) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: raisedSurface ? AppColors.surfaceRaised : AppColors.surfaceTouch,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DESCUENTOS',
                style: AppText.label.copyWith(fontSize: 10),
              ),
              const SizedBox(height: 8),
              Text(
                'Elegí con qué precio cobrar esta venta.',
                style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              _DiscountOption(
                label: 'Con descuento',
                value: hasRate ? formatArs(conDesc) : '—',
                selected: applied,
                onTap: () => cart.setApplyDiscounts(true),
              ),
              const SizedBox(height: 8),
              _DiscountOption(
                label: 'Sin descuento (lista)',
                value: hasRate ? formatArs(sinDesc) : '—',
                selected: !applied,
                onTap: () => cart.setApplyDiscounts(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscountOption extends StatelessWidget {
  const _DiscountOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.canvas : AppColors.textPrimary;
    return Material(
      color: selected ? AppColors.textPrimary : AppColors.surfaceTouch,
      borderRadius: BorderRadius.circular(AppDecorations.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDecorations.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDecorations.radius),
            border: Border.all(
              color: selected ? AppColors.textPrimary : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 18,
                color: selected ? AppColors.accent : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppText.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              Text(
                value,
                style: AppText.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
