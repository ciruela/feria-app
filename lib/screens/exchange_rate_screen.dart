import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _controller = TextEditingController(text: formatExchangeRateInput(rate));
    _parsed = rate;
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final parsed = parseExchangeRate(_controller.text);
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
    return (next - current).abs() >= 0.005;
  }

  Future<void> _save() async {
    final parsed = _parsed;
    if (parsed == null || parsed <= 0) return;

    final exchangeRate = context.read<ExchangeRateService>();
    await exchangeRate.saveRate(parsed);
    if (!mounted) return;

    _controller.text = formatExchangeRateInput(exchangeRate.rate);
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() => _parsed = exchangeRate.rate);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tipo de cambio guardado: ${formatExchangeRate(exchangeRate.rate)} ARS',
        ),
      ),
    );
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
                  ? 'Se sincroniza en tiempo real con todos los celulares de esta armería. Podés usar centavos (ej. 1500,50).'
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
                  const Text('1 USD =', style: AppText.heading),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    // AR-37: number alone hides decimal key on mobile.
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    style: AppText.displayDesktop.copyWith(
                      color: AppColors.accent,
                    ),
                    decoration: InputDecoration(
                      suffixText: 'ARS',
                      suffixStyle: AppText.numberLarge.copyWith(
                        color: AppColors.textMuted,
                      ),
                      hintText: '1500,50',
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
                onPressed: _canSave ? _save : null,
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
