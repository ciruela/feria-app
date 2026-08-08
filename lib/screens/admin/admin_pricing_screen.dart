import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/pricing_limits.dart';
import '../../models/presupuesto_branding.dart';
import '../../services/pricing_settings_service.dart';
import '../../services/tenant_session_service.dart';
import '../../widgets/feria_shell.dart';

class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  late final TextEditingController _efectivo;
  late final TextEditingController _debito;
  late final TextEditingController _t1;
  late final TextEditingController _t3;
  late final TextEditingController _t6;
  late final TextEditingController _t9;
  late final TextEditingController _t12;
  late final TextEditingController _t18;
  late final TextEditingController _munEfectivo;
  late final TextEditingController _munT3;
  late bool _municionOverride;
  late bool _municionTransferEfectivo;
  late bool _municionT3SoloLarga;
  bool _saving = false;

  bool get _isWorldGuns {
    final slug = context.read<TenantSessionService>().activeTenantSlug;
    return PresupuestoBranding.forTenant(slug: slug).isWorldGuns;
  }

  @override
  void initState() {
    super.initState();
    final settings = context.read<PricingSettingsService>();
    _efectivo = TextEditingController(text: settings.descuentoEfectivoPct.toString());
    _debito = TextEditingController(text: settings.recargoDebitoPct.toString());
    _t1 = TextEditingController(text: settings.recargoTarjeta1Pct.toString());
    _t3 = TextEditingController(text: settings.recargoTarjeta3Pct.toString());
    _t6 = TextEditingController(text: settings.recargoTarjeta6Pct.toString());
    _t9 = TextEditingController(text: settings.recargoTarjeta9Pct.toString());
    _t12 = TextEditingController(text: settings.recargoTarjeta12Pct.toString());
    _t18 = TextEditingController(text: settings.recargoTarjeta18Pct.toString());
    _munEfectivo = TextEditingController(
      text: settings.municionDescuentoEfectivoPct.toString(),
    );
    _munT3 = TextEditingController(
      text: settings.municionRecargoTarjeta3Pct.toString(),
    );
    _municionOverride = settings.municionOverrideEnabled;
    _municionTransferEfectivo = settings.municionTransferenciaComoEfectivo;
    _municionT3SoloLarga = settings.municionTarjeta3SoloArmaLarga;
  }

  @override
  void dispose() {
    _efectivo.dispose();
    _debito.dispose();
    _t1.dispose();
    _t3.dispose();
    _t6.dispose();
    _t9.dispose();
    _t12.dispose();
    _t18.dispose();
    _munEfectivo.dispose();
    _munT3.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = _validateAndMessage();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<PricingSettingsService>().save(
            efectivoPct: double.parse(_efectivo.text),
            debitoPct: double.parse(_debito.text),
            tarjeta1Pct: double.parse(_t1.text),
            tarjeta3Pct: double.parse(_t3.text),
            tarjeta6Pct: double.parse(_t6.text),
            tarjeta9Pct: double.parse(_t9.text),
            tarjeta12Pct: double.parse(_t12.text),
            tarjeta18Pct: double.parse(_t18.text),
            municionOverrideEnabled: _isWorldGuns ? _municionOverride : false,
            municionEfectivoPct: double.tryParse(_munEfectivo.text),
            municionTarjeta3Pct: double.tryParse(_munT3.text),
            municionTransferenciaComoEfectivo: _municionTransferEfectivo,
            municionTarjeta3SoloArmaLarga: _municionT3SoloLarga,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precios y promos actualizados')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showMunicion = _isWorldGuns;

    return FeriaScaffold(
      appBar: const FeriaAppBar(title: Text('Precios y cuotas')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Promos y descuentos',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            showMunicion
                ? 'Lista = USD × tipo de cambio. Abajo están las promos '
                    'generales (armas) y la promo exclusiva de munición. '
                    'Los % se guardan en la armería (todos los dispositivos).'
                : 'Lista = USD × tipo de cambio. Transferencia usa precio lista. '
                    'Efectivo aplica descuento sobre lista. Débito y cuotas '
                    'recargan % sobre lista. Los % se guardan en la armería.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (showMunicion) ...[
            const SizedBox(height: 24),
            Text(
              'Promo munición (World Guns)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              '10% efectivo/transferencia aplica a toda la munición. '
              '3 cuotas sin interés solo a munición de arma larga '
              '(rifle/escopeta/.22). Munición de pistola/revólver '
              '(9mm, .40, .45, .38, etc.) usa el recargo general de 3 cuotas.',
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activar promo munición'),
              value: _municionOverride,
              onChanged: (v) => setState(() => _municionOverride = v),
            ),
            if (_municionOverride) ...[
              _field('Descuento efectivo munición (%)', _munEfectivo),
              _field('Recargo 3 cuotas munición larga (%)', _munT3),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('3 cuotas SI solo en munición arma larga'),
                subtitle: const Text(
                  'Si está apagado, el recargo 3 cuotas de arriba aplica a toda la munición.',
                ),
                value: _municionT3SoloLarga,
                onChanged: (v) => setState(() => _municionT3SoloLarga = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Transferencia = mismo descuento que efectivo'),
                subtitle: const Text(
                  'Si está apagado, transferencia usa precio lista.',
                ),
                value: _municionTransferEfectivo,
                onChanged: (v) =>
                    setState(() => _municionTransferEfectivo = v),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Resto del catálogo (armas)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
          ] else ...[
            const SizedBox(height: 20),
          ],
          _field('Descuento efectivo (%)', _efectivo),
          _field('Recargo débito (%)', _debito),
          _field('Recargo 1 cuota (%)', _t1),
          _field('Recargo 3 cuotas (%)', _t3),
          _field('Recargo 6 cuotas (%)', _t6),
          _field('Recargo 9 cuotas (%)', _t9),
          _field('Recargo 12 cuotas (%)', _t12),
          _field('Recargo 18 cuotas (%)', _t18),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'GUARDANDO…' : 'GUARDAR'),
          ),
        ],
      ),
    );
  }

  /// Returns an error message, or null if all fields are valid.
  String? _validateAndMessage() {
    final entries = <(String key, String label, String text)>[
      ('efectivo', 'El descuento de efectivo', _efectivo.text),
      ('debito', 'El recargo de débito', _debito.text),
      ('tarjeta1', 'El recargo de 1 cuota', _t1.text),
      ('tarjeta3', 'El recargo de 3 cuotas', _t3.text),
      ('tarjeta6', 'El recargo de 6 cuotas', _t6.text),
      ('tarjeta9', 'El recargo de 9 cuotas', _t9.text),
      ('tarjeta12', 'El recargo de 12 cuotas', _t12.text),
      ('tarjeta18', 'El recargo de 18 cuotas', _t18.text),
    ];

    if (_isWorldGuns && _municionOverride) {
      entries.addAll([
        (
          'efectivo',
          'El descuento de efectivo (munición)',
          _munEfectivo.text,
        ),
        (
          'tarjeta3',
          'El recargo de 3 cuotas (munición)',
          _munT3.text,
        ),
      ]);
    }

    for (final (key, label, text) in entries) {
      final value = double.tryParse(text);
      if (value == null) {
        return 'Valores inválidos';
      }
      final (lo, hi) = PricingLimits.rangeFor(key);
      if (value < lo || value > hi) {
        return '$label debe estar entre ${lo.toInt()} y ${hi.toInt()}%';
      }
    }
    return null;
  }

  Widget _field(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
