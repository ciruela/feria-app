import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../cart_checkout_payment_panel.dart';
import '../presupuesto/budget_serial_panel.dart';

/// Mock 07_Mob — chrome del presupuesto (sin rediseñar el comprobante).
class BudgetMobileLayout extends StatelessWidget {
  const BudgetMobileLayout({
    super.key,
    required this.scanning,
    required this.hasCustomerData,
    required this.checkoutConfigured,
    required this.onBack,
    required this.onScanDni,
    required this.onRescanDni,
    required this.preview,
    required this.actions,
  });

  final bool scanning;
  final bool hasCustomerData;
  final bool checkoutConfigured;
  final VoidCallback onBack;
  final VoidCallback onScanDni;
  final VoidCallback onRescanDni;
  final Widget preview;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BudgetMobileHeader(onBack: onBack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                BudgetMobileChrome(
                  scanning: scanning,
                  hasCustomerData: hasCustomerData,
                  checkoutConfigured: checkoutConfigured,
                  onScanDni: onScanDni,
                  onRescanDni: onRescanDni,
                ),
                const SizedBox(height: 16),
                const BudgetSerialPanel(),
                const SizedBox(height: 16),
                Align(alignment: Alignment.topCenter, child: preview),
                const SizedBox(height: 20),
                actions,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BudgetMobileHeader extends StatelessWidget {
  const BudgetMobileHeader({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded, size: 24),
              color: AppColors.textMuted,
              tooltip: 'Volver',
            ),
            Text(
              'Presupuesto',
              style: AppText.heading.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetMobileChrome extends StatelessWidget {
  const BudgetMobileChrome({
    super.key,
    required this.scanning,
    required this.hasCustomerData,
    required this.checkoutConfigured,
    required this.onScanDni,
    required this.onRescanDni,
  });

  final bool scanning;
  final bool hasCustomerData;
  final bool checkoutConfigured;
  final VoidCallback onScanDni;
  final VoidCallback onRescanDni;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: scanning ? null : (hasCustomerData ? onRescanDni : onScanDni),
          icon: scanning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.badge_outlined),
          label: Text(hasCustomerData ? 'Volver a escanear el DNI' : 'Escanear DNI'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            minimumSize: const Size.fromHeight(44),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasCustomerData
              ? 'Datos del cliente cargados desde el DNI. Revisalos antes de generar.'
              : 'El DNI argentino tiene dos caras: escaneá el frente (nombre y DNI) '
                  'y el dorso (domicilio arriba y CUIL al medio). Revisá siempre los datos antes de generar.',
          style: AppText.bodySmall.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        const CartCheckoutPaymentPanel(
          budgetHandoff: true,
          raisedSurface: true,
        ),
        if (!checkoutConfigured) ...[
          const SizedBox(height: 8),
          Text(
            'Configurá cómo abona el cliente para habilitar el comprobante.',
            style: AppText.bodySmall.copyWith(color: AppColors.accent),
          ),
        ],
      ],
    );
  }
}
