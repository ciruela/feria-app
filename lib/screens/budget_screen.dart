import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/budget.dart';
import '../models/budget_customer_controllers.dart';
import '../config/app_config.dart';
import '../services/budget_service.dart';
import '../services/cart_service.dart';
import '../services/dni_ocr_service.dart';
import '../services/exchange_rate_service.dart';
import '../services/pricing_settings_service.dart';
import '../services/seller_service.dart';
import '../services/supabase_sales_repository.dart';
import '../theme/app_theme.dart';
import '../utils/presupuesto_pdf.dart';
import '../widgets/budget_payment_panel.dart';
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
      _showMessage('Datos del DNI cargados. Revisá antes de generar.');
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
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Frente del DNI'),
              subtitle: const Text('Nombre, apellido y número de documento'),
              onTap: () {
                Navigator.pop(context);
                _scanDniSide(DniScanSide.front, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Dorso del DNI'),
              subtitle: const Text('Domicilio y localidad'),
              onTap: () {
                Navigator.pop(context);
                _scanDniSide(DniScanSide.back, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: const Text('Frente y dorso (cámara)'),
              subtitle: const Text('Escaneo completo en dos pasos'),
              onTap: () {
                Navigator.pop(context);
                _scanDniBothSides(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir foto de galería'),
              subtitle: const Text('Una cara del DNI (frente o dorso)'),
              onTap: () {
                Navigator.pop(context);
                _scanDniSide(DniScanSide.unknown, ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdf(Budget budget) async {
    try {
      await PresupuestoPdf.share(budget);
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo exportar el PDF: $error');
    }
  }

  Future<void> _printBudget(Budget budget) async {
    try {
      await PresupuestoPdf.printBudget(budget);
    } catch (error) {
      if (!mounted) return;
      _showMessage('No se pudo imprimir: $error');
    }
  }

  Future<void> _finalizeComprobante(Budget budget) async {
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

    final snapshot = budget.copyWithCustomer(_customer);

    if (AppConfig.useSupabase) {
      final seller = context.read<SellerService>().selected;
      final exchangeRate = context.read<ExchangeRateService>().rate;
      try {
        await SupabaseSalesRepository().insert(
          snapshot,
          sellerId: seller?.id,
          exchangeRate: exchangeRate,
        );
      } catch (_) {
        if (!mounted) return;
        _showMessage(
          'Comprobante generado, no se pudo guardar en nube',
        );
      }
    }

    if (!mounted) return;
    context.read<CartService>().clear();

    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ComprobanteScreen(budget: snapshot),
      ),
    );
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

    return FeriaScaffold(
      appBar: const FeriaAppBar(
        title: Text('Presupuesto'),
      ),
      body: cart.isEmpty
          ? const Center(child: Text('El carrito está vacío'))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _scanning ? null : _pickScanSource,
                        icon: _scanning
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.document_scanner_outlined),
                        label: const Text('ESCANEAR DNI'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'El DNI argentino tiene dos caras: escaneá el frente (nombre y DNI) '
                  'y el dorso (domicilio y localidad). Siempre revisá los datos antes de generar.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                const BudgetPaymentPanel(),
                if (!checkoutConfigured) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Configurá cómo abona el cliente para habilitar el comprobante.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.goldDark,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                PresupuestoPaper(
                  budget: budget,
                  controllers: _controllers,
                  onChanged: () => setState(() {}),
                  onSerialChanged: (lineKey, value) {
                    context.read<CartService>().updateSerialNumber(lineKey, value);
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: checkoutConfigured
                      ? () => _finalizeComprobante(budget)
                      : null,
                  icon: const Icon(Icons.receipt_long_rounded),
                  label: const Text('GENERAR COMPROBANTE'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _exportPdf(budget),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('EXPORTAR PDF'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _printBudget(budget),
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('IMPRIMIR'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}
