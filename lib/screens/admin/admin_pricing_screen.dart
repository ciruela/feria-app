import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/pricing_settings_service.dart';

class AdminPricingScreen extends StatefulWidget {
  const AdminPricingScreen({super.key});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  late final TextEditingController _efectivo;
  late final TextEditingController _t3;
  late final TextEditingController _t6;
  late final TextEditingController _t12;

  @override
  void initState() {
    super.initState();
    final settings = context.read<PricingSettingsService>();
    _efectivo = TextEditingController(
      text: settings.descuentoEfectivoPct.toString(),
    );
    _t3 = TextEditingController(text: settings.recargoTarjeta3Pct.toString());
    _t6 = TextEditingController(text: settings.recargoTarjeta6Pct.toString());
    _t12 = TextEditingController(text: settings.recargoTarjeta12Pct.toString());
  }

  @override
  void dispose() {
    _efectivo.dispose();
    _t3.dispose();
    _t6.dispose();
    _t12.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Precios y cuotas')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Reglas de precio',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Lista = USD × tipo de cambio. Efectivo descuenta %. Tarjetas recargan %.',
          ),
          const SizedBox(height: 20),
          _field('Descuento efectivo (%)', _efectivo),
          _field('Recargo tarjeta 3 cuotas (%)', _t3),
          _field('Recargo tarjeta 6 cuotas (%)', _t6),
          _field('Recargo tarjeta 12 cuotas (%)', _t12),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final efectivo = double.tryParse(_efectivo.text);
              final t3 = double.tryParse(_t3.text);
              final t6 = double.tryParse(_t6.text);
              final t12 = double.tryParse(_t12.text);

              if ([efectivo, t3, t6, t12].any((v) => v == null)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Valores inválidos')),
                );
                return;
              }

              await context.read<PricingSettingsService>().save(
                    efectivoPct: efectivo!,
                    tarjeta3Pct: t3!,
                    tarjeta6Pct: t6!,
                    tarjeta12Pct: t12!,
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
