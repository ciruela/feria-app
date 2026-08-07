import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/pricing_limits.dart';
import '../../services/pricing_settings_service.dart';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeriaScaffold(
      appBar: const FeriaAppBar(title: Text('Precios y cuotas')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Promos tarjeta',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Lista = USD × tipo de cambio. Transferencia usa precio lista. '
            'Efectivo aplica descuento sobre lista. Débito y cuotas recargan % sobre lista. '
            'Los % se guardan en la armería (todos los dispositivos usan los mismos).',
          ),
          const SizedBox(height: 20),
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
            onPressed: () async {
              final error = _validateAndMessage();
              if (error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error)),
                );
                return;
              }

              await context.read<PricingSettingsService>().save(
                    efectivoPct: double.parse(_efectivo.text),
                    debitoPct: double.parse(_debito.text),
                    tarjeta1Pct: double.parse(_t1.text),
                    tarjeta3Pct: double.parse(_t3.text),
                    tarjeta6Pct: double.parse(_t6.text),
                    tarjeta9Pct: double.parse(_t9.text),
                    tarjeta12Pct: double.parse(_t12.text),
                    tarjeta18Pct: double.parse(_t18.text),
                  );

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Precios actualizados')),
              );
            },
            child: const Text('GUARDAR'),
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
