import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/budget.dart';
import '../models/budget_customer_controllers.dart';
import '../models/product_prices.dart';
import '../config/app_config.dart';
import '../services/budget_service.dart';
import '../services/cart_service.dart';
import '../services/cart_totals_service.dart';
import '../services/catalog_service.dart';
import '../services/dni_ocr_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/seller_service.dart';
import '../services/supabase_sales_repository.dart';
import '../services/tenant_session_service.dart';
import '../theme/app_theme.dart';
import '../models/presupuesto_branding.dart';
import '../utils/layout_breakpoints.dart';
import '../utils/formatters.dart';
import '../utils/presupuesto_pdf.dart';
import '../widgets/cart_checkout_payment_panel.dart';
import '../widgets/employee/dni_scan_sheet.dart';
import '../widgets/feria_shell.dart';
import '../widgets/presupuesto_paper.dart';
import 'comprobante_screen.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  final _controllers = BudgetCustomerControllers();
  final _ocr = DniOcrService();
  bool _scanning = false;
  bool _finalizing = false;

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  BudgetCustomer get _customer => BudgetCustomer(
        fullName: _controllers.fullName.text.trim(),
        dni: _controllers.dni.text.trim(),
        clu: _controllers.clu.text.trim(),
        cluExpiry: _controllers.cluExpiry.text.trim(),
        phone: _controllers.phone.text.trim(),
        email: _controllers.email.text.trim(),
        fiscalCondition: _controllers.fiscalCondition.text.trim(),
        address: _controllers.address.text.trim(),
        city: _controllers.city.text.trim(),
        notes: _controllers.notes.text.trim(),
      );

  Budget _buildBudget(CartService cart) {
    return context.read<BudgetService>().buildFromCart(
      cart: cart,
      exchangeRate: context.read<ExchangeRateService>(),
      pricingSettings: context.read<PricingSettingsService>(),
      customer: _customer,
      sellerService: context.read<SellerService>(),
    );
  }

  void _applyScanResult(DniScanResult result, {bool merge = false}) {
    if (!result.hasData) {
      if (merge) {
        _showMessage(
          result.side == DniScanSide.back
              ? 'No pudimos leer el dorso. Mejorá la luz, apoyá el DNI plano e intentá de nuevo.'
              : 'No pudimos leer esa cara. Completá los datos a mano.',
        );
      } else {
        _showMessage('No pudimos leer el documento. Completá los datos a mano.');
      }
      return;
    }

    setState(() {
      if (merge) {
        final merged = DniScanResult(
          fullName: _controllers.fullName.text.trim().isEmpty
              ? null
              : _controllers.fullName.text.trim(),
          dni: _controllers.dni.text.trim().isEmpty
              ? null
              : _controllers.dni.text.trim(),
          address: _controllers.address.text.trim().isEmpty
              ? null
              : _controllers.address.text.trim(),
          city: _controllers.city.text.trim().isEmpty
              ? null
              : _controllers.city.text.trim(),
        ).merge(result);
        _controllers.applyScan(
          fullName: merged.fullName,
          dni: merged.dni,
          address: merged.address,
          city: merged.city,
        );
      } else {
        _controllers.applyScan(
          fullName: result.fullName,
          dni: result.dni,
          address: result.address,
          city: result.city,
        );
      }
    });

    final missing = <String>[];
    if ((result.fullName?.isEmpty ?? true) &&
        _controllers.fullName.text.trim().isEmpty) {
      missing.add('nombre');
    }
    if ((result.dni?.isEmpty ?? true) &&
        _controllers.dni.text.trim().isEmpty) {
      missing.add('DNI');
    }
    if ((result.address?.isEmpty ?? true) &&
        _controllers.address.text.trim().isEmpty) {
      missing.add('domicilio');
    }

    if (missing.isEmpty) {
      final session = context.read<TenantSessionService>();
      final isUrban =
          PresupuestoBranding.forTenant(slug: session.activeTenantSlug).isUrban;
      _showMessage(
        isUrban
            ? 'DNI cargado (cliente, CUIT/DNI y domicilio). Revisá antes de generar.'
            : 'Datos del DNI cargados. Revisá antes de generar.',
      );
    } else if (result.side == DniScanSide.front) {
      _showMessage(
        'Frente leído. Escaneá el dorso para domicilio y localidad.',
      );
    } else if (result.side == DniScanSide.back) {
      _showMessage('Dorso leído. Revisá domicilio y localidad.');
    } else {
      _showMessage(
        'Datos parciales cargados. Faltan: ${missing.join(', ')}.',
      );
    }
  }

  Future<void> _scanDniSide(DniScanSide side, ImageSource source) async {
    if (kIsWeb) {
      _showMessage('Escaneo de DNI disponible en celular (iOS/Android).');
      return;
    }

    setState(() => _scanning = true);
    try {
      final result = await _ocr.pickAndScan(source: source, hint: side);
      if (!mounted) return;
      if (result == null) return;

      _applyScanResult(result, merge: true);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Error al escanear: $error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _scanDniBothSides(ImageSource source) async {
    if (kIsWeb) {
      _showMessage('Escaneo de DNI disponible en celular (iOS/Android).');
      return;
    }

    setState(() => _scanning = true);
    try {
      final result = await _ocr.pickAndScanBothSides(
        source: source,
        onStep: _showMessage,
      );
      if (!mounted) return;
      if (result == null) return;

      _applyScanResult(result);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Error al escanear: $error');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pickScanSource() async {
    await showDniScanSheet(
      context,
      onScanSide: _scanDniSide,
      onScanBoth: _scanDniBothSides,
    );
  }

  Future<void> _exportPdf(Budget budget) async {
    try {
      final branding = resolvePresupuestoBranding(
        context.read<TenantSessionService>(),
      );
      await PresupuestoPdf.share(budget, branding: branding);
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo exportar el PDF: $error');
    }
  }

  Future<void> _printBudget(Budget budget) async {
    try {
      final branding = resolvePresupuestoBranding(
        context.read<TenantSessionService>(),
      );
      await PresupuestoPdf.printBudget(budget, branding: branding);
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo imprimir: $error');
    }
  }

  Future<void> _finalizeComprobante(Budget budget) async {
    if (_finalizing) return;

    final cart = context.read<CartService>();

    if (!cart.hasCheckoutPayment) {
      _showMessage('Configurá cómo abona el cliente antes de generar el comprobante.');
      return;
    }

    final missingSerial = cart.weaponsMissingSerial;
    if (missingSerial.isNotEmpty) {
      final labels = missingSerial
          .map((item) => item.product.modeloDisplay)
          .join(', ');
      _showMessage('Completá el N° de serie para: $labels');
      return;
    }

    if (_controllers.fullName.text.trim().length < 3) {
      _showMessage('Completá el nombre del cliente en SEÑOR/A.');
      return;
    }

    setState(() => _finalizing = true);
    final snapshot = budget.copyWithCustomer(_customer);
    final sellerId = context.read<SellerService>().selected?.id;
    final catalog = context.read<CatalogService>();

    try {
      if (AppConfig.useSupabase) {
        await context.read<TenantSessionService>().ensureSupabaseWriteContext();
        if (!mounted) return;
        await catalog.syncFromCloud(silent: true);
        if (!mounted) return;
        await SupabaseSalesRepository(catalog: catalog).insert(
          snapshot,
          sellerId: sellerId,
          pricingSettings: context.read<PricingSettingsService>(),
          branding: resolvePresupuestoBranding(
            context.read<TenantSessionService>(),
          ),
        );
      } else {
        final quantities = <String, int>{};
        for (final line in snapshot.lines) {
          if (line.productId.isEmpty) continue;
          quantities.update(
            line.productId,
            (value) => value + line.quantity,
            ifAbsent: () => line.quantity,
          );
        }
        await catalog.applySaleStockDecrement(quantities);
      }

      cart.clear();

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ComprobanteScreen(budget: snapshot),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo confirmar la venta: $error');
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartService>();
    final budget = _buildBudget(cart);
    final checkoutConfigured = cart.hasCheckoutPayment;
    final exchangeRate = context.watch<ExchangeRateService>();
    final seller = context.watch<SellerService>().selected;
    final isDesktop = LayoutBreakpoints.isDesktop(MediaQuery.sizeOf(context).width);
    final hasCustomerData = _controllers.fullName.text.trim().length >= 3;

    final listaTotal = context.read<CartTotalsService>().cartTotalAtMethod(
          cart: cart,
          method: PaymentMethod.lista,
          exchangeRate: exchangeRate,
          pricingSettings: context.read<PricingSettingsService>(),
        );

    final sidebar = _BudgetSidebar(
      scanning: _scanning,
      checkoutConfigured: checkoutConfigured,
      finalizing: _finalizing,
      hasCustomerData: hasCustomerData,
      listaArs: listaTotal.ars,
      exchangeRate: exchangeRate.rate,
      sellerName: seller != null ? formatSellerFirstName(seller.nombre) : null,
      updatedAt: exchangeRate.updatedAt,
      onScanDni: _pickScanSource,
      onRescanDni: _pickScanSource,
      onGenerate: checkoutConfigured && !_finalizing
          ? () => _finalizeComprobante(budget)
          : null,
      onExportPdf: () => _exportPdf(budget),
      onPrint: () => _printBudget(budget),
    );

    final preview = Center(
      child: PresupuestoA4Preview(
        child: PresupuestoPaper(
          budget: budget,
          controllers: _controllers,
          onChanged: () => setState(() {}),
          onSerialChanged: (lineKey, value) {
            context.read<CartService>().updateSerialNumber(lineKey, value);
          },
          onTcChanged: (lineKey, value) {
            context.read<CartService>().updateTarjetaConsumo(lineKey, value);
          },
        ),
      ),
    );

    return FeriaScaffold(
      constrainBody: false,
      appBar: FeriaAppBar(
        title: const Text('Presupuesto'),
        actions: [
          if (isDesktop && seller != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'Atiende ${formatSellerFirstName(seller.nombre)}'
                  '${exchangeRate.updatedAt != null ? ' · ${formatDateTime(exchangeRate.updatedAt!)}' : ''}',
                  style: AppText.bodySmall,
                ),
              ),
            ),
        ],
      ),
      body: cart.isEmpty
          ? const Center(child: Text('El carrito está vacío'))
          : isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 320, child: sidebar),
                    const VerticalDivider(width: 1, color: AppColors.border),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: preview,
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    sidebar,
                    const SizedBox(height: 16),
                    preview,
                  ],
                ),
    );
  }
}

class _BudgetSidebar extends StatelessWidget {
  const _BudgetSidebar({
    required this.scanning,
    required this.checkoutConfigured,
    required this.finalizing,
    required this.hasCustomerData,
    required this.listaArs,
    required this.exchangeRate,
    required this.sellerName,
    required this.updatedAt,
    required this.onScanDni,
    required this.onRescanDni,
    required this.onGenerate,
    required this.onExportPdf,
    required this.onPrint,
  });

  final bool scanning;
  final bool checkoutConfigured;
  final bool finalizing;
  final bool hasCustomerData;
  final double listaArs;
  final double? exchangeRate;
  final String? sellerName;
  final DateTime? updatedAt;
  final VoidCallback onScanDni;
  final VoidCallback onRescanDni;
  final VoidCallback? onGenerate;
  final VoidCallback onExportPdf;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final isDesktop = LayoutBreakpoints.isDesktop(MediaQuery.sizeOf(context).width);

    return Container(
      color: isDesktop ? AppColors.surfaceRaised : Colors.transparent,
      padding: EdgeInsets.all(isDesktop ? 20 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'DATOS DEL CLIENTE',
            style: AppText.label.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: scanning ? null : (hasCustomerData ? onRescanDni : onScanDni),
            icon: scanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(hasCustomerData ? Icons.refresh_rounded : Icons.document_scanner_outlined),
            label: Text(hasCustomerData ? 'Volver a escanear el DNI' : 'Escanear DNI'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasCustomerData
                ? 'Datos del cliente cargados desde el DNI. Revisalos antes de generar.'
                : 'El DNI argentino tiene dos caras: escaneá el frente (nombre y DNI) '
                    'y el dorso (domicilio y localidad). Revisá siempre los datos antes de generar.',
            style: AppText.bodySmall,
          ),
          const SizedBox(height: 20),
          Text(
            'FORMA DE PAGO',
            style: AppText.label.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          const CartCheckoutPaymentPanel(),
          if (!checkoutConfigured) ...[
            const SizedBox(height: 8),
            Text(
              'Configurá cómo abona el cliente para habilitar el comprobante.',
              style: AppText.bodySmall.copyWith(color: AppColors.accent),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'TOTAL DEL PRESUPUESTO',
            style: AppText.label.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            formatArs(listaArs),
            style: AppText.number.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          if (exchangeRate != null) ...[
            const SizedBox(height: 4),
            Text(
              'Lista ${formatArs(listaArs)} · dólar '
              '${formatArs(exchangeRate!).replaceFirst(r'$ ', '')}',
              style: AppText.bodySmall,
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onGenerate,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: const Size.fromHeight(AppDecorations.buttonPrimary),
            ),
            icon: finalizing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent),
                  )
                : const Icon(Icons.receipt_long_outlined),
            label: Text(finalizing ? 'Generando…' : 'Generar comprobante'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onExportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Exportar PDF'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onPrint,
            icon: const Icon(Icons.print_outlined),
            label: const Text('Imprimir'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ],
      ),
    );
  }
}
