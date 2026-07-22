import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
            'Efectivo aplica descuento sobre lista. Débito y cuotas recargan % sobre lista.',
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
              final efectivo = double.tryParse(_efectivo.text);
              final debito = double.tryParse(_debito.text);
              final t1 = double.tryParse(_t1.text);
              final t3 = double.tryParse(_t3.text);
              final t6 = double.tryParse(_t6.text);
              final t9 = double.tryParse(_t9.text);
              final t12 = double.tryParse(_t12.text);
              final t18 = double.tryParse(_t18.text);

              if ([efectivo, debito, t1, t3, t6, t9, t12, t18].any((v) => v == null)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Valores inválidos')),
                );
                return;
              }

              await context.read<PricingSettingsService>().save(
                    efectivoPct: efectivo!,
                    debitoPct: debito!,
                    tarjeta1Pct: t1!,
                    tarjeta3Pct: t3!,
                    tarjeta6Pct: t6!,
                    tarjeta9Pct: t9!,
                    tarjeta12Pct: t12!,
                    tarjeta18Pct: t18!,
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
