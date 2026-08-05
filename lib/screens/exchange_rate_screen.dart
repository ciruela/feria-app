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
  double? _parsed;

  @override
  void initState() {
    super.initState();
    final rate = context.read<ExchangeRateService>().rate;
    _controller = TextEditingController(text: rate.toStringAsFixed(0));
    _parsed = rate;
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final parsed = double.tryParse(_controller.text.replaceAll(',', '.'));
    setState(() => _parsed = parsed);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave {
    final next = _parsed;
    final current = context.read<ExchangeRateService>().rate;
    if (next == null || next <= 0) return false;
    return (next - current).abs() >= 0.01;
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
            SectionHeader(
              title: 'Tipo de cambio de hoy',
              subtitle: exchangeRate.hasServerRate
                  ? 'Se sincroniza en tiempo real con todos los celulares de esta armería.'
                  : 'Todavía no hay tipo de cambio guardado para esta armería. Guardalo acá para habilitar precios en pesos.',
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(AppDecorations.radius),
                border: Border.all(
                  color: AppColors.border,
                  width: AppDecorations.hairline,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('1 USD =', style: AppText.heading),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    style: AppText.displayDesktop.copyWith(
                      color: AppColors.accent,
                    ),
                    decoration: InputDecoration(
                      suffixText: 'ARS',
                      suffixStyle: AppText.numberLarge.copyWith(
                        color: AppColors.textMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: AppDecorations.buttonPrimary,
              child: ElevatedButton(
                onPressed: _canSave
                    ? () async {
                        final parsed = _parsed!;
                        await exchangeRate.saveRate(parsed);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tipo de cambio guardado.'),
                          ),
                        );
                      }
                    : null,
                child: const Text('GUARDAR'),
              ),
            ),
            const SizedBox(height: 16),
            if (exchangeRate.updatedAt != null)
              Text(
                'Última actualización: ${formatDateTime(exchangeRate.updatedAt!)}',
                style: AppText.bodySmall,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
