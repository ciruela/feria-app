import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/exchange_rate_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/feria_shell.dart';
import '../widgets/section_header.dart';

class ExchangeRateScreen extends StatefulWidget {
  const ExchangeRateScreen({super.key});

  @override
  State<ExchangeRateScreen> createState() => _ExchangeRateScreenState();
}

class _ExchangeRateScreenState extends State<ExchangeRateScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final rate = context.read<ExchangeRateService>().rate;
    _controller = TextEditingController(
      text: rate.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exchangeRate = context.watch<ExchangeRateService>();

    return FeriaScaffold(
      appBar: const FeriaAppBar(
        title: Text('Tipo de cambio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeader(
              title: 'Tipo de cambio de hoy',
              subtitle:
                  'Se sincroniza en tiempo real con todos los celulares conectados a Supabase.',
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppDecorations.radiusLg,
                border: Border.all(color: AppColors.border),
                boxShadow: [AppDecorations.cardShadow],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1 USD =',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: const InputDecoration(
                      suffixText: 'ARS',
                      suffixStyle: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppDecorations.goldGradient,
                borderRadius: AppDecorations.radiusMd,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () async {
                final parsed = double.tryParse(
                  _controller.text.replaceAll(',', '.'),
                );

                if (parsed == null || parsed <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ingresá un tipo de cambio válido.'),
                    ),
                  );
                  return;
                }

                await context.read<ExchangeRateService>().saveRate(parsed);

                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tipo de cambio guardado.'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: AppColors.primaryDark,
              ),
              child: const Text('GUARDAR'),
            ),
            ),
            const SizedBox(height: 16),
            if (exchangeRate.updatedAt != null)
              Text(
                'Última actualización: ${formatDateTime(exchangeRate.updatedAt!)}',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
